# Project retrospective

**Purpose** Consolidate the reasoning behind the platform, the limitations the team has knowingly accepted, and a ranked list of what to work on next. Written as input for the final presentation and for anyone auditing the project without reading every source document behind it.

## Key decisions

Twenty two ADRs live in [`decisions.md`](decisions.md), each with its own context, consequences and rejected alternatives. Grouped here by theme, with the shared reasoning behind each group; the individual justification stays in the ADR itself.

| Theme | ADRs | Shared reasoning |
|---|---|---|
| Compute, network and DNS | [001](decisions.md#adr-001-registry-amazon-ecr), [003](decisions.md#adr-003-one-shared-cluster-with-three-namespaces), [004](decisions.md#adr-004-compute-amazon-eks), [005](decisions.md#adr-005-multi-az-network-with-a-single-nat-gateway), [008](decisions.md#adr-008-dns-in-route-53-and-tls-with-acm) | Managed AWS services over self-hosted equivalents, and one shared cluster over one per environment, both chosen for a course budget and a two-week working window rather than production scale |
| Delivery pipeline and versioning | [007](decisions.md#adr-007-terraform-validation-with-ci-quality-gates), [009](decisions.md#adr-009-native-s3-state-locking), [010](decisions.md#adr-010-ephemeral-infrastructure-with-split-state), [011](decisions.md#adr-011-pipeline-credentials-with-oidc-and-an-iam-role), [012](decisions.md#adr-012-modules-in-their-own-repository-versioned-by-tag), [013](decisions.md#adr-013-semantic-versioning-for-services-and-modules), [019](decisions.md#adr-019-release-notes) | Every artifact, a Terraform plan, a module, a service image, a version, carries a reproducible identity and an automated check before it is trusted, rather than a person attesting to it by hand |
| Environments and promotion | [014](decisions.md#adr-014-promotion-between-environments), [015](decisions.md#adr-015-staging-shares-the-non-production-load-balancer), [017](decisions.md#adr-017-exposure-through-the-gateway-api), [018](decisions.md#adr-018-productions-argo-cd-project-gateway-and-restore-on-start), [022](decisions.md#adr-022-level-2-and-3-gates-run-inside-the-promotion-pipeline-not-reactively) | A version moves through development, staging and production by a Git change, never a live edit, and production carries the extra isolation (its own Argo CD project and gateway) the other two share to save cost |
| Security and change control | [002](decisions.md#adr-002-secrets-with-external-secrets-and-ssm-parameter-store), [006](decisions.md#adr-006-administrative-access-with-ssm-session-manager), [016](decisions.md#adr-016-production-approval-without-branch-protection), [020](decisions.md#adr-020-independent-approval-as-a-policy-parameter), [021](decisions.md#adr-021-security-controls-applied-and-the-ones-deferred-on-record) | Where the GitHub plan or the team's own size will not support a preventive control, the project records and audits instead, and states the resulting gap rather than claiming the control exists |

## Current limitations

Consolidated from four sources, each already checked against the current state of its own repository. `docket-gitops/docs/production-operations.md` section 8, `docket-gitops/docs/production-change-policy.md` section 10, `docket-infrastructure/docs/security-controls.md` section 7 (R1 through R16, the most detailed of the four), and `docket-architecture/pipelines.md`'s "What this leaves open" together cover it.

| # | Limitation | Impact if it is wrong | What would close it | Card |
|---|---|---|---|---|
| L1 | Argo CD is reached with one shared `admin` account; a sync names no individual | A sync nobody approved reaches an environment and the record cannot say who | Per-person Argo CD access | Accepted, no card. Card #19 recorded this risk without closing it |
| L2 | Three IAM users hold `AdministratorAccess`; the deploy role's own policy carries broad wildcard actions with no CloudTrail trail to validate a narrower one | A compromised credential or pipeline run can act on the whole AWS account | A role per task, assumed rather than held; a CloudTrail trail, then the scoped policy | Accepted, no card |
| L3 | Production approval is recorded and audited, not enforced by GitHub; while `independent-approval` is `not-required`, one person can request, approve, merge and sync a change alone | An unreviewed change reaches production | A paid GitHub plan for branch protection (#39); the parameter set back to `required` once a second approver is available | #39, ADR-020 |
| L4 | Every released image can carry HIGH severity findings; the pipeline blocks only CRITICAL. `users-api` alone carries 17, from Spring Boot 1.5.6, out of support since 2019 | A known vulnerability reaches production, `users-api`'s concretely | The `main → dev` gate raising its threshold; `users-api`'s dependency stack modernised | #49 for `users-api`; the gate itself has no card yet |
| L5 | No metrics, dashboards or alerts exist; the load balancer's health checks fail open for `auth-api` and `todos-api` | A failing service is noticed by a person, not by an alert, and unhealthy targets keep receiving traffic | The observability stack and real health endpoints | #20, #21, in progress |
| L6 | Production's todos live in memory inside `todos-api`; a restart loses every user's tasks | Data loss on any restart, including a routine node replacement | A real store behind `todos-api` | Accepted, no card |
| L7 | Namespace egress is not restricted | A compromised pod can reach the internet and exfiltrate data | An egress `NetworkPolicy` per namespace | Accepted, no card |
| L8 | Pod Security enforces `baseline`, not `restricted`; nothing sets `readOnlyRootFilesystem` | A pod can run with more privilege than it needs | `redis` given a security context, `enforce` raised, `readOnlyRootFilesystem` added service by service | Accepted, no card |
| L9 | No penetration test has been run, although the deliverables ask for one | An exposed flaw nobody looked for | An OWASP Top 10 pass over the application and infrastructure | Accepted, no card |
| L10 | The `allowed-users` SSM parameter is not managed by Terraform for staging or production (development was adopted and rotated on 15 September 2026) | Neither parameter is reproducible from code; a mistaken deletion breaks every login with no trace in a pull request | The same adoption development already had, one environment at a time | Accepted, no card |
| L11 | `renovate` and `sonarqubecloud` are installed organisation-wide, `renovate` with write access to contents and workflows | A compromised App could change a pipeline in any repository | Narrower, per-repository installation | Accepted, no card; related to #52 |
| L12 | Development, staging and the shared gateway's Argo CD Applications use the `default` project, which admits any destination | An Application could be pointed at another namespace and Argo CD would apply it | A dedicated project per non-production environment, matching production's own | Accepted, no card |
| L13 | IAM policy statement identifiers in `docket-terraform-modules` are still in Spanish | A consistency defect, no security impact; harder to read against `AGENTS.md` section 2 | Renamed statement identifiers, a module release | Accepted, no card |
| L14 | One shared EKS cluster serves all three environments | A cluster-wide incident reaches production alongside development and staging | A cluster per environment, or at minimum for production | Accepted, no card, [ADR-003](decisions.md#adr-003-one-shared-cluster-with-three-namespaces) |
| L15 | GitHub refused a direct collaborator's pull request approval on `docket-gitops`, even with write and admin access, as of 15 September 2026 | One fewer independent approver than the team's own access grants suggest | Unresolved; tracked as a known GitHub behaviour, not a misconfiguration found yet | Accepted, no card |

**Closed since first recorded.** `security-controls.md`'s own R10, "the level 2 and 3 gates are run by hand, with no `verify` status and no blocking," named cards #16 and #17 as what would close it. Both are done. The `verify` job inside `promote.yml` runs the suites and blocks a promotion pull request on failure, exercised for real on 16 September 2026. The source file itself, tied to card #19, is not edited here; this note reflects the current state without it.

## Prioritised future improvements

Ranked by impact if the underlying limitation stays wrong, from the table above, ahead of convenience or cosmetic fixes.

1. **Narrow the deploy role's IAM policy and remove standing `AdministratorAccess`** (L2). This carries the highest blast radius of anything on this list, since a single compromised credential can act on the whole account today.
2. **Enforce production approval** (L3), through branch protection once a paid GitHub plan is available, or a second team member before then.
3. **Modernise `users-api`'s dependency stack** (L4), the only concrete path that actually closes the 17 HIGH findings rather than continuing to accept them.
4. **Ship observability and alerting** (L5), already in progress as cards #20 and #21.
5. **Give `todos-api` a real data store** (L6), the one limitation on this list with a direct, visible cost to an end user.
6. **Per-person Argo CD access** (L1), which also closes the "who synced" gap named in three of the four source documents.
7. **Restrict namespace egress and raise Pod Security to `restricted`** (L7, L8), lower likelihood than the items above, real impact if exploited.
8. **Run a penetration test** (L9), required by the deliverables and not yet attempted.

Lower priority, real but smaller in impact or already partly mitigated. Narrower installation scopes for `renovate` and SonarQube (L11), a project per non-production Argo CD Application (L12), bringing `allowed-users` under Terraform for staging and production (L10), and the Spanish IAM statement identifiers (L13) all belong here.

Cards #28, #29 and #30 (a task-board feature area, deprioritised by the team lead while this documentation batch is in progress) and card #52 (Renovate has never actually run; its own card names the investigation needed before a fix is even scoped) are absent from this ranking because they are already decided, not because they are unimportant.

## Related documents

[`decisions.md`](decisions.md) carries every ADR's full reasoning. [`testing-strategy.md`](testing-strategy.md) covers the three test levels this retrospective does not repeat. `docket-gitops/docs/production-operations.md` and `production-change-policy.md`, and `docket-infrastructure/docs/security-controls.md`, are the limitations table's own sources, each more detailed on its own subject than this consolidation.
