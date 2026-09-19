# Demo runbook

**Purpose** A practical script for the technical demo and the demonstration
video, card 36. It sequences what to show, the exact commands and screens,
what a healthy run looks like, and what to do when something does not
cooperate live. It is not the video itself — recording it is a manual step
outside what this repository can produce — and it is not a slide deck; card
36 asks for a script, not slides.

**Read this first: what the demo can honestly show today.** Two capabilities
this script walks through are implemented but not yet deployed anywhere:
the task and case board (card 28) and task assignment (card 29) exist as
reviewed-ready local commits on feature branches in `docket-todos-api` and
`docket-frontend`, not yet pushed, opened as pull requests, or merged. Until
they are, section 6 below demonstrates them against a local instance
(`docket-local`) built from those branches, not against `dev`. Section 8
(production release) is a walkthrough of a release that has not happened:
card 27 is genuinely open, blocked on two promotion-gate gaps described
there, not merely unpushed work. Say this plainly during the recording
rather than presenting either as further along than it is.

## 0. Before recording

| Check | Why |
|---|---|
| `dev` is `Synced` and `Healthy` in Argo CD | The walkthrough opens there; a broken `dev` derails everything after it |
| The SonarQube Cloud org (`sintratel-docket-platform`) is reachable and `auth-api` and `users-api` show a passed Quality Gate | The only two services with `SONAR_TOKEN` provisioned end to end today (see section 3) |
| The most recent Slack message in the alerts channel from card 21's controlled trigger test is still visible, or its screenshot is on hand | Section 7 shows it; Slack retention may have scrolled it out of easy reach |
| `docket-local` builds cleanly from `feat/29-task-assignment` in `docket-todos-api` and `docket-frontend` | Section 6 runs against it, not against a deployed environment |
| A terminal with `gh` authenticated against `sintratel-docket-platform` and `kubectl`/Argo CD access to `dev` | Sections 2, 4 and 5 run real commands, not screenshots of old ones |

## 1. Architecture (2 min)

Open `docket-architecture/logical-architecture.md` alongside a browser tab on
`dev.docket.<domain>`. Narrate the five services and the one path a request
takes: `frontend` → `auth-api` (login) or `todos-api` (task actions), with
`todos-api` publishing to Redis, and `log-message-processor` consuming it.
Point at the diagram, not just the page, so the audience sees the shape
before the deep dive.

State once, so it frames everything after: one EKS cluster, `us-east-1`,
three namespaces (`dev`, `staging`, `prod`), Argo CD synchronising all three
from `docket-gitops`. Everything from here on is one of those three
namespaces, or the pipeline that fills them.

## 2. Traceability: change → build → version → deployment (4 min)

The spine of the whole demo — do this before anything else feature-shaped,
so later sections can point back to it instead of re-deriving it.

1. Pick any recent commit on `main` in `docket-todos-api`: `git log --oneline -1 main`.
2. Show its Actions run: `gh run list -R sintratel-docket-platform/docket-todos-api -b main -L 1`, then open it.
3. Point at the version the run published, `v<version>`, and the matching tag: `git show v<version>`.
4. Show the same version in ECR: `aws ecr describe-images --repository-name docket/todos-api --image-ids imageTag=<version> --query 'imageDetails[0].imagePushedAt'`.
5. Show it declared in `docket-gitops`: the commit the pipeline wrote into `environments/development/kustomization.yaml`, and the matching `releases/todos-api/<version>.md` release notes.
6. Close the loop in Argo CD: the `todos-api` `Application` in `dev`, `Synced`, its running image tag matching step 4.

One sentence ties it together: a version name is never assigned twice, the
image Trivy scanned is the exact image ECR holds and Argo CD deployed, and
every step traces back to the one commit in step 1.

## 3. CI pipeline and SonarQube (5 min)

Open a pull request against `docket-auth-api` (or reuse an existing closed
one) and walk its checks top to bottom: `Tests` (install, suite, coverage
artifact), `SonarQube Cloud scan` (re-run with coverage, submitted to
SonarQube Cloud, Quality Gate awaited), `Build and scan` (image built
in-runner, Trivy blocks on CRITICAL, publishes only on a push to `main`).
Show the Quality Gate passed badge on the SonarQube Cloud project page for
`sintratel-docket-platform_docket-auth-api`.

