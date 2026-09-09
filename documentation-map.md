# Documentation map

Where every piece of project documentation lives, and which of the nine areas it
answers. Area 09 asks for complete project documentation; the documentation
itself is spread across five repositories by design, so this is the single index
into it.

## By repository

### `docket-architecture` — this repository

The reference architecture and the decisions behind it.

| Document | Contents | Area |
|---|---|---|
| [`logical-architecture.md`](logical-architecture.md) | The five services, the queue, the call graph and the supporting platform | 01, 03 |
| [`environments.md`](environments.md) | Namespaces, boundaries between environments, GitOps flow, secrets, DNS | 02, 04 |
| [`aws-infrastructure.md`](aws-infrastructure.md) | Network, EKS, registry, state backend, identity, secrets, budget | 02, 08, 09 |
| [`decisions.md`](decisions.md) | Eleven ADRs with context, consequences and rejected alternatives | 09 |

### `docket-infrastructure` — infrastructure as code

| Document | Contents | Area |
|---|---|---|
| `README.md` | Repository map and apply order | 02 |
| `CONVENTIONS.md` | Naming, tags, providers, variables, versions, which stack each resource belongs to | 02 |
| `OPERATIONS.md` | Start-up and shutdown, cluster access, orphan checking, domain and TLS | 02, 09 |
| `docs/TERRAFORM-IAC-BEST-PRACTICES.md` | The long-form Terraform standard, with sources | 02 |
| `docs/IAM-POLICY-VALIDATION.md` | What is still needed before the scoped deploy policy replaces the broad one | 08 |
| `modules/*/README.md` | One per module: inputs, outputs and the decisions inside it | 02 |
| `stacks/*/README.md` | One per stack: state key, lifecycle, what it contains | 02 |

### `docket-terraform-modules` — reusable modules, public

| Document | Contents | Area |
|---|---|---|
| `README.md` | What the repository holds, why it is public, and how to consume a module by tag | 02 |
| `modules/*/README.md` | One per module: inputs, outputs and the decisions inside it | 02 |

### `docket-gitops` — deployment manifests

| Document | Contents | Area |
|---|---|---|
| `README.md` | What the repository holds and the ownership boundary against infrastructure | 04 |
| `docs/argocd-development.md` | The development environment end to end: architecture, access, validation, troubleshooting | 04 |

### `docket-roadmap` — planning and evidence

| Document | Contents | Area |
|---|---|---|
| `README.md` | Index of the 48 cards with their board status | 01 |
| `stories/` | One file per card, with its acceptance criteria as written | 01 |
| `iterations/` | What each iteration committed to, what shipped, what did not, and what the retrospective found | 01 |

### `docket-ai-sdd` — process

| Document | Contents | Area |
|---|---|---|
| `README.md` | The SDD flow step by step, and how to open a session | 01 |
| `docs/sintratel-docket-brief.md` | The client brief and the nine areas | — |
| `docs/sdd-adoption.md` | Where SDD starts applying, and why no retroactive specs | 01 |
| `specs/` | Spec, plan and tasks per story | 01 |

### Every repository

| Document | Contents | Area |
|---|---|---|
| `AGENTS.md` | The engineering constitution: language, branching, commits, pull requests, Terraform, testing, security, definition of done | 01, 02, 05, 08 |
| `CONTRIBUTING.md` | The repository-local short form for human contributors | 01 |

## By area

| # | Area | Where it is documented |
|---|---|---|
| 01 | Agile methodology and branching | `AGENTS.md` §4–6, `docket-roadmap`, `docket-ai-sdd` |
| 02 | Infrastructure as code | `docket-infrastructure` in full, `aws-infrastructure.md` |
| 03 | Design patterns | `logical-architecture.md`. **Largely undocumented; open work** |
| 04 | Continuous integration and deployment | `environments.md`, `docket-gitops`, the CI workflows |
| 05 | Testing strategy | `AGENTS.md` §9. **No test suites yet beyond two Terraform modules** |
| 06 | Change management and release notes | **Not started** |
| 07 | Observability and monitoring | `logical-architecture.md`, target only. **Not deployed** |
| 08 | Security | `AGENTS.md` §7.10 and §10, `policy/docket.rego`, `decisions.md` ADR-002, 006, 011 |
| 09 | Documentation and presentation | This map. **Operations manual and cost analysis partially covered by `OPERATIONS.md` and `aws-infrastructure.md`** |

Areas 03, 05, 06 and 07 are named here with their gaps stated rather than
omitted, so the map reports the real coverage instead of implying completeness.
