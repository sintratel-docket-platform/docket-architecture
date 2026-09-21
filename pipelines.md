# Pipelines

How work reaches the cluster, which automation owns each step, and where a change is
stopped when it should not go further.

The project runs twelve pipelines across four repositories. This document maps all of
them and sequences the ones where the order of messages between independent actors
carries information.

## Why the work is split across pipelines

A single long pipeline that builds, tests, deploys and verifies is the wrong shape here,
for three reasons.

**End to end tests need a deployed system.** They cannot run in the job that produced the
image, because at that moment nothing is running. They run against `dev` after Argo CD has
applied the manifests, which is a different trigger and a different pipeline.

**Feedback time compounds.** A unit test failure should be known in two minutes. If unit
tests share a pipeline with an end to end suite that needs a deployment, every failure
costs the full run.

**The deliverables document requires the separation.** It asks that CI build and publish
artifacts and that Argo CD perform the deployment. A pipeline that did both would collapse
that boundary.

The project therefore needs one more pipeline, `verify`, which runs the two upper test
levels and produces the signal that authorises promotion. It does not run after
deployment as a reaction to it, for the reason Sequence 5 gives; it runs inside the
promotion pipeline itself, before a promotion is even written.

## Which pipelines get a sequence diagram

A sequence diagram earns its place when **several independent actors exchange messages and
the order matters**. When a pipeline is a list of steps inside one runner, its sequence
diagram becomes a column of arrows from a participant to itself, and a table says the same
in less space.

| Pipeline | Repository | Actors | Treatment |
|---|---|---|---|
| `service-ci` | the five service repositories | 8 | Sequence 1 |
| promotion | `docket-gitops` | 5 | Sequence 2 |
| `infrastructure` | `docket-infrastructure` | 6 | Sequence 3 |
| `release` | `docket-terraform-modules` | 6, crosses repositories | Sequence 4 |
| `verify` | `docket-gitops`, inside `promote.yml` | 1 (one job in one runner) | Sequence 5, as a table |
| rollback | `docket-gitops` | 5 | Sequence 6 |
| `pr-conventions` | all nine | 2 | Gate table |
| `terraform-ci` | `docket-infrastructure` | 2 | Gate table |
| `module-ci` | `docket-terraform-modules` | 2 | Gate table |
| `gitops-ci` | `docket-gitops` | 2 | Gate table |
| `production-approval` | `docket-gitops` | 2 | Sequence 2 and gate table |
| `production-sync-record` | `docket-gitops` | 2 | Sequence 2 |

## How the pipelines connect

![How the Docket pipelines connect](img/pipeline-map.png)

Four properties of the system are visible in the map.

**Only `infrastructure` holds write credentials for AWS.** Every other gate is static
analysis and needs no cloud identity. The one workflow that can destroy the cluster is
therefore manual and sits behind a single OIDC role.

