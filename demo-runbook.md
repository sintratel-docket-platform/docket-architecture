# Demo runbook

**Purpose.** A practical script for the technical demo and demonstration
video in card 36. It says what can be shown now, where the durable evidence
lives, and which statements would overclaim the delivered platform. It is not
the video itself: recording and publishing the video remain manual work.

## Current constraint

The AWS free-credit account ended on 22 September 2026. The EKS cluster, ECR
images, Terraform state, secrets, DNS zone, CloudWatch data and Argo CD runtime
no longer exist. The demo therefore has two honest surfaces:

1. repository and GitHub evidence for the infrastructure, pipelines,
   promotions, security and historical production release; and
2. `docket-local` for the client-visible task board.

Do not present a local container as development or production, and do not show
an old screenshot as live state. If the platform is rebuilt in a funded AWS
account later, this runbook can regain live sections after they are revalidated.
The rebuild procedure is
[`docket-infrastructure/docs/rebuilding-in-a-new-account.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/rebuilding-in-a-new-account.md).

## 0. Before recording

| Check | Why |
|---|---|
| All repositories are on current `main` | The video must show delivered code, not a feature branch |
| `gh auth status` succeeds for `sintratel-docket-platform` | Sections 2, 3, 4 and 8 open real pull requests, issues and workflow runs |
| `cp .env.example .env`, `./build.sh`, then `docker compose up -d` succeeds in `docket-local` | Section 6 needs a working client-visible capability; these are the repository's documented commands |
| <http://localhost:8080> accepts `johnd` / `foo` and `janed` / `ddd` | The shared-board demonstration needs two distinct users |
| The SonarQube Cloud organisation is accessible to the presenter | Section 3 may show current private project metrics; if it is not accessible, use the recorded GitHub Actions results |
| The Slack screenshot from card 21's controlled trigger is available, if the team retained one | The cloud account and its alarm history are gone; the issue comment is the durable textual evidence |

No AWS login, `kubectl` context or Argo CD session is required for this version
of the demo. Their former resources cannot be queried.

## 1. Architecture (2 min)

Open [`project-walkthrough.md`](project-walkthrough.md) and
[`logical-architecture.md`](logical-architecture.md). Narrate the five
services and the request path:

```text
frontend -> auth-api -> users-api
         -> todos-api -> Redis -> log-message-processor
```

Then open [`environments.md`](environments.md): one EKS cluster in
`us-east-1`, with `dev`, `staging` and `prod` as namespaces. State explicitly
that this is the architecture that ran before the account ended, not a live
environment on recording day.

## 2. Traceability: change -> build -> version -> deployment (4 min)

Use the last recorded production release as the spine of the demonstration.
It remains checkable without AWS:

1. Open `docket-todos-api` pull request #15 and commit `ea0cf8a`, the image-gate
   fix included in release 1.3.0.
2. Open GitHub Actions run `35555036762`; show that tests, the SonarQube gate,
   image build and image scan passed before publication.
3. Show the immutable service version with `git show v1.3.0` in
   `docket-todos-api`.
4. Open `docket-gitops/releases/todos-api/1.3.0.md`; it connects the version to
   the source pull requests, commits and image tag.
5. Open `docket-gitops` commit `c4759ad` and
   `environments/production/kustomization.yaml`; production declares
   `docket/todos-api:1.3.0` there.
6. Open `docket-gitops` pull request #52. Its gate, approval and sync comments
   record the promotion and the historical `Synced`/`Healthy` verification.

Do not query ECR or Argo CD: those resources are gone. The durable chain is
source commit -> successful workflow -> version tag and release note -> GitOps
revision -> recorded production sync.

## 3. CI pipeline and SonarQube (5 min)

Open one service's `.github/workflows/service-ci.yml` and show the job order:

```text
Tests -> SonarQube Cloud scan -> Build and scan -> publish/promote
```

`Build and scan` depends on both tests and the quality job. The quality job
waits for the server-side SonarQube Quality Gate; a failed gate therefore
produces no image. Show the same structure in a second service to demonstrate
that it is platform-wide, then open the successful card-11 workflow runs or
the private SonarQube dashboards if the presenter has access.

Show the current Trivy gate as well: every service blocks **HIGH and
CRITICAL** findings before publication. Do not repeat the former statement
that only CRITICAL findings block; that stopped being true on 21 September.

## 4. Security controls (3 min)

Show four controls and their limits:

1. service pipelines assume AWS roles through GitHub OIDC and contain no
   long-lived AWS access key;
2. HIGH and CRITICAL image findings block publication;
3. the production AppProject confines production to the GitOps repository,
   `prod` namespace and allowed namespaced kinds; and
4. the three public team repositories carry the branch protection recorded in
   [`standards/branch-protection.md`](standards/branch-protection.md).

Then state the remaining card-19 gap accurately. `docket-gitops` pull request
#45 declares a `production-approver` role, and `docket-infrastructure` pull
request #45 declares per-person local accounts and their bindings. Those
changes merged after the last infrastructure run, were never applied to the
retired cluster, and the source still leaves the shared Argo CD administrator
enabled. Production access is therefore designed but not proven restricted.

## 5. GitOps and environments (3 min)

Open `docket-gitops/environments/development`, `staging` and `production` side
by side. Show that they share bases but pin versions independently. Then show:

- automated sync for development and staging;
- manual sync for production;
- `docs/production-change-policy.md` for approval; and
- pull request #52 for the recorded release.

This is a repository walkthrough, not a live Argo CD demonstration. The last
runtime state is evidence on the release pull request; there is no current
Application object to inspect.

## 6. Task and case board (5 min)

Run the client-visible part locally from the current service `main` branches:

```bash
cd docket-local
cp .env.example .env
./build.sh
docker compose up -d
```

Open <http://localhost:8080> and perform this flow:

1. Log in as `johnd` / `foo`.
2. Create a task with case `case-demo-01`; confirm it starts in **Pending**.
3. Filter by that case.
4. Start the task; confirm it moves to **In progress**.
5. Assign it to `janed`; confirm the assignee badge changes.
6. In a separate browser session, log in as `janed` / `ddd`, filter by
   assignee and show the same shared task.
7. Create one task with a past deadline and one due within seven days; show the
   **Overdue** and **Upcoming** badges.
8. Complete the overdue task; its compliance state becomes **Completed**.

Cards 28 and 29 are done and their current local suites pass. The deadline
implementation exists and is tested, but card 30 remains open because the
agreed demonstration-environment evidence was never completed before AWS
ended. Say that distinction on camera.

Stop the local environment after recording:

```bash
docker compose down
```

## 7. Observability and operational alerts (4 min)

Use durable evidence rather than pretending CloudWatch is live:

- card 20's closure comment records the former Container Insights add-on,
  application log group and seven-day retention;
- `docket-infrastructure/stacks/ephemeral/alerts.tf` declares restart, CPU,
  memory and error-rate alarms;
- `docket-infrastructure/docs/operational-alerts.md` explains thresholds and
  the SNS -> Lambda -> Slack path; and
- card 21's 21 September comments record the failed encrypted-topic test, its
  fix, and the successful controlled ALARM and OK deliveries.

Card 20 is done. Card 21 remains open for one precise reason: the response an
operator should take for each alert is not documented. If the Slack screenshot
still exists, show it as historical evidence and label it with its date.

## 8. Production release flow (3 min, recorded evidence only)

Card 27 is done. Walk through the completed 21 September release without
dispatching a workflow or syncing anything:

1. Open workflow run `35572437557`; the deployed-development L2 gate and the
   full L3 suite against staging passed.
2. Open `docket-gitops` pull request #52; show its approval, gate evidence and
   sync record.
3. Show GitOps revision `c4759ad` and the five production image versions.
4. Show card 27's closing evidence: production was `Synced`/`Healthy`, all five
   Deployments were ready, and the public health checks passed at that time.

Do not run `gh workflow run`, `argocd app sync` or any Kubernetes write during
the demo. There is no live target, and the release record already supplies the
traceability this section is meant to show.

## 9. FinOps summary (2 min)

Open `docket-infrastructure/docs/infrastructure-costs.md`. Walk through the
shared EKS compute, NAT Gateway, two load balancers and usage-driven
observability lines, then the stated exclusions. The estimate is about
285--290 USD per continuously running month at the rates verified on 17
September. It is the cost of rebuilding and running the declared architecture,
not a current bill.

## Demo order and timing

| # | Section | Minutes | Running total |
|---|---|---|---|
| 1 | Architecture | 2 | 2 |
| 2 | Traceability | 4 | 6 |
| 3 | CI pipeline and SonarQube | 5 | 11 |
| 4 | Security controls | 3 | 14 |
| 5 | GitOps and environments | 3 | 17 |
| 6 | Task and case board | 5 | 22 |
| 7 | Observability and alerts | 4 | 26 |
| 8 | Production release evidence | 3 | 29 |
| 9 | FinOps summary | 2 | 31 |

Target 30 minutes with one minute of slack. Preserve section 6 if time runs
short: it is the only client-visible behavior in the recording.

## Fallbacks

| Problem | Response |
|---|---|
| `docket-local` does not start | Show the current implementation and the fresh L1/L2 test results; state that the capability could not be executed on the recording machine |
| A private SonarQube project cannot be opened | Show the quality job definition and its recorded successful GitHub Actions run |
| The Slack screenshot is unavailable | Show card 21's timestamped controlled-trigger evidence; do not recreate a screenshot |
| A GitHub page is slow | Keep the commit, pull request and workflow identifiers above open in separate tabs before recording |
| The recording runs long | Compress sections 1 and 9; do not omit the limitations in sections 4 and 7 |

## Recording and delivery

Record section by section. Keep the URL or repository path visible, and show
the command before its output. Use `localhost` only for section 6; every cloud
screen shown elsewhere is historical evidence and must be narrated in the past
tense.

Name the file `docket-demo-card36-<YYYY-MM-DD>.<ext>`. Link or attach the final
video on card 36. Card 36 can move to Done only after the recording visibly
shows the local client capability, the retained monitoring evidence and the
traceability flow above.

## What this demo does not claim

- The platform is currently deployed. It is not.
- The old ECR images, CloudWatch metrics, Terraform state or Argo CD history
  can be queried. They ended with the AWS account.
- Per-person production access was applied or verified. It was not, and card
  19 remains open.
- Card 21 is complete. Its alert delivery worked, but its operator-response
  documentation remains open.
- Card 30 is complete. The deadline feature exists, but its agreed
  demonstration-environment evidence is missing.
- The video exists until its link is attached to card 36.
