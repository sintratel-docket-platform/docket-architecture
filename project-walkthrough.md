# Project walkthrough

**Purpose** Replace the talk the final presentation used to be. The narrative
now lives here, built from the Markdown the team wrote across the project's
repositories, with every claim linked to something a reviewer can open and
check. Written for someone who has not seen the project before and wants to
follow it without a guide.

**State at delivery.** The AWS account that hosted the platform ran on the AWS
free credit plan, and it ended with the credits on 22 September 2026. Nothing
runs now. The cluster, the registry and its images, the Terraform state, the
secrets and the DNS zone ended with the account, so no endpoint answers and no
environment can be visited. Everything below describes what was built and links
to the record that outlives it, in Git and on the board.
[`docket-infrastructure/docs/rebuilding-in-a-new-account.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/rebuilding-in-a-new-account.md)
covers what a rebuild in a new account needs.

## 1. The client's problem and what Docket is

SINTRATEL, the course's client brief, asks for a task management platform for
a law firm's teams, built with the continuous engineering practices the
Infrastructure Automation course requires: agile delivery, infrastructure as
code, automated pipelines, GitOps, testing at three levels, change management,
observability and security, on top of an application that actually works. The
full brief is [`docket-ai-sdd/docs/sintratel-docket-brief.md`](https://github.com/sintratel-docket-platform/docket-ai-sdd/blob/main/docs/sintratel-docket-brief.md).

**Docket** is that platform: five microservices and a queue, one per
repository, described in full in
[`logical-architecture.md`](logical-architecture.md).

| Service | Stack | Role |
|---|---|---|
| `auth-api` | Go | Issues JWTs on login |
| `users-api` | Java, Spring Boot | User profiles, read only |
| `todos-api` | Node.js | Task CRUD, publishes events to Redis |
| `log-message-processor` | Python | Consumes the Redis queue |
| `frontend` | Vue.js | The web interface |

`JWT_SECRET` is shared by `auth-api`, `users-api` and `todos-api`; Redis is the
queue between `todos-api` and `log-message-processor`.

## 2. What was built, area by area

Nine areas, the same nine [`documentation-map.md`](documentation-map.md)
indexes. Each row is where the detail lives, not a repeat of it.

**01. Agile methodology and branching.** Kanban on GitHub Projects, 53 cards,
two recorded iterations. Trunk-based development: short branches, one pull
request per card, Conventional Commits.
[`docket-roadmap/README.md`](https://github.com/sintratel-docket-platform/docket-roadmap/blob/main/README.md),
[`AGENTS.md`](standards/AGENTS.md) sections 4 to 6.

**02. Infrastructure as code.** Terraform, split between reusable modules
(public, tagged releases, currently `v3.3.0`) and the stacks that consume them
by pinned tag. Three environments, ephemeral infrastructure with split state,
CI gates on every module and stack change (card #41, done) and module-level
tests (card #46, done).
[`docket-infrastructure/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/README.md),
[`docket-terraform-modules/README.md`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/README.md),
[`aws-infrastructure.md`](aws-infrastructure.md).

**03. Design patterns.** [`design-patterns.md`](design-patterns.md) names what
the code applies and points at the file behind each one: retry with capped
backoff where the services depend on Redis, external configuration through
Parameter Store and the External Secrets Operator, and the Redis channel
between `todos-api` and `log-message-processor`, which are the resilience,
configuration and integration patterns the brief asks for. It also lists what
the platform does without, such as a circuit breaker and a service mesh, and
why.

