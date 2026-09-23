# Testing strategy

**Purpose** State the three levels of testing the project runs, where and when each one executes, and what makes it pass. [`AGENTS.md`](AGENTS.md) section 9 carries the exact, enforceable version of every rule referenced here; this document is the audit-facing summary.

## The three levels

| Level | Objective | Scope | Environment | Trigger |
|---|---|---|---|---|
| L1, Unit | Verify one function, class or component in isolation | No network, no container, no filesystem, no clock | None | Every push, every pull request |
| L2, Integration | Verify one service together with its real collaborators | A real but ephemeral double, such as a container, an in-memory store or a stub server, stands in for the collaborator | None; the double replaces it | Every pull request into `main` |
| L3, End to end | Verify a complete user journey through the actual front door | The frontend, the APIs and the queue, reachable through the gateway | A real, deployed environment | Before a promotion between environments |

The level a test belongs to depends on one rule. A test that needs a network call, a database, Redis or any process outside the one under test is L2 at minimum, no matter how small it looks. A test that never leaves the process is L1.

## Tooling per service

Each service uses the framework that fits its own stack. `auth-api`, `users-api`, `todos-api` and `log-message-processor`'s exact library per level is listed in [`AGENTS.md`](AGENTS.md) section 9.2.

`frontend` uses Jest with `@vue/test-utils` version 1 for L1. Its L2 suite (card 16) runs the same Vuex store, router and components against a plain Node HTTP server standing in for `auth-api` and `todos-api`, over a real socket, in `tests/integration/`. This entry has not yet reached `AGENTS.md`'s own copy of the tooling table; that file is canonical, distributed from [`standards/AGENTS.md`](standards/AGENTS.md) and updated at its source, a separate piece of work from this document.

L3 is a single suite for the whole platform, written in Playwright, in `docket-gitops/e2e`. It runs against a deployed environment only.

## What makes each level pass

L1 and L2 run together inside `service-ci`, in the same job, on every push and every pull request. A failing test at either level stops the job before an image is built, which blocks a merge into `main` and the image publish that follows it.

L3 runs inside `promote.yml`, in a job named `verify`, before a promotion pull request is written. A promotion from development to staging runs the suite's smoke scenarios against development's real host; a promotion from staging to production runs the full suite against staging's real host. A failing suite fails the job, and the promotion pull request never opens. The result is also written as a commit status named `verify` on the commit that deployed the version, which `gitops-ci` reads before allowing the corresponding manifest change to merge ([ADR-014](decisions.md#adr-014-promotion-between-environments)).

The mechanism has already been exercised for real, on its first use. On 16 September 2026, a dispatched promotion from development to staging failed at this exact step (`docket-gitops` run `35063141056`), and no promotion pull request opened. The cause that day was a shell compatibility bug in the job script, fixed within the hour and confirmed against the same dispatch afterward; the block itself held as designed.

## How this fits the environments and the pipeline

Promotion moves in one direction, from development to staging to production, as [`environments.md`](environments.md) describes. Each step needs the level below it already green. A version reaches development after L1 and L2 pass in `service-ci`. It reaches staging after L3's smoke suite passes against development. It reaches production after L3's full suite passes against staging, an approver reviews the manifest change, and a person syncs it manually.

[`pipelines.md`](pipelines.md) documents every pipeline in the project, including the four that gate a merge and the full mechanics of `verify`. This document isolates the testing part of that picture for a reader who needs the strategy on its own.

## Current state

Verified 23 September 2026, by running each suite.

| Service | L1 tests | L2 tests |
|---|---|---|
| `auth-api` | 19 | 14 |
| `users-api` | 19 | 11 |
| `todos-api` | 65 | 31 |
| `log-message-processor` | 13 | 7 |
| `frontend` | 72 | 8 |

259 tests across L1 and L2, all five services. `todos-api` and `frontend` carry most of the growth since the earlier counts. Cards 28, 29 and 30 added the shared board, the assignment of a task to a person and the deadlines, each with its own tests. Line coverage is reported per pull request by each service's own CI, not summarised here since a fixed number goes stale the moment it is written. Two rules define "sufficient" coverage. [`AGENTS.md`](AGENTS.md) section 9.4's ratchet keeps coverage on new code from falling below the service's existing overall coverage, and card 11's SonarQube quality gate, enforced in all five services since 20 September 2026, blocks the pipeline when the project's own threshold is missed.

L3 covers seven scenarios in `docket-gitops/e2e`, across `auth.spec.js`, `todos.spec.js` and `deadlines.spec.js`. Three are tagged smoke and run on every development to staging promotion; all seven run on every staging to production promotion.

Two related areas sit outside this strategy. Observability driven alerting, cards 20 and 21, is delivered and feeds operational response rather than test gating; `docket-infrastructure/docs/operational-alerts.md` holds the alarms, their thresholds and the action each one calls for. Per level ownership by a dedicated QA team does not apply here; one team covers all five services and all three levels.

## Related documents

[`AGENTS.md`](AGENTS.md) section 9 holds the exact rules this document summarises, including the scope vocabulary for test-related commits and the standing rules an agent writing tests must follow. `docket-gitops/e2e/README.md` holds the L3 suite's scenarios one by one. [`environments.md`](environments.md) describes the three namespaces and the promotion path in full. [`pipelines.md`](pipelines.md) describes every pipeline in the project, testing included.
