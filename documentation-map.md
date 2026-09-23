# Documentation map

Where every piece of project documentation lives, and which of the nine areas
it answers. Area 09 asks for complete project documentation; the
documentation itself is spread across thirteen repositories by design, so
this is the single index into it. The reviewers of this project have read
access to the private repositories, so every entry below links directly to
its file.

## By repository

### `docket-architecture`, this repository

The reference architecture, the decisions behind it, and the walkthrough that
ties everything together.

| Document | Contents | Area |
|---|---|---|
| [`project-walkthrough.md`](project-walkthrough.md) | The final presentation: the client's problem, what was built area by area, results with evidence, limitations, coverage against the course brief | 09 |
| [`logical-architecture.md`](logical-architecture.md) | The five services, the queue, the call graph and the supporting platform | 01, 03 |
| [`environments.md`](environments.md) | Namespaces, boundaries between environments, GitOps flow, secrets, DNS | 02, 04 |
| [`aws-infrastructure.md`](aws-infrastructure.md) | Network, EKS, registry, state backend, identity, secrets, budget | 02, 08, 09 |
| [`design-patterns.md`](design-patterns.md) | The patterns the services and the platform apply, with the file that implements each and the tests that check them | 03 |
| [`pipelines.md`](pipelines.md) | The ten pipelines, how they connect, the test pyramid, six sequence diagrams and the gate table | 04, 05, 06, 09 |
| [`testing-strategy.md`](testing-strategy.md) | The three test levels, where and when each runs, what makes it pass, current counts per service | 05, 09 |
| [`decisions.md`](decisions.md) | 25 ADRs with context, consequences and rejected alternatives | 09 |
| [`project-retrospective.md`](project-retrospective.md) | The ADRs grouped by theme, current limitations consolidated from four repositories, and a ranked list of future improvements | 09 |
| [`demo-runbook.md`](demo-runbook.md) | The technical demo script: order, commands, expected screens, timing, fallback plan, and what it does not claim | 09 |

### `docket-architecture/standards`, the engineering standards, here

The canonical source every repository distributes from.

| Document | Contents | Area |
|---|---|---|
| [`standards/README.md`](standards/README.md) | Index of the standards, why the constitution is copied rather than linked, how to change one | 01 |
| [`standards/AGENTS.md`](standards/AGENTS.md) | The engineering constitution: language, branching, Conventional Commits, pull requests, Terraform, GitOps, testing, security, definition of done | 01, 02, 05, 08 |
| [`standards/terraform-iac-best-practices.md`](standards/terraform-iac-best-practices.md) | The long-form Terraform standard with rationale and sources | 02 |
| [`standards/templates/README.md`](standards/templates/README.md) | Index of the files distributed to each repository: CI workflows, linter and scanner configuration, OPA policy, PR template, CODEOWNERS | 01, 02, 04 |
| [`standards/branch-protection.md`](standards/branch-protection.md) | The state of branch protection per repository, the justification for each open gap, and the ready-to-run commands that close them | 01, 08 |

### [`docket-infrastructure`](https://github.com/sintratel-docket-platform/docket-infrastructure), infrastructure as code, private

