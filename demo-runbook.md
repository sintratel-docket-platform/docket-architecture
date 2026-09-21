# Demo runbook

**Purpose** A practical script for the technical demo and the demonstration
video, card 36. It sequences what to show, the exact commands and screens,
what a healthy run looks like, and what to do when something does not
cooperate live. It is not the video itself — recording it is a manual step
outside what this repository can produce — and it is not a slide deck; card
36 asks for a script, not slides.

**Read this first: what the demo can honestly show today.** The task and
case board (card 28) and task assignment (card 29) are merged into `main`
in both `docket-todos-api` (#13, #14) and `docket-frontend` (#13, #14).
`docket-gitops`'s `dev` kustomization already references `docket/todos-api`
and `docket/frontend` at `1.2.0`, so the pipeline has written the deployment
— but this document was not able to confirm the running cluster is actually
`Synced` and `Healthy` at demo-prep time: no live Argo CD or `kubectl`
access to the real cluster was available when this section was last
written. Section 6 below gives two paths — verify `dev` yourself first
(section 0), and prefer it if it checks out; fall back to a local
`docket-local` build from `main` otherwise. Either way, say plainly on
camera which one you're using. Section 8 (production release) is a
walkthrough of a release that has not happened: card 27 is genuinely open,
blocked on two promotion-gate gaps described there, not merely unpushed
work. Say this plainly during the recording rather than presenting either
as further along than it is.

## 0. Before recording

| Check | Why |
|---|---|
| `dev` is `Synced` and `Healthy` in Argo CD, and its `todos-api`/`frontend` `Application`s report `1.4.0` (or newer), the version that carries card 30's deadlines | The walkthrough opens there; a broken `dev` derails everything after it. This also decides which path section 6 takes — real `dev` if this checks out, `docket-local` otherwise |
| The SonarQube Cloud org (`sintratel-docket-platform`) is reachable and all five services — `auth-api`, `users-api`, `todos-api`, `log-message-processor`, `frontend` — show a passed Quality Gate | All five carry the enforced `quality` job on `main` today (see section 3) |
| The most recent Slack message in the alerts channel from card 21's controlled trigger test is still visible, or its screenshot is on hand | Section 7 shows it; Slack retention may have scrolled it out of easy reach |
| If `dev` cannot be confirmed `Synced`/`Healthy`, `docket-local` builds cleanly from `main` in `docket-todos-api` and `docket-frontend` | Section 6's fallback path |
| A terminal with `gh` authenticated against `sintratel-docket-platform` and `kubectl`/Argo CD access to `dev` | Sections 2, 4, 5 and 6 run real commands, not screenshots of old ones |

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

State the coverage across the platform plainly: all five services —
`auth-api`, `users-api`, `todos-api`, `log-message-processor`, and
`frontend` — carry the identical `quality` job and a real
`sonar-project.properties`, merged into `main`, with a green Quality Gate.
Show a second project's passed gate alongside `auth-api`'s so the audience
sees this isn't one project standing in for the rest — `todos-api` and
`frontend` are the simplest to point at. Worth a mention if there's time:
Sonar's own GitHub Actions ruleset caught real supply-chain gaps in the CI
that installs each project's dependencies, not just in application code —
`todos-api`'s `quality` job now installs with `--ignore-scripts` and pins
the exact version it invokes, and `log-message-processor`'s installs from
a `pip-tools`-generated lock file with `--require-hashes`.

## 4. Security controls (3 min)

Show, in order: the `Report HIGH and CRITICAL findings` and
`Block on CRITICAL` Trivy steps in the same pipeline run from section 3; the
OIDC role assumption step (`Assume the build role`) and note there is no
long-lived AWS credential in any service repository's secrets
(`gh secret list -R sintratel-docket-platform/docket-todos-api`, pointing
out only `GITOPS_APP_PRIVATE_KEY` and the two Slack webhooks are present);
`CODEOWNERS` in `docket-gitops` gating the manifest repository.

State plainly: the two production-access controls — a dedicated Argo CD
`production-approver` role (`docket-gitops` PR #45) and per-person Argo CD
accounts for production sync (`docket-infrastructure` PR #45) — are merged
into `main` in both repositories. Show the merged diffs rather than the
open-PR view.

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

The client-visible capability the acceptance criteria ask for. Cards 28 and
29 are merged into `main` in both `docket-todos-api` and `docket-frontend`,
and `docket-gitops`'s `dev` kustomization declares both services at
`1.4.0`, which also carries card 30's deadlines (steps 7 to 10). Use whichever of the two paths below the section 0 check settled:

**Preferred — real `dev`.** If `dev` is confirmed `Synced` and `Healthy`
with both services at `1.4.0` or newer, run the steps below against
`https://dev.docket.<domain>` directly. This is the stronger demo: it's the
actual deployed platform, not a workstation build.

**Fallback — `docket-local`.** If `dev` could not be confirmed, build
`docket-local` from `main` (not a feature branch — the work is merged) in
both `docket-todos-api` and `docket-frontend`, and say plainly on camera
that this is a local build of merged, deployed-pending-verification code,
not the running `dev` environment.

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
7. Create a task with a deadline set a few days in the past. Its due-date
   badge shows that date, and its compliance badge reads `Overdue`.
8. Create a second task with a deadline set a few days from today, still
   inside the coming week. Its compliance badge reads `Upcoming`.
9. Filter the board by the `Overdue` compliance state; only the first task
   remains. Reset the filter afterward.
10. Click `Start` on the overdue task, then `Complete`. Its compliance
    badge changes to `Completed`, whatever its deadline. This is card 30's
    point: a finished task stops counting against the date that made it
    late.

If you ran this against real `dev`, see "Cleaning up demo data" below
before ending the recording session.

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

Show `docket-infrastructure`'s merged cost documentation (`docs(costs):
estimate infrastructure costs from the running architecture`, PR #46,
merged into `main`). Walk its cost breakdown page: the fixed floor (EKS
control plane, the NAT gateway, the Route 53 zone), the components that
scale with usage (node hours, load balancer, data transfer), what stays
inside the AWS free tier at this scale, and the explicit assumptions the
estimate is built on — single cluster, `us-east-1`, on-demand nodes, no
reserved capacity. Say plainly that these are estimates against the
documented architecture, not a billed invoice, and that the document names
its assumptions rather than presenting a single number as fact.

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
| `docket-local` does not build cleanly from `main` for section 6 | Show the code (the diff, the new endpoints, the passing local test suite) instead of the running UI, and say why. A narrated diff is honest; a silently skipped section is not. |
| The SonarQube Cloud UI is slow or briefly down | Screenshot from the pre-check stands in; narrate live only what is actually live. |
| Slack's history has scrolled past the card 21 trigger-test message | Use the screenshot captured in the pre-check (section 0). |
| Running well past 30 minutes | Cut section 1 to the diagram alone, cut section 9 to the one summary sentence, and skip the `promote.yml` file read-through in section 8 down to the narration. |

## Cleaning up demo data

Section 6 creates real records. If it ran against `docket-local`, the board
is in-memory and disappears when the local stack stops — nothing to clean
up. If it ran against real `dev`, the shared board persists across the
worker process's lifetime, so leave it tidy:

1. Identify the demo records: the task created with the case tag
   `case-demo-01`, and any task assigned to the second demo username used
   in step 5. The board's case filter (`Filter by case`) finds the first by
   itself; the assignee filter finds the second.
2. Remove each with the board's own delete control (the `X` button on the
   task) — the same `DELETE /todos/:taskId` the application always uses,
   nothing outside the app's own behavior.
3. Confirm the board no longer shows them, filtered or not.

This is application-level demo-data cleanup only. It does not touch
infrastructure, the cluster, or any other environment.

## Recording and delivery

No screen-recording tool or video-hosting platform is documented elsewhere
in this project, so none is prescribed here — use whatever is already
standard for the team (the OS's own screen recorder, OBS, or similar).

**Flow:** record section by section rather than one unbroken take, so a
mistake in one section only costs a re-record of that section, not the
whole video. Keep the browser and the terminal both visible where a
section uses both (sections 2 through 6, 8); full-screen the browser alone
where it doesn't (sections 1, 7, 9). Narrate in the first person, present
tense, describing what's on screen as it happens rather than summarizing
afterward.

**What should be visible:** the actual command text before it runs, not
just its output; the actual URL bar, so it's clear which environment
(`dev`, or `localhost` for the `docket-local` fallback) is on screen;
enough of each dashboard (SonarCloud, Argo CD, CloudWatch) to read the
relevant number or status, not a cropped corner of it.

**File naming:** `docket-demo-card36-<YYYY-MM-DD>.<ext>` for the raw
recording, so a re-record on a different day doesn't silently overwrite
the previous attempt.

**Where it's referenced:** link or attach the final video on the card 36
issue in `docket-roadmap`, the same place this project already records
evidence for other cards (for example, card 21's controlled-trigger-test
proof). Where the video file itself is hosted is a decision for whoever
finalizes it — this document does not assume a specific platform.

## What this demo does not claim

- Whether real `dev` was actually `Synced` and `Healthy` at recording time
  is only known once section 0's check is run that day — this document was
  written without live cluster access to confirm it in advance. Section 6
  says on camera which of its two paths was used.
- Card 27 is a walkthrough of a release procedure, not a completed
  release; production has not been synced by this work. The two
  promotion-gate gaps described there (`main → dev` blocking only on
  CRITICAL, not HIGH; no L2 gate against the deployed `dev` environment)
  are unresolved as of this writing.