State the honest coverage across the platform: `auth-api` and `users-api`
have `SONAR_TOKEN` provisioned and a green gate today. `todos-api`,
`log-message-processor` and `frontend` carry the identical `quality` job
and a real `sonar-project.properties`, committed and locally validated, but
still need a SonarQube Cloud project and token provisioned before their
pipeline runs it — that provisioning is external and outside this
repository's reach. Show the code (the `quality` job in
`todos-api/.github/workflows/service-ci.yml`) rather than a pipeline run
that cannot exist yet for those three.

## 4. Security controls (3 min)

Show, in order: the `Report HIGH and CRITICAL findings` and
`Block on CRITICAL` Trivy steps in the same pipeline run from section 3; the
OIDC role assumption step (`Assume the build role`) and note there is no
long-lived AWS credential in any service repository's secrets
(`gh secret list -R sintratel-docket-platform/docket-todos-api`, pointing
out only `GITOPS_APP_PRIVATE_KEY` and the two Slack webhooks are present);
`CODEOWNERS` in `docket-gitops` gating the manifest repository.

State plainly, do not gloss over it: the two remaining production-access
controls — a dedicated Argo CD `production-approver` role and per-person
Argo CD accounts for production sync — are implemented and reviewed-ready
but still open as `docket-gitops` PR #45 and `docket-infrastructure` PR #45,
pending merge. Show the diffs, not a merged state that does not exist yet.

## 5. GitOps and environments (3 min)

Open `docket-gitops` and show `environments/development`,
`environments/staging`, `environments/production` side by side: identical
structure, different pinned versions. Show the Argo CD UI (or
`argocd app list`) with all three `Application` objects, and point out
`dev` and `staging` on automated sync, `prod` on manual. Narrate the two
independent controls production carries: a reviewed, approved pull request
merging the manifest change, and a separate, later, human-triggered sync —
two auditable acts, not one.

Reference `environments.md`'s boundary table for the one thing worth saying
aloud: isolation is namespace-level only, so this is one cluster carrying
three environments, not three clusters.

## 6. Task and case board, with assignment (5 min)

The client-visible capability the acceptance criteria ask for. Run it from
`docket-local` on `feat/29-task-assignment` in both `docket-todos-api` and
`docket-frontend` — say once, clearly, that this is a local build of
reviewed-ready work, not the deployed `dev` environment, and why (section 0
and the note at the top of this document).

1. Log in, land on the task board: three columns, Pending / In progress /
   Done, not a flat list.
2. Create a task with a case tag (`case-demo-01`). It appears in Pending.
3. Filter the board by that case; only the new task remains.
4. Click `Start` — it moves to In progress via a real `PATCH /todos/:id`,
   visible in the browser's network tab if the audience wants proof.
5. Assign it to a second username in the assignment field; the badge
   updates from `Unassigned`.
6. Open the board as that second user (a second browser session, logged in
   separately) and filter by assignee: the task the first user created is
   visible — the point of card 29, and only possible because card 28
   replaced the old per-user-siloed storage with one shared board.

## 7. Observability and operational alerts (4 min)

**Observability, card 20, closed.** Show the `/health` endpoint on two
services (`curl https://dev.docket.<domain>/health`, and the worker's
heartbeat file if a shell is available: `kubectl exec` into the
`log-message-processor` pod in `dev`, `stat /tmp/heartbeat`). Open the
CloudWatch Container Insights view for the `dev` namespace: pod-level CPU,
memory, and the aggregated application logs it collects, queryable there.

**Operational alerts, card 21, closed.** Show the alert configuration (the
threshold and the channel it posts to) and then the proof already on hand
from section 0: the Slack message from the card's own controlled trigger
test. Narrate what it demonstrates: a real degrade condition, detected, and
routed to a channel distinct from the pipeline's own build/deploy
notifications — the acceptance criterion is that alerts are
distinguishable from pipeline noise, not merely present.

## 8. Production release flow (3 min, walkthrough only — no sync)

State the header sentence first: **this section is a walkthrough of a
release that has not happened.** Card 27 is open, not merely unpushed.

Show `docket-gitops/.github/workflows/promote.yml` and the real dispatch
that would move a version from `staging` into `production`:

