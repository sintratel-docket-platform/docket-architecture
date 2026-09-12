# Pipelines

How work reaches the cluster, which automation owns each step, and where a change is
stopped when it should not go further.

The project runs ten pipelines across four repositories. Six work today. Four belong to
card 14 and later. This document maps all of them and sequences the six where the order of
messages between independent actors carries information.

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

The project therefore needs one more pipeline, `verify`, which runs after deployment and
produces the signal that authorises promotion.

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
| `release` and Renovate | `docket-terraform-modules` | 6, crosses repositories | Sequence 4 |
| `verify` | `docket-gitops` | 7 | Sequence 5 |
| rollback | `docket-gitops` | 5 | Sequence 6 |
| `pr-conventions` | all nine | 2 | Gate table |
| `terraform-ci` | `docket-infrastructure` | 2 | Gate table |
| `module-ci` | `docket-terraform-modules` | 2 | Gate table |
| `gitops-ci` | `docket-gitops` | 2 | Gate table |

## How the pipelines connect

![How the Docket pipelines connect](img/pipeline-map.png)

Four properties of the system are visible in the map.

**Only `infrastructure` holds write credentials for AWS.** Every other gate is static
analysis and needs no cloud identity. The one workflow that can destroy the cluster is
therefore manual and sits behind a single OIDC role.

**A version joins the two Terraform repositories.** `docket-terraform-modules` cuts a tag,
Renovate opens a bump pull request, and live state changes on apply. Each step is an
explicit decision, so a module change reaches production only when someone chooses it.

**`docket-gitops` sits between code and cluster.** No pipeline holds `kubectl`
credentials. Every deployment happens because Argo CD read a commit.

**Verification gates promotion.** `verify` turns a deployed version into a promotable one,
and its result is the evidence a promotion rests on.

## The test pyramid, and where each level runs

The three levels the deliverables document requires belong in different places.

| Level | Runs in | Against | Trigger | Card |
|---|---|---|---|---|
| Unit | `service-ci` | the code, nothing deployed | every push and pull request | 10 |
| Integration | `verify` | the services running in `dev` | Argo CD reports `dev` Healthy | 16 |
| End to end | `verify` | the full journey through `dev` | same run, after integration | 17 |

The split follows from what each level needs. Unit tests need a compiler. Integration
tests need several services talking to each other and to Redis. End to end tests need the
frontend, the APIs and the queue all reachable through the ingress.

Coverage is produced at the unit level and consumed by SonarQube. Integration and end to
end produce pass or fail plus traces, and their result is what the promotion gate reads.

**Current state, 11 September 2026.** All five services carry a suite and `service-ci` runs
it on every change. 106 tests, 71 at level 1 and 35 at level 2.

| Service | L1 | L2 | Line coverage |
|---|---|---|---|
| `auth-api` | 12 | 11 | 60.6% |
| `users-api` | 11 | 10 | 80.6% |
| `todos-api` | 9 | 8 | 53.2% |
| `log-message-processor` | 2 | 6 | 69% |
| `frontend` | 37 | 0 | 75.4% |

Level 3 has nothing yet and is correctly blocked. It needs a deployed staging
environment, which is card 22.

Two gaps the numbers hide. `server.js` in `todos-api` and `main.js` in the frontend sit at
0%, because the level 2 helper builds its own Express app rather than booting the real
one, so nothing at any level exercises the process starting up. That belongs to level 3.
And `frontend` has no level 2 at all, which `AGENTS.md` section 9.2 intends and card 16
contradicts. One of the two is wrong and nobody has decided which.

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

**Trivy scans the image while it is still on the runner.** A critical finding stops the
run before the image reaches ECR. The registry's own scan happens after publication, when
the vulnerable image is already available to deploy.

**The image carries two tags.** A semantic version and the commit sha. The deliverables
document asks to tie every build to a commit and to an identifiable version, which are two
different questions. The version identifies a release in conversation, the sha identifies
the exact source.

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

## Sequence 3. Turning the cluster on and off

![Cluster lifecycle](img/pipeline-cluster-lifecycle.png)

The only pipeline with write credentials on AWS. The diagram documents behaviour already
in production.

The shutdown branch is where the ordering matters. The workflow talks to the Kubernetes
API **before** Terraform destroys anything, because load balancers, DNS records and volumes
are created by controllers inside the cluster and never entered Terraform state.
Destroying the cluster first leaves all three orphaned and billing.

## Sequence 4. From a module change to live infrastructure

![Module to live infrastructure](img/pipeline-module-to-infrastructure.png)

The only flow that crosses repositories, introduced by ADR-012 when modules moved out of
`docket-infrastructure`.

It also shows why the exposure scan runs first in `module-ci`. The module repository is
public and so is its Git history, so clearing an account identifier committed by mistake
requires rewriting history.

## Sequence 5. Verification after deployment

![Verification after deployment](img/pipeline-verification.png)

The upper two levels of the test pyramid, and the pipeline that puts evidence behind a
promotion.

The deployment triggers it. Argo CD reports `dev` as Synced and Healthy, and the
integration and end to end suites then run against the services that are actually running.

The outcome is a gate. Suites pass and the version is recorded as promotable, so the
promotion pipeline has something to act on. Suites fail and the version stays in `dev` with
a named failing scenario. This is what the deliverables document means by minimum approval
criteria for promotion between environments.

## Sequence 6. Rolling back a bad release

![Rollback](img/pipeline-rollback.png)

The deliverables document asks for documented rollback plans. In GitOps the procedure has
a counterintuitive property, and the diagram shows both paths so the working one is
unambiguous.

**Rolling back from the Argo CD interface fails here.** Argo CD reapplies the previous
manifests while Git still declares the broken version, so the next reconciliation with
self heal enabled restores the broken version. The tool undoes its own rollback.

The rollback is a `git revert` in `docket-gitops`, reviewed like any other change,
followed by a sync. It costs about a minute more, it leaves Git and the cluster in
agreement, and it records what was reverted and by whom.

## The four gate pipelines

These four are lists of checks. What matters is what they verify, in what order, and which
one blocks a merge.

| Pipeline | Trigger | Checks | Blocks |
|---|---|---|---|
| `pr-conventions` | every pull request, all nine repositories | Conventional Commit title, branch name pattern, `AGENTS.md` drift against its canonical source | yes |
| `terraform-ci` | pull requests touching Terraform | `fmt`, `validate`, `tflint`, Trivy config scan, Checkov, OPA policy against saved plans | yes |
| `module-ci` | pull requests touching modules | account identifier and secret scan, `fmt`, `validate`, plan mode tests | yes |
| `gitops-ci` | pull requests in `docket-gitops` | `kustomize build`, manifest schema, the image tag exists in the registry | planned |

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
`environments/<env>/kustomization.yaml`, one entry per service, written with
`kustomize edit set image`. A `sed` over the YAML works until someone reorders the file.

Six entries share one file, so five pipelines write to the same path. Actions concurrency
groups do not cross repositories, so two merges landing together collide on the push. The
step needs a rebase and a bounded retry, and it needs to fail visibly rather than leave a
tag half written.

**How a version is recorded as promotable.** Sequence 5 ends with `verify` writing that
signal. A Git tag, a status check on the commit, and a file in the repository are all
workable, and each has different consequences for how the promotion pipeline reads it.

**Where SonarQube runs.** Self hosted inside the cluster or SonarCloud. The choice changes
the credentials the pipeline needs, and it belongs to card 11.