| Document | Contents | Area |
|---|---|---|
| [`README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/README.md) | Repository map and apply order | 02 |
| [`CONVENTIONS.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/CONVENTIONS.md) | Naming, tags, providers, variables, versions, which stack each resource belongs to | 02 |
| [`GETTING-STARTED.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/GETTING-STARTED.md) | Install, configure, deploy and tear down, start to finish | 02, 09 |
| [`OPERATIONS.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/OPERATIONS.md) | Start-up and shutdown, cluster access, orphan checking, domain and TLS, secret rotation | 02, 09 |
| [`docs/TERRAFORM-IAC-BEST-PRACTICES.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/TERRAFORM-IAC-BEST-PRACTICES.md) | The long-form Terraform standard, with sources | 02 |
| [`docs/IAM-POLICY-VALIDATION.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/IAM-POLICY-VALIDATION.md) | What is still needed before the scoped deploy policy replaces the broad one | 08 |
| [`docs/security-controls.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/security-controls.md) | Per-identity security record and the residual risk register (R1 to R17) | 08 |
| [`docs/operational-alerts.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/operational-alerts.md) | The four operational alarms, their thresholds, delivery pipeline and how to test one | 07 |
| [`docs/infrastructure-costs.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/docs/infrastructure-costs.md) | Cost estimate and analysis per environment | 09 |
| [`policies/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/policies/README.md) | The OPA policies enforced in Terraform CI | 08 |
| [`scripts/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/scripts/README.md) | The operational scripts and what each one checks | 02 |
| [`stacks/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/README.md) | The seven stacks, their apply order and dependencies | 02 |
| [`stacks/bootstrap/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/bootstrap/README.md) | State backend and the pipeline identity | 02 |
| [`stacks/persistent/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/persistent/README.md) | Network, DNS and the registry: what survives a destroy | 02 |
| [`stacks/ephemeral/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/ephemeral/README.md) | The EKS cluster and its OIDC provider: what is routinely destroyed and reapplied | 02 |
| [`stacks/platform/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/platform/README.md) | Controllers, Argo CD, notifications and the observability add-on, installed with Helm | 02, 07 |
| [`stacks/platform/charts/gateway-api-crds/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/platform/charts/gateway-api-crds/README.md) | The Gateway API custom resource definitions chart | 02 |
| [`stacks/platform/charts/gateway-class/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/platform/charts/gateway-class/README.md) | The shared `GatewayClass` chart | 02 |
| [`stacks/environments/dev/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/environments/dev/README.md) | The development namespace, quota and secrets | 02 |
| [`stacks/environments/staging/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/environments/staging/README.md) | The staging namespace, quota and secrets | 02 |
| [`stacks/environments/prod/README.md`](https://github.com/sintratel-docket-platform/docket-infrastructure/blob/main/stacks/environments/prod/README.md) | The production namespace, its own gateway and project, quota and secrets | 02 |

### [`docket-terraform-modules`](https://github.com/sintratel-docket-platform/docket-terraform-modules), reusable modules, public

| Document | Contents | Area |
|---|---|---|
| [`README.md`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/README.md) | What the repository holds, why it is public, and how to consume a module by tag | 02 |
| [`modules/README.md`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/README.md) | Index of the eight modules | 02 |
| [`modules/network/README.md`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/network/README.md), [`cluster`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/cluster/README.md), [`registry`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/registry/README.md), [`ci-identity`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/ci-identity/README.md), [`irsa`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/irsa/README.md), [`namespace`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/namespace/README.md), [`environment`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/environment/README.md), [`dns`](https://github.com/sintratel-docket-platform/docket-terraform-modules/blob/main/modules/dns/README.md) | One README per module: inputs, outputs and the decisions inside it | 02 |

### [`docket-gitops`](https://github.com/sintratel-docket-platform/docket-gitops), deployment manifests, private

| Document | Contents | Area |
|---|---|---|
| [`README.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/README.md) | What the repository holds and the ownership boundary against infrastructure | 04 |
| [`docs/argocd-development.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/argocd-development.md) | The development environment end to end: architecture, access, validation, troubleshooting | 04 |
| [`docs/production-change-policy.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/production-change-policy.md) | Who may approve a production change, how the list narrows, the emergency path | 06, 08 |
| [`docs/production-operations.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/production-operations.md) | Syncing production, rollback, and what a production operator must never do | 04, 06 |
| [`docs/operations-manual.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/docs/operations-manual.md) | The day-to-day operations manual for the whole platform | 09 |
| [`releases/README.md`](https://github.com/sintratel-docket-platform/docket-gitops/blob/main/releases/README.md) | How release notes are generated and laid out, with a link to each service's folder and its latest version | 06 |

### [`docket-roadmap`](https://github.com/sintratel-docket-platform/docket-roadmap), planning and evidence, private

| Document | Contents | Area |
|---|---|---|
| [`README.md`](https://github.com/sintratel-docket-platform/docket-roadmap/blob/main/README.md) | Index of the 53 cards with their board status | 01 |
| [`stories/`](https://github.com/sintratel-docket-platform/docket-roadmap/tree/main/stories) | One file per card, with its acceptance criteria as written | 01 |
| [`iterations/`](https://github.com/sintratel-docket-platform/docket-roadmap/tree/main/iterations) | What each iteration committed to, what shipped, what did not, and what the retrospective found | 01 |
| [`plans/README.md`](https://github.com/sintratel-docket-platform/docket-roadmap/blob/main/plans/README.md) | Index of the cross-cutting plans | 01, 09 |
| [`plans/remediation-plan.md`](https://github.com/sintratel-docket-platform/docket-roadmap/blob/main/plans/remediation-plan.md) | The security and consistency remediation plan, with what is done and what remains | 08, 09 |
| [`plans/handover.md`](https://github.com/sintratel-docket-platform/docket-roadmap/blob/main/plans/handover.md) | The handover record between team phases | 01 |

Private because `plans/` names the account, the domain and findings that are
still open; the rest of the repository carries no such detail.

### [`docket-ai-sdd`](https://github.com/sintratel-docket-platform/docket-ai-sdd), process, private

The team's assisted workspace: specs, plans, tasks and the tooling behind
them. Excluded from this card's reachability check by the team lead's
decision of 21 September 2026; linked here for a reviewer who wants to see
how the process worked.

| Document | Contents | Area |
|---|---|---|
| [`README.md`](https://github.com/sintratel-docket-platform/docket-ai-sdd/blob/main/README.md) | The SDD flow step by step, and how to open a session | 01 |
| [`docs/sintratel-docket-brief.md`](https://github.com/sintratel-docket-platform/docket-ai-sdd/blob/main/docs/sintratel-docket-brief.md) | The client brief and the nine areas, in Spanish as delivered | n/a |
| [`docs/sdd-adoption.md`](https://github.com/sintratel-docket-platform/docket-ai-sdd/blob/main/docs/sdd-adoption.md) | Where SDD starts applying, and why no retroactive specs | 01 |
| [`docs/refactoring-prompt.md`](https://github.com/sintratel-docket-platform/docket-ai-sdd/blob/main/docs/refactoring-prompt.md) | The prompt used for the English migration refactor | 01 |
| [`specs/002-architecture-and-environments/`](https://github.com/sintratel-docket-platform/docket-ai-sdd/tree/main/specs/002-architecture-and-environments) | The reference example of a complete spec, plan and tasks | 01 |
| [`.claude/commands/`](https://github.com/sintratel-docket-platform/docket-ai-sdd/tree/main/.claude/commands) | The five SDD slash commands: specify, plan, tasks, implement and their supporting prompts | 01 |
| [`.agents/skills/`](https://github.com/sintratel-docket-platform/docket-ai-sdd/tree/main/.agents/skills) | The vendored Terraform skills the agent uses while writing infrastructure code | 02 |

### [`.github`](https://github.com/sintratel-docket-platform/.github), organisation defaults, public

| Document | Contents | Area |
|---|---|---|
| [`profile/README.md`](https://github.com/sintratel-docket-platform/.github/blob/main/profile/README.md) | The organisation's public profile: what Docket is and where to start | 09 |
| [`README.md`](https://github.com/sintratel-docket-platform/.github/blob/main/README.md) | What this repository holds and why it is public | 01 |
| [`.github/CONTRIBUTING.md`](https://github.com/sintratel-docket-platform/.github/blob/main/.github/CONTRIBUTING.md), [`PULL_REQUEST_TEMPLATE.md`](https://github.com/sintratel-docket-platform/.github/blob/main/.github/PULL_REQUEST_TEMPLATE.md) | Defaults for public repositories that carry no copy of their own | 01 |

### Every repository

| Document | Contents | Area |
|---|---|---|
| `AGENTS.md` | The engineering constitution: language, branching, commits, pull requests, Terraform, testing, security, definition of done | 01, 02, 05, 08 |
| `CONTRIBUTING.md` | The repository-local short form for human contributors, pointing at the canonical constitution | 01 |
| `.github/pull_request_template.md` | The pull request checklist, identical across repositories | 01 |

## By area

| # | Area | Where it is documented |
|---|---|---|
| 01 | Agile methodology and branching | `AGENTS.md` §4–6, `docket-roadmap` (53 cards, two recorded iterations), `docket-ai-sdd` |
| 02 | Infrastructure as code | `docket-infrastructure` in full, `docket-terraform-modules` (public, tagged releases through `v3.3.0`, module tests since card #46), `aws-infrastructure.md` |
| 03 | Design patterns | [`design-patterns.md`](design-patterns.md): the resilience, configuration and integration patterns the brief asks for, the ones the services and the platform apply, where they are tested, and what is deliberately absent |
| 04 | Continuous integration and deployment | `environments.md`, `docket-gitops`, the CI workflows, [`pipelines.md`](pipelines.md) |
| 05 | Testing strategy | [`testing-strategy.md`](testing-strategy.md), `AGENTS.md` §9. All five services carry L1 and L2 (147 tests), `docket-gitops/e2e` carries L3, all three gate promotion since card #17 |
| 06 | Change management and release notes | Delivered: semantic versioning ([ADR-013](decisions.md#adr-013-semantic-versioning-for-services-and-modules)), automated release notes ([ADR-019](decisions.md#adr-019-release-notes), `docket-gitops/releases/`), the production change policy and a documented rollback (`docket-gitops/docs/production-change-policy.md`, `production-operations.md` §7) |
| 07 | Observability and monitoring | Delivered differently from the original target: CloudWatch Container Insights replaces Prometheus and Grafana ([ADR-023](decisions.md#adr-023-observability-cloudwatch-container-insights)), four alarms to Slack (`docket-infrastructure/docs/operational-alerts.md`, card #21). Health endpoints since card #20. Zipkin is instrumented in `auth-api`; no tracing backend is deployed |
| 08 | Security | `AGENTS.md` §7.10 and §10, `policy/docket.rego`, `decisions.md` ADR-002, 006, 011, 021, 025; the per-identity record and the residual risk register (R1 to R17) live in `docket-infrastructure/docs/security-controls.md` (private). Branch protection on the three public repositories (card #39, ADR-025); the HIGH/CRITICAL image gate and the SonarQube quality gate are enforced in every service |
| 09 | Documentation and presentation | This map, [`project-walkthrough.md`](project-walkthrough.md) for the presentation itself, [`demo-runbook.md`](demo-runbook.md) for the demo script, `docket-infrastructure/docs/infrastructure-costs.md` for costs (card #33, in review), `docket-gitops/docs/operations-manual.md` and `docket-infrastructure/OPERATIONS.md` / `GETTING-STARTED.md` for operations (cards #31, #32) |

Areas 03 and 07 are named here with their gaps stated rather than omitted
(area 03 undocumented, area 07's tracing backend undeployed), so the map
reports the real coverage instead of implying completeness. Checked against
the repositories and the board on 21 September 2026.