```bash
gh workflow run promote.yml -R sintratel-docket-platform/docket-gitops \
  -f target=production -f services=auth-api,users-api,todos-api,log-message-processor,frontend
```

Narrate what it does without running it against `production`: resolves the
source environment, runs the L3 gate (the full suite for a production
promotion, the smoke suite for staging), and on a pass opens a pull request
with a `Gate evidence:` comment. Merging that pull request needs an
approval from a named approver (`docs/production-change-policy.md` in
`docket-gitops`); the sync itself is a second, separate, manual act.

Then state the actual blocker, from the card's own reopening comment and
`AGENTS.md` section 9.5: the documented `main → dev` gate requires blocking
on HIGH-severity Trivy findings, and every service today blocks only on
CRITICAL; and the documented `dev → staging` gate requires "L2 green
against `dev`," which does not exist — L2 only runs pre-deployment, inside
CI, never against the environment it actually deployed to. Closing card 27
needs one of: implementing both gates across all five services, or a
reviewed amendment to `AGENTS.md`'s own standard. Neither is a slide-level
detail to skip past; it is the reason there is no production release to
show yet.

## 9. FinOps summary (2 min)

Show `docket-infrastructure` PR #46, `docs(costs): estimate infrastructure
costs from the running architecture` — code-complete, reviewed-ready,
pending merge like the two security PRs in section 4. Walk its cost
breakdown page: the fixed floor (EKS control plane, the NAT gateway, the
Route 53 zone), the components that scale with usage (node hours, load
balancer, data transfer), what stays inside the AWS free tier at this
scale, and the explicit assumptions the estimate is built on — single
cluster, `us-east-1`, on-demand nodes, no reserved capacity. Say plainly
that these are estimates against the documented architecture, not a billed
invoice, and that the PR names its assumptions rather than presenting a
single number as fact.

## Demo order and timing

| # | Section | Minutes | Running total |
|---|---|---|---|
| 1 | Architecture | 2 | 2 |
| 2 | Traceability | 4 | 6 |
| 3 | CI pipeline and SonarQube | 5 | 11 |
| 4 | Security controls | 3 | 14 |
| 5 | GitOps and environments | 3 | 17 |
| 6 | Task and case board, with assignment | 5 | 22 |
| 7 | Observability and operational alerts | 4 | 26 |
| 8 | Production release flow (walkthrough) | 3 | 29 |
| 9 | FinOps summary | 2 | 31 |

Target duration **30 minutes**, one minute of slack. Sections 1, 8 and 9 are
the first to trim if running long — they are narration over static
material, not live systems that need to be seen working. Section 6 is the
last to trim; it is the one capability the acceptance criteria name
explicitly ("at least one capability visible to the client").

## Fallback plan

| If this fails live | Do this instead |
|---|---|
| `dev` is not `Synced`/`Healthy` when recording starts | Fix it before recording rather than narrating around it — an unhealthy environment undermines section 2 and 5 together. If there is truly no time, use the most recent screenshot of a healthy state and say so on camera. |
| A live `kubectl`/Argo CD command errors on stage | Fall back to a screenshot taken during the pre-check in section 0; do not debug cluster access live. |
| `docket-local` does not build cleanly from the feature branches for section 6 | Show the code (the diff, the new endpoints, the passing local test suite) instead of the running UI, and say why. A narrated diff is honest; a silently skipped section is not. |
| The SonarQube Cloud UI is slow or briefly down | Screenshot from the pre-check stands in; narrate live only what is actually live. |
| Slack's history has scrolled past the card 21 trigger-test message | Use the screenshot captured in the pre-check (section 0). |
| Running well past 30 minutes | Cut section 1 to the diagram alone, cut section 9 to the one summary sentence, and skip the `promote.yml` file read-through in section 8 down to the narration. |

## What this demo does not claim

- Card 30 (deadlines and compliance status) is one of card 36's own
  dependencies and is still open; nothing here shows it, and the video
  should not imply otherwise.
- Cards 28 and 29 are demonstrated locally, not from a deployed
  environment, until their pull requests are opened, reviewed and merged.
- Card 27 is a walkthrough of a release procedure, not a completed
  release; production has not been synced by this work.
- `todos-api`, `log-message-processor` and `frontend` carry the SonarQube
  Cloud job in code, but it has not run for real yet, pending external
  token provisioning.