**04. Continuous integration and GitOps.** Ten pipelines connect a commit to a
deployed version: build, test, scan and publish per service, then a promotion
pull request that changes an image tag in `docket-gitops` for Argo CD to
apply. Promotion carries real gates, not only a description of them: the
`main → dev` gate blocks HIGH and CRITICAL image findings (every service's own
"block HIGH and CRITICAL image findings" pull request, merged 21 September
2026), staging promotion is gated on the L2 suite having actually run against
the deployed `dev` environment
([`docket-gitops` pull request #46](https://github.com/sintratel-docket-platform/docket-gitops/pull/46)),
and production needs a recorded approval and a manual sync
([`docs/production-change-policy.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/production-change-policy.md),
[ADR-016](decisions.md#adr-016-production-approval-without-branch-protection),
[ADR-020](decisions.md#adr-020-independent-approval-as-a-policy-parameter),
[ADR-022](decisions.md#adr-022-level-2-and-3-gates-run-inside-the-promotion-pipeline-not-reactively)).
[`environments.md`](environments.md), [`pipelines.md`](pipelines.md).

**05. Testing.** Three levels: L1 unit and L2 integration inside each
service's own pipeline, all five services carrying both levels, and L3 end to
end in Playwright against a deployed environment, seven scenarios living in
`docket-gitops/e2e`. All three gate promotion; none is informational
only. [`testing-strategy.md`](testing-strategy.md), [`AGENTS.md`](standards/AGENTS.md)
section 9.

**06. Change management and release notes.** Semantic versioning
([ADR-013](decisions.md#adr-013-semantic-versioning-for-services-and-modules))
and automated release notes
([ADR-019](decisions.md#adr-019-release-notes)) from Conventional Commits, one
Markdown file per service version in
[`docket-gitops/releases/`](https://github.com/sintratel-docket-platform/docket-gitops/tree/main/releases)
and a GitHub Release per service tag. Production changes follow a written
policy with named approvers and a documented rollback, a reverted pull request
through the same approval and sync path, never a live edit.
[`docs/production-change-policy.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/production-change-policy.md),
[`docs/production-operations.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/production-operations.md)
section 7.

**07. Observability.** Every service answers an unauthenticated `GET /health`
(card #20), read by the Kubernetes probes. CloudWatch Container Insights
collects pod and node metrics and container logs
([ADR-023](decisions.md#adr-023-observability-cloudwatch-container-insights)),
and four alarms (`restarts-high`, `cpu-high`, `memory-high`, `error-rate`) post
to Slack through an SNS topic and a Lambda formatter (card #21). `auth-api`'s
Zipkin instrumentation runs but sends spans nowhere: no tracing backend is
deployed. Prometheus and Grafana, named in the brief, were replaced by this
CloudWatch-based approach, recorded as a deliberate substitution in ADR-023
rather than an omission.
[`docket-infrastructure/docs/operational-alerts.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/operational-alerts.md).

**08. Security.** Secrets in SSM Parameter Store, read through External
Secrets and IRSA, never in Git
([ADR-002](decisions.md#adr-002-secrets-with-external-secrets-and-ssm-parameter-store)).
CI authenticates to AWS through OIDC, no long-lived keys
([ADR-011](decisions.md#adr-011-pipeline-credentials-with-oidc-and-an-iam-role)).
Policy as code enforces the Terraform security invariants (card #42). Every
service's image gate blocks HIGH and CRITICAL findings, and every service
enforces a SonarQube quality gate (card #11's five service pull requests,
each titled "enforce SonarQube quality gate", merged between 18 and 20
September 2026). Branch protection now covers the three public repositories,
the most the current GitHub plan allows (card #39, in review,
[ADR-025](decisions.md#adr-025-branch-protection-within-the-free-plan)). The
residual risks the team has accepted rather than closed, including the
production JWT secret incident of 21 September 2026, are recorded in
[`project-retrospective.md`](project-retrospective.md) and, in full detail, in
`docket-infrastructure/docs/security-controls.md` (private).

**09. Documentation and presentation.** This walkthrough,
[`documentation-map.md`](documentation-map.md) as the index into everything
else, `docket-infrastructure/docs/infrastructure-costs.md` (card #33, in
review) for costs, and
`docket-gitops/docs/operations-manual.md` /
`docket-infrastructure/OPERATIONS.md` / `docket-infrastructure/GETTING-STARTED.md`
(cards #31, #32) for operations. The demonstration video (card #36) does not
exist yet; [`demo-runbook.md`](demo-runbook.md) is its script.

## 3. Results and evidence

Each row links a pull request, a card, a tag or a document rather than a running
endpoint, so every claim stays checkable now that the environment is gone.

| Result | Evidence |
|---|---|
| First controlled release to production | Card [#27](https://github.com/sintratel-docket-platform/docket-roadmap/issues/27), done. `docket-gitops` pull request [#32](https://github.com/sintratel-docket-platform/docket-gitops/pull/32) (15 September 2026) |
| Latest production sync, all five services | `docket-gitops` pull request [#52](https://github.com/sintratel-docket-platform/docket-gitops/pull/52) (21 September 2026), revision `c4759ad`, recorded on the same pull request's sync comment |
| `users-api` off its unsupported framework | Card [#49](https://github.com/sintratel-docket-platform/docket-roadmap/issues/49) delivered (board still shows Ready; its own closing comment confirms completion). Spring Boot 3.5.16 on Java 17, 26 tests passing, `.trivyignore.yaml` empty, zero CRITICAL. [ADR-024](decisions.md#adr-024-users-api-framework-and-security-baseline-migration) |
| HIGH and CRITICAL image findings block every service | Each service's "block HIGH and CRITICAL image findings" pull request, merged 21 September 2026 (`docket-auth-api` #14, `docket-users-api` #12, `docket-todos-api` #15, `docket-log-message-processor` #19, `docket-frontend` #15) |
| SonarQube quality gate enforced on every service | Each service's "enforce SonarQube quality gate" pull request, merged 18 to 20 September 2026. Card [#11](https://github.com/sintratel-docket-platform/docket-roadmap/issues/11) (board still shows Ready) |
| Staging promotion gated on a real L2 run against `dev` | `docket-gitops` pull request [#46](https://github.com/sintratel-docket-platform/docket-gitops/pull/46) |
| Branch protection on the repositories the Free plan allows | Card [#39](https://github.com/sintratel-docket-platform/docket-roadmap/issues/39), in review. [ADR-025](decisions.md#adr-025-branch-protection-within-the-free-plan) |
| Observability stack delivered | Cards [#20](https://github.com/sintratel-docket-platform/docket-roadmap/issues/20) and [#21](https://github.com/sintratel-docket-platform/docket-roadmap/issues/21), both done. `docket-infrastructure/docs/operational-alerts.md` |
| Task board, assignment and deadlines built, deployed to development and staging | `docket-todos-api` and `docket-frontend` pull requests for cards #28, #29, #30, merged 20 to 21 September 2026; `environments/development` and `environments/staging` kustomizations pin `1.4.0` for `frontend` and `todos-api`. Production promotion waiting on private-repository Actions minutes |
| Terraform modules versioned and tested | `docket-terraform-modules` tags through `v3.3.0`. Card [#46](https://github.com/sintratel-docket-platform/docket-roadmap/issues/46), done |
| Infrastructure costs estimated | Card [#33](https://github.com/sintratel-docket-platform/docket-roadmap/issues/33), in review. `docket-infrastructure/docs/infrastructure-costs.md` |
| Automated tests at three levels | L1 and L2 suites in all five services, run by each service's `service-ci` on every pull request; the L3 suite, seven Playwright scenarios in `docket-gitops/e2e`, gates every promotion. Per-service counts in [`testing-strategy.md`](testing-strategy.md) date from 16 September; `todos-api` and `frontend` grew with card #30 |

## 4. Limitations and what comes next

The full list is [`project-retrospective.md`](project-retrospective.md), checked
against the repositories and the board on 21 September 2026, and it describes
the platform as it last ran. What matters most:

1. **The platform no longer runs.** Its AWS account ended with its free credits
   on 22 September 2026. Bringing it back means a new account and the values
   tied to the old one, which
   [`docket-infrastructure/docs/rebuilding-in-a-new-account.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/rebuilding-in-a-new-account.md)
   lists. The code, the manifests, the pipelines and the record of what ran are
   unaffected.
2. **Production approval was enforced by process, not by GitHub, on the ten
   private repositories.** The three public repositories have branch
   protection; the private ones cannot on the current plan (card #39).
3. **Nothing validates a JWT secret's length before a deployment.** Production's
   `jwt-secret` was too short after the 21 September sync and every login
   failed until it was rotated, caught only because someone tried to log in.
4. **`todos-api` stores its data in memory.** A restart loses every task.
5. **Argo CD was reached through one shared account.** A sync named no
   individual; card #19 recorded this without closing it.

## 5. Coverage against the brief

One row per deliverable the course brief lists. Complete means the document
or evidence exists and is current; partial means it exists but leaves a
stated gap; missing means nothing exists yet.

| Deliverable | Status | Where |
|---|---|---|
| Architecture with diagrams | Complete | [`logical-architecture.md`](logical-architecture.md), [`environments.md`](environments.md), [`aws-infrastructure.md`](aws-infrastructure.md), [`pipelines.md`](pipelines.md); the nine diagrams were redrawn and re-exported on 21 September 2026 against the platform as it ran |
| Agile methodology | Complete | [`AGENTS.md`](standards/AGENTS.md) §4 to §6, `docket-roadmap` |
| Sprint and iteration records | Complete | `docket-roadmap/iterations/`, two recorded iterations |
| User stories and acceptance criteria | Complete | `docket-roadmap/stories/`, one file per board card; cards 49, 50, 52 and 53 are added by `docket-roadmap` #54 (there is no card 51) |
| Branching strategy | Complete | [`AGENTS.md`](standards/AGENTS.md) §4 |
| Design patterns | Complete | [`design-patterns.md`](design-patterns.md), with the resilience, configuration and integration patterns the brief asks for named against the files that implement them, and the absent ones stated |
| Operations and maintenance guide | Complete | `docket-gitops/docs/operations-manual.md`, `docket-infrastructure/OPERATIONS.md`, `docket-infrastructure/GETTING-STARTED.md` |
| Test results and analysis | Complete | [`testing-strategy.md`](testing-strategy.md) |
| Infrastructure as code | Complete | `docket-infrastructure`, `docket-terraform-modules` |
| Environments (dev, staging, prod) | Complete | [`environments.md`](environments.md) |
| Rollback plans | Complete | `docket-gitops/docs/production-operations.md` §7 |
| Release notes | Complete | `docket-gitops/releases/`, GitHub Releases per service |
| Security controls | Complete, with residual risk recorded | `docket-infrastructure/docs/security-controls.md` (private), [`project-retrospective.md`](project-retrospective.md) |
| Cost estimate and analysis | Complete | `docket-infrastructure/docs/infrastructure-costs.md` (card #33, in review) |
| Lessons learned | Complete | [`project-retrospective.md`](project-retrospective.md) |
| Final presentation | Complete | This document |
| Demonstration video | Missing | Card #36, in backlog |
| Penetration test | Missing | Taken on by EstebanGZam, with no card yet; recorded as an accepted risk until it is done |
| Monitoring stack (Prometheus and Grafana in the brief) | Delivered differently | Replaced by CloudWatch Container Insights, [ADR-023](decisions.md#adr-023-observability-cloudwatch-container-insights) |
| Distributed tracing (Zipkin) | Partial | The services carry Zipkin instrumentation; no Zipkin backend is deployed |

## 6. A suggested order for the walkthrough

Aligned with [`demo-runbook.md`](demo-runbook.md), which ordered the live demo
the same way while the environment ran.

1. The organisation profile, `.github/profile/README.md`, for the one-line
   orientation and the link back here.
2. This document, then [`logical-architecture.md`](logical-architecture.md)
   for the application and [`environments.md`](environments.md) for how it is
   deployed.
3. `docket-infrastructure` and `docket-terraform-modules` for the
   infrastructure as code, starting from each repository's `README.md`.
4. `docket-gitops`, for GitOps, promotion and the production change policy.
5. [`testing-strategy.md`](testing-strategy.md), then `docket-gitops/e2e` for
   the end-to-end suite itself.
6. `docket-infrastructure/docs/security-controls.md` and
   [`decisions.md`](decisions.md)'s security-themed ADRs.
7. `docket-infrastructure/docs/operational-alerts.md` for observability.
8. `docket-roadmap`, for the board, the stories and the iterations.
9. [`docket-roadmap/iterations/iteration-03.md`](https://github.com/sintratel-docket-platform/docket-roadmap/blob/main/iterations/iteration-03.md),
   for what the last iteration committed to, what shipped and how the
   environment ended.
10. [`project-retrospective.md`](project-retrospective.md), for the limitations
    and what comes next, last, since it presumes everything above it.