**A version joins the two Terraform repositories.** `docket-terraform-modules` cuts a tag
when someone merges the release pull request release-please keeps open, a pull request in
`docket-infrastructure` moves the pinned `?ref=`, and live state changes on apply. Each
step is an explicit decision, so a module change reaches production only when someone
chooses it. Renovate was meant to open that bump pull request and never has, so today a
person opens it ([card 52](project-retrospective.md#current-limitations)).

**`docket-gitops` sits between code and cluster.** No pipeline holds `kubectl`
credentials. Every deployment happens because Argo CD read a commit.

**Verification gates promotion.** `verify` turns a deployed version into a promotable one,
and its result is the evidence a promotion rests on. The contract is fixed by ADR-014: a
commit status named `verify` on the `docket-gitops` commit that deployed the version.
Cards 16 and 17 write it (ADR-022): `promote.yml` runs the gate and sets the status
before a promotion pull request exists, so `gitops-ci`'s own read of it, on the pull
request that does open, always finds `success` already there.

## The test pyramid, and where each level runs

The three levels the deliverables document requires belong in different places.

| Level | Runs in | Against | Trigger | Card |
|---|---|---|---|---|
| Unit | `service-ci` | the code, nothing deployed | every push and pull request | 10 |
| Integration | `service-ci` | the code, with ephemeral doubles standing in for its real collaborators (`AGENTS.md` §9.1) | every push and pull request | 16 |
| End to end | `verify`, inside `promote.yml` | a deployed environment, through its public host | a promotion is requested | 17 |

The split follows from what each level needs. Unit tests need a compiler. Integration
tests need a real collaborator, kept ephemeral for the run — a double is enough, and every
built suite uses one. End to end tests need the frontend, the APIs and the queue all
reachable through the gateway, which only a real deployment gives.

Coverage is produced at the unit level and consumed by SonarQube. Integration and end to
end produce pass or fail plus traces, and their result is what the promotion gate reads.

**Current state, 16 September 2026.** All five services carry a suite and `service-ci` runs
it on every change. 147 tests, 96 at level 1 and 51 at level 2. Line coverage is reported
per pull request by each service's own CI and not summarised here, to avoid a number that
goes stale the moment it is written; card 11 (SonarQube) is where it will be consumed.

| Service | L1 | L2 |
|---|---|---|
| `auth-api` | 19 | 14 |
| `users-api` | 13 | 11 |
| `todos-api` | 14 | 12 |
| `log-message-processor` | 13 | 7 |
| `frontend` | 37 | 7 |

Level 3 exists (`docket-gitops/e2e`, six scenarios) and, since card 17, runs automatically
inside `promote.yml` — see Sequence 5.

**Doubles, not a live `dev`, for level 2 — resolved (ADR-022).** This section used to note
a contradiction: level 2 was designed to run inside `verify` against a real deployed `dev`,
but every suite that got built uses doubles instead, which is what `AGENTS.md` §9.1
explicitly permits ("real, but ephemeral: containers, in-memory doubles"). `AGENTS.md`'s
design is the one that stands. Running level 2 again against a live `dev` would duplicate
level 3's job with a different mechanism, at the cost of needing that job to reach a real
cluster network, which no other pipeline in this project does.

`frontend` had no level 2 suite until card 16 closed it, against a stub standing in for
`auth-api` and `todos-api` — the same shape the other four services already use. The
`server.js` / `main.js` start-up gap the previous version of this section noted is level
3's territory: the suite now runs against the real deployed process, not a helper that
builds its own app in-process.

## Sequence 1. Commit to development

![Commit to development](img/pipeline-commit-to-development.png)

**One diagram covers all five services.** The pipeline has the same shape in every
repository, so five identical lifelines would widen the diagram without adding
information. The toolchain differs, and only in the first two steps.

| Service | Language | Unit tests | Coverage format for Sonar |
|---|---|---|---|
| `docket-auth-api` | Go | `go test` | `cover.out` |
| `docket-users-api` | Java, Maven | `mvn test` | JaCoCo XML |
| `docket-todos-api` | Node.js | `npm test` | LCOV |
| `docket-frontend` | Vue | `npm test` | LCOV |
| `docket-log-message-processor` | Python | `pytest` | `coverage.xml` |

Everything from the build onwards is identical, which is the half worth extracting into a
shared action once all five work.

The diagram fixes five decisions.

**Trivy scans the image while it is still on the runner.** A HIGH or CRITICAL finding stops the
run before the image reaches ECR. The registry's own scan happens after publication, when
the vulnerable image is already available to deploy.

**The image carries two tags.** A semantic version and the commit sha. The deliverables
document asks to tie every build to a commit and to an identifiable version, which are two
different questions. The version identifies a release in conversation, the sha identifies
the exact source.

Implemented by card 12 and recorded in ADR-013. `.github/scripts/next-version.sh` reads
the commits since the highest `vX.Y.Z` tag: a breaking change bumps the major, a `feat`
the minor, and anything else that publishes an image the patch, because an image deployed
without a version is exactly what the two tags exist to prevent. The first version of each
service was `1.0.0`. On a pull request the version is predicted from its title, which
becomes the squash commit, and shown in the run summary.

Four properties hold the chain together, each enforced by the pipeline rather than by
convention:

- **Both tags name one manifest.** The version is added to the pushed sha tag with
  `imagetools create --prefer-index=false`, and the run compares the two digests. Without
  that flag buildx wraps the image in a new manifest list; `log-message-processor` `1.0.0`
  was published that way, before the fix, and stays as the one exception, since ECR tags
  cannot be rewritten.
- **A version never names two commits.** If it already exists in ECR, its
  `org.opencontainers.image.revision` label must be this commit, which makes the run a
  re-run; otherwise the run fails and names both.
- **The Git tag follows the image.** `vX.Y.Z` is pushed only after the registry holds the
  image, so no tag points at a version that cannot be pulled.
- **Runs on `main` queue.** A run cancelled between the registry push and the tag would
  leave the next run to collide, so only pull request runs cancel each other.

`docket-gitops` receives the version as `newTag`, with the sha in the commit header
(`deploy 1.0.1 (sha-e4ae055) to development`), and the Slack announcement carries both.
Observed end to end on the first rollout: every pod in `dev` runs a version whose image
digest equals the one ECR reports for both of its tags.

**Development is written directly, with no pull request.** The environment document
assigns the controls: none extra for `dev`, review for `staging`, review plus approval for
`prod`. A pull request in `dev` would mean every merge to `main` opens another pull request
for someone to merge.

**The pipeline writes into `docket-gitops`.** The alternative is a process that watches ECR
for new images, which adds delay, fails quietly, and loses the link between a commit and
the deployment it produced.

**Argo CD appears at the end.** No arrow runs from GitHub Actions to the cluster.

## What the first image scans found

The gate in Sequence 1 had never run against a container before 11 September 2026. Running
it across the five services produced the numbers below. They are recorded here because they
are the baseline a future decision needs, and because every one of the five services would
have failed its first merge without the work each row describes.

| Service | Base image | CRITICAL before | after | What was done |
|---|---|---|---|---|
| `auth-api` | distroless static, Debian 12 | 1 | 0 | grpc 1.63.2 had a patch at 1.79.3 and it was taken |
| `todos-api` | `node:20-alpine` | 1 | 0 | the CVE was in npm's bundled tar, and npm was removed from the runtime stage |
| `frontend` | `nginx-unprivileged:1.27-alpine` | 2 | 0 | the 1.27 line stopped receiving the OpenSSL patch, so the base moved to 1.29 |
| `log-message-processor` | `python:3.11-slim`, Debian 13 | 3 | 3 accepted | perl-base has no fixed Debian release, and the bookworm base measured worse at 5 |
| `users-api` | `eclipse-temurin:8-jre-alpine` | 44 | 17 accepted | every patch inside the Boot 1.5.6 lines was taken, closing 27 |

### The gate reported green while scanning nothing

The first run of the pilot passed all five checks. It was not scanning for
vulnerabilities. `trivy.yaml` sits at the root of every service repository and pins
`scanners` to `misconfig` and `secret` for the Terraform scan, Trivy discovers that file on
its own, and it overrode the intent of the step. The evidence was a summary table carrying
`Misconfigurations` and `Secrets` columns with no `Vulnerabilities` column, and a job that
downloaded the checks bundle instead of the vulnerability database.

Every `service-ci` now passes `scanners` explicitly. A green check is not evidence on its
own. The log must show `[vulndb] Downloading vulnerability DB` and the table must carry a
`Vulnerabilities` column.

### What this leaves open

`log-message-processor` accepts 3 findings and `users-api` accepts 17. Both sets expire on
2 October 2026, and an expiry is a recheck rather than an extension.

The two are different problems and the distinction matters for whoever picks this up.

The three in `log-message-processor` are Debian's to fix. Nothing in the project can reach
them, the alternative base was measured and is worse, and the worker never invokes perl.
The decision to revisit is whether Debian has shipped a fix.

The 17 in `users-api` are one decision repeated. Spring Boot 1.5.6 is from 2017 and has
been out of support since 2019. Tomcat needs 9 or later, Spring needs 5 or later, h2 needs
a major version that changes SQL syntax, and dom4j has no fix at all. Card 49 is the work
that empties that file, and its acceptance criteria include the list returning to
`vulnerabilities: []`. Until then this service reports green because the findings are
declared, not because they are resolved.

HIGH findings are reported everywhere and block nowhere. That threshold belongs to the
`main` to `dev` promotion gate in `AGENTS.md` section 9.5, card 16. Raising it into
`service-ci` today would stop all five services on base image CVEs that are already
recorded as a limitation.

## Sequence 2. Promotion to production

![Promotion to production](img/pipeline-promotion-to-production.png)

Production has **two independent controls**, each an act of its own with its own audit
trail.

Approving and merging declares the version in Git, and the cluster is untouched at that
moment. The change lands when a person triggers the sync, because the production
Application uses a manual sync policy while `dev` and `staging` are automated.

**Built by card 23 (ADR-014).** Step 1 is the `promote` workflow in `docket-gitops`, run
with a target and a set of services: it opens the pull request as the
`docket-gitops-writer` App, with the *from* and *to* versions, the service tags, the image
digests and the commit that deployed each version to the source environment. On that pull
request, and on any other that moves a `newTag`, `gitops-ci` checks that each image
exists, that the version came from the previous environment and the verify gate. After
the merge, a pin job tags every image staging and production declare
`promoted-<environment>-<tag>`, which the registry lifecycle keeps.

**Approval and sync are recorded by card 25 (ADR-016).** Branch protection is not
available on the manifests repository, so the approval is not required but checked and
audited. `production-approval` sets the commit status `production-approval` on the pull
request, green once an approver who is not the author approves the commit being merged,
and not the requester either unless the policy's independent-approval parameter says so
(ADR-020), and after the merge it audits the commit on `main`, reporting a change
with no valid approval, or merged by someone who is not an approver, to the alerts channel.
Argo CD announces every finished production sync, and the person who synced runs
`production-sync-record`, which names them on every pull request the sync applied and sets
the status `production-sync` on the revision. `gitops-ci` refuses a production Application
that declares automated sync.

Staging follows the same sequence without steps 6 and 7: it syncs on its own once the
promotion merges. The first staging promotion moved four services from `sha-` tags to
`1.0.0` this way; production is first promoted by card 27.

## Sequence 3. Turning the cluster on and off

![Cluster lifecycle](img/pipeline-cluster-lifecycle.png)

The only pipeline that changes the AWS infrastructure. The diagram documents behaviour
already in production. The start branch ends by restoring production to the release the
`production` tag names, and never to anything newer (ADR-018).

The shutdown branch is where the ordering matters. The workflow talks to the Kubernetes
API **before** Terraform destroys anything, because load balancers, DNS records and volumes
are created by controllers inside the cluster and never entered Terraform state.
Destroying the cluster first leaves all three orphaned and billing.

## Sequence 4. From a module change to live infrastructure

![Module to live infrastructure](img/pipeline-module-to-infrastructure.png)

The only flow that crosses repositories, introduced by ADR-012 when modules moved out of
`docket-infrastructure`.

Releasing is automatic since card 12 (ADR-013). Every push to `main` runs release-please,
which reads the commits that touched `modules/` since the last tag. A `feat`, `fix`, `perf`
or breaking change opens or updates one release pull request; anything else, and any change
outside `modules/`, releases nothing. The deliberate act is merging that pull request,
which creates the tag, so several module changes can travel in one release. The first run
after it was switched on confirmed the path filter: `No commits for path: modules,
skipping`.

It also shows why the exposure scan runs first in `module-ci`. The module repository is
public and so is its Git history, so clearing an account identifier committed by mistake
requires rewriting history.

**The diagram shows the bump both ways.** ADR-012 and ADR-013 both describe Renovate
opening the pull request that moves a stack's pinned `?ref=`. Renovate is installed
organisation wide and has never opened one, so every bump in `docket-infrastructure` so far
was opened by a person, the path the diagram marks as today. Card 52 holds the
investigation. The gates that run on that pull request are the same either way; what is
missing is the automation that would notice a release exists.

## Sequence 5. Verifying a version before it is promoted

The pipeline that puts evidence behind a promotion, and where it actually runs (ADR-022,
card 17). It is not a diagram: it is one job inside the promotion pipeline (Sequence 2),
not several independent actors exchanging messages, so a table says what a sequence
diagram would.

**The trigger is a promotion being requested, not a deployment finishing.** The design this
section used to describe had the end to end suite triggered by Argo CD reporting `dev`
Synced and Healthy. Nothing ever built that trigger: it needed a way for the cluster to
reach GitHub Actions, and the only notification target Argo CD has is a Slack webhook.
Building one would have meant a GitHub credential living inside the cluster, a category of
credential every other pipeline in this project was built to avoid. The suite itself needs
no such thing — it drives a browser against a deployed environment's public host, which is
exactly what a person did by hand for every gate this project ran before card 17.

| Step | What happens |
|---|---|
| 1. A promotion is dispatched | `promote.yml`'s `verify` job resolves the source environment from the target, and its public host |
| 2. The gate runs | The level 3 suite, in the pinned Playwright image: the smoke suite for a promotion into `staging`, the full suite for one into `production` |
| 3. The result is written | `promote`'s job writes the `verify` commit status on every service's deploy commit being promoted, from that result |
| 4. The gate decides | Pass: `promote` continues to write `newTag` and open the pull request, with a `Gate evidence:` comment. Fail: the job stops there — no pull request opens |

The outcome is still the same gate ADR-014 fixed: `gitops-ci`, on whatever pull request
later moves a version, reads the same `verify` status from the same deploy commit and
finds it already resolved. Level 2's own criterion in card 16 — that the pipeline blocks
promotion when it fails — needed no new pipeline at all: `service-ci`'s `image` job already
needs `test`, so a version cannot reach `docket-gitops` without level 1 and level 2 passing
for that exact commit.

## Sequence 6. Rolling back a bad release

![Rollback](img/pipeline-rollback.png)

The deliverables document asks for documented rollback plans. In GitOps the procedure has
a counterintuitive property, and the diagram shows both paths so the working one is
unambiguous.

The procedure starts from a CloudWatch alarm posted to the Slack alerts channel (card 21).

**Rolling back from the Argo CD interface fails here.** Argo CD reapplies the previous
manifests while Git and the `production` tag still declare the broken version, so the next
sync, or the restore on the next cluster start, brings the broken version back.

The rollback is a `git revert` in `docket-gitops`, approved like any other production
change, followed by a sync and its record. It costs a few minutes more, it leaves Git, the
cluster and the restore tag in agreement, and it records what was reverted and by whom.

## The four gate pipelines

These four are lists of checks. What matters is what they verify, in what order, and which
one blocks a merge.

| Pipeline | Trigger | Checks | Blocks |
|---|---|---|---|
| `pr-conventions` | every pull request, all nine repositories | Conventional Commit title, branch name pattern, `AGENTS.md` drift against its canonical source | yes |
| `terraform-ci` | pull requests touching Terraform | `fmt`, `validate`, `tflint`, Trivy config scan, Checkov, OPA policy against saved plans | yes |
| `module-ci` | pull requests touching modules | account identifier and secret scan, `fmt`, `validate`, plan mode tests | yes |
| `gitops-ci` | pull requests in `docket-gitops` touching the manifests | `kustomize build` of every environment, each moved image exists in ECR, the version came from the previous environment, the verify gate (ADR-014), production keeps manual sync (ADR-016) | yes |

`production-approval` is a fifth check that does not block. On every pull request touching
a production path it reports whether a named approver approved the commit being merged, and
it audits every merge; branch protection, which would make it blocking, is not available on
the manifests repository (card 39, ADR-016).

Gates run cheapest first, so a formatting error costs seconds. None of them holds cloud
credentials.

## Open before the tag reaches docket-gitops

The first two questions in this section are answered. The YAML they blocked is written and
running in all five services, and the answers are recorded here because the reasoning does
not survive in the result.

**Which credential lets the pipeline write into `docket-gitops`. A GitHub App.** The
`GITHUB_TOKEN` Actions issues is scoped to the repository where the run happens, and the
deploy key `docket-gitops` already holds is read only and belongs to Argo CD.

A write deploy key was rejected. It is a long lived secret that would sit in five
repositories and rotate by hand. A fine grained token was rejected because it belongs to a
person and expires. The App belongs to the organisation, installs on `docket-gitops` alone
with `contents: write`, and mints a token per run that lives an hour.

**It does not exist yet, and it is the only thing blocking the tag write.** Creating an
organisation App and installing it are both owner actions, so this waits on a team lead
rather than on whoever writes the pipeline. The work was ordered around that. Build, test,
scan and publication to ECR need none of it and are delivered.

**Where exactly the image tag lives.** In the `images:` block of
`environments/<env>/kustomization.yaml`, one entry per service. It is written by a
one-line `awk` edit of the matching `newTag`, not `kustomize edit set image`, which
rewrites and reorders the whole file and turns every write into a collision. Since card 12 the value written is the semantic version, not the sha (ADR-013, and
`AGENTS.md` §8 rule 5).

Six entries share one file, so five pipelines write to the same path. Actions concurrency
groups do not cross repositories, so two merges landing together collide on the push. The
step needs a rebase and a bounded retry, and it needs to fail visibly rather than leave a
tag half written.

**How a version is recorded as promotable. A commit status.** ADR-014 fixed it as a status
named `verify` on the `docket-gitops` commit that deployed the version: visible next to the
change it judges, and readable without access to the private service repositories. A Git
tag cannot carry a failure, and a file needs a commit per run. Sequence 5 answers who
writes it and when, settled later by ADR-022: the promotion pipeline itself, before the
pull request that would need it exists.

**Where SonarQube runs.** Self hosted inside the cluster or SonarCloud. The choice changes
the credentials the pipeline needs, and it belongs to card 11.
