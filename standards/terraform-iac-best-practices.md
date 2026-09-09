# Terraform IaC Best Practices and AI Agent Rules

**Scope:** Docket platform (SINTRATEL) — standards for authoring, reviewing and deploying Terraform, and the rules AI agents must follow when they write it.
**Status:** Research baseline, 7 September 2026. Supersedes nothing; complements `docket-infrastructure/CONVENCIONES.md`.
**Audience:** Two. Engineers who set and review the standard, and AI coding agents that generate Terraform under it.

> **A note on language.** This document is written in English because it is new (zero migration cost), because objective 1 of the project review states English as the intended documentation standard, and because agent rule files conventionally sit in English alongside `AGENTS.md`. The rest of the project is currently in Spanish and that decision is still open — see the language finding in the platform review. If the team settles on Spanish, this is one file to translate, not fourteen directories to rename.

---

## Contents

- [1. How to use this document](#1-how-to-use-this-document)
- [2. Why AI changes the requirements](#2-why-ai-changes-the-requirements)
- [Part I — Core Terraform standards](#part-i--core-terraform-standards)
  - [3. Repository and file layout](#3-repository-and-file-layout)
  - [4. Naming](#4-naming)
  - [5. Variables and outputs](#5-variables-and-outputs)
  - [6. Resource authoring and block order](#6-resource-authoring-and-block-order)
  - [7. count and for_each](#7-count-and-for_each)
  - [8. Versions, providers and the lock file](#8-versions-providers-and-the-lock-file)
  - [9. Modules and composition](#9-modules-and-composition)
  - [10. State: backends, isolation, locking](#10-state-backends-isolation-locking)
  - [11. Secrets: keeping them out of state](#11-secrets-keeping-them-out-of-state)
  - [12. Refactoring without destroying](#12-refactoring-without-destroying)
  - [13. Testing](#13-testing)
  - [14. Version control hygiene](#14-version-control-hygiene)
- [Part II — Rules for AI agents](#part-ii--rules-for-ai-agents)
  - [15. The eight failure modes](#15-the-eight-failure-modes)
  - [16. Non-negotiable agent rules](#16-non-negotiable-agent-rules)
  - [17. Grounding the agent in truth](#17-grounding-the-agent-in-truth)
  - [18. Identity separation: the agent plans, a human applies](#18-identity-separation-the-agent-plans-a-human-applies)
  - [19. Drop-in rule block](#19-drop-in-rule-block)
- [Part III — The pipeline](#part-iii--the-pipeline)
  - [20. Gate order and tooling](#20-gate-order-and-tooling)
  - [21. Policy as code](#21-policy-as-code)
  - [22. Reviewing a plan](#22-reviewing-a-plan)
- [Part IV — Applied to docket-infrastructure](#part-iv--applied-to-docket-infrastructure)
  - [23. Conformance table](#23-conformance-table)
  - [24. Adoption order](#24-adoption-order)
- [25. Sources](#25-sources)

---

## 1. How to use this document

This is a standards document, not a tutorial. It has three jobs.

1. **Set the bar.** Part I is what correct Terraform looks like here, drawn from HashiCorp's official style guide and the community conventions that have converged around it.
2. **Constrain the agents.** Part II is the part that matters most for this project, and the part that generic Terraform guides omit. It is written as rules an agent can follow and a reviewer can check.
3. **Close the gap.** Part IV measures `docket-infrastructure` against Parts I–III and orders the work.

**Wiring it into the toolchain.** This file is the source of truth; it is not automatically loaded by anything. To make it operative:

- Reference it from `docket-ai-sdd/CLAUDE.md` so agent sessions inherit it.
- Paste [§19](#19-drop-in-rule-block) into the agent rule file verbatim — it is written to be copied, not summarised.
- Install HashiCorp's own Terraform agent skills rather than reimplementing them (`npx skills add hashicorp/agent-skills/plugins/terraform/skills/terraform-style-guide`, and likewise `terraform-test` and `refactor-module`).
- Add the Terraform MCP server so the agent reads provider schemas and module metadata from the registry instead of from memory (see [§17](#17-grounding-the-agent-in-truth)).

---

## 2. Why AI changes the requirements

Terraform best practice used to be mostly about maintainability: keep modules small, name things consistently, don't repeat yourself. Those still hold. But when a model writes the HCL, a second class of problem appears that no style guide was designed to catch.

A model produces plausible HCL. Plausible is not the same as valid, and neither is the same as correct for *this* account, *this* provider version, *this* state file. The failure is not that the code looks wrong — it is that it looks right.

Two industry numbers frame the risk. As of 2026, **93% of organisations report at least one AI-caused infrastructure incident, while 76% would apply AI-generated HCL to production with minimal or no review**. The gap between those figures is the entire problem, and it is a process problem, not a model problem.

The response is layered guardrails: constrain generation, then verify mechanically, then verify semantically, then have a human approve a *plan* rather than a diff. Each layer catches what the previous one cannot.

| Layer | Catches | Cannot catch |
|---|---|---|
| Agent rules (Part II) | Bad habits, unsafe commands, missing `moved` blocks | Anything the agent chooses to ignore |
| `terraform validate` | Hallucinated resource types and arguments, syntax, internal inconsistency | Wrong-but-valid values, bad IAM scoping, wrong workspace |
| Linters and scanners | Deprecated idioms, insecure defaults, missing encryption | Business intent |
| Policy as code | Semantic rules: no IAM wildcards, no `0.0.0.0/0`, mandatory tags | Whether the change was the *right* change |
| Plan review by a human | Blast radius, unintended destroys, intent mismatch | Nothing — this is the last gate, so it must not be skipped |

---

# Part I — Core Terraform standards

## 3. Repository and file layout

HashiCorp's recommended filenames, one responsibility each:

| File | Contents |
|---|---|
| `terraform.tf` | `required_version` and `required_providers` |
| `providers.tf` | `provider` blocks |
| `backend.tf` | Backend configuration |
| `main.tf` | Resources and data sources |
| `variables.tf` | Input variables, alphabetical |
| `outputs.tf` | Outputs, alphabetical |
| `locals.tf` | Local values |

Beyond a few hundred lines, split `main.tf` by logical group — `network.tf`, `compute.tf`, `storage.tf` — rather than growing one file.

`versions.tf` is a widespread community alternative to `terraform.tf` and is fine, provided it is used consistently across every root and child module in the repository. Consistency beats conformance here.

**Backends belong to root modules only.** A child module never declares `backend` or `provider`. It inherits both from the root that calls it. This is what makes a module reusable across environments.

## 4. Naming

Rules, in order of how often they are broken:

- **Never repeat the resource type in the name.** `resource "aws_route_table" "public"`, not `"public_route_table"`. The type is already the first label.
- **Underscores, lowercase.** In Terraform identifiers. Dashes belong in *values* that humans read — DNS names, tags — not in identifiers.
- **Singular nouns.** `aws_instance.web_api`, never `web_apis`, even when `for_each` creates many.
- **`main` or `this` as the fallback** when only one instance exists and no descriptive name adds information. `this` is the convention inside single-resource modules.
- **Descriptive over positional.** `web_api` beats `instance_1`.

```hcl
# Bad
resource "aws_instance" "webAPI-aws-instance" {}
resource "aws_instance" "web_apis" {}
variable "name" {}

# Good
resource "aws_instance" "web_api" {}
resource "aws_vpc" "main" {}
variable "application_name" {}
```

Reusable module repositories use the three-part registry name `terraform-<PROVIDER>-<NAME>`, e.g. `terraform-aws-ec2-instance`. This is mandatory for registry publication and harmless otherwise.

## 5. Variables and outputs

**Every variable declares `type` and `description`. No exceptions.** A variable without a description is an undocumented public interface.

```hcl
variable "environment" {
  description = "Target deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "database_password" {
  description = "Password for the database admin user"
  type        = string
  sensitive   = true
}
```

Additional rules:

- **A variable without a `default` is required.** Use that deliberately — it is the mechanism that forces a caller to make a choice.
- **No defaults that point at one concrete environment.** A default is for a value that is genuinely usually right, not for the value your account happens to use.
- **`sensitive = true`** on anything secret. It redacts CLI output; it does *not* keep the value out of state (see [§11](#11-secrets-keeping-them-out-of-state)).
- **`validation` blocks** for constrained inputs. They fail at plan time with a message you wrote, instead of at apply time with a provider error nobody can read.
- **`nullable = false`** where null is meaningless.
- **Plural names for collections**, singular for scalars.
- Prefer simple types over `object()` unless strict structural validation earns the complexity.

*A note on argument order:* HashiCorp's prose lists type before description, while HashiCorp's own agent skill and most community code put description first. Either is defensible. Pick one, apply it everywhere, and keep `validation` last.

**Outputs** carry a `description` and a `value`, plus `sensitive = true` where warranted. Keep the surface minimal: an output nobody consumes is a maintenance liability, so delete it. Name them `{name}_{type}_{attribute}` — `vpc_id`, `private_subnet_ids` — and use plurals for collections.

## 6. Resource authoring and block order

Inside a resource, arguments come before nested blocks, and the order is fixed:

1. `count` or `for_each` — meta-arguments first, followed by a blank line
2. Resource-specific arguments
3. `tags`, last among real arguments
4. Nested blocks
5. `lifecycle`
6. `depends_on`

```hcl
resource "aws_instance" "example" {
  count = 3

  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = local.common_tags

  root_block_device {
    volume_size = 20
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

Two spaces per level, no tabs. Align the equals signs of consecutive single-line arguments. Declare data sources before the resources that consume them, and dependent resources after the ones they reference — Terraform resolves order from the dependency graph, but humans read top to bottom.

Use `#` for comments. Not `//`, not `/* */`. Comment the non-obvious; do not narrate the obvious.

## 7. count and for_each

The distinction is not stylistic. It determines whether a change is safe.

**`for_each` for multiple distinct instances.** Keys are stable strings, so removing the second of three items removes exactly that item.

**`count` for conditional creation only** — the `var.enabled ? 1 : 0` idiom.

```hcl
# Bad — removing "web-2" reindexes "web-3" and destroys/recreates it
resource "aws_instance" "web" {
  count = var.instance_count
  tags  = { Name = "web-${count.index}" }
}

# Good — keys are stable, removals are surgical
resource "aws_instance" "web" {
  for_each = var.instance_names   # set(string)
  tags     = { Name = each.key }
}

# Good — count for a genuine on/off
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name = "high-cpu-usage"
  threshold  = 80
}
```

Both add indirection. Use them in moderation, and comment when the effect is not obvious at a glance.

## 8. Versions, providers and the lock file

```hcl
terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
```

- **Pin providers with `~>`.** Patch and minor upgrades flow; a major version bump becomes a deliberate act.
- **Set a `required_version` floor.** Track the latest minor release of Terraform unless a dependency holds you back. Relevant floors: 1.6 native tests, 1.7 mock providers, 1.10 ephemeral resources, 1.11 write-only arguments.
- **Commit `.terraform.lock.hcl` in every root module.** It is what makes two machines resolve the same provider builds. Exclude it from child modules, where it has no root to bind to and only drifts.
- **Always define a default (unaliased) provider.** Put every provider block in one file. If you use aliases, list the default first and make `alias` the first argument of the others.
- **Set `default_tags`** on the provider so tagging is declared once rather than per resource. Be aware it only reaches resources Terraform creates directly — anything an autoscaling group or a Kubernetes controller creates on your behalf needs explicit propagation.

## 9. Modules and composition

**Keep root modules thin: composition, not implementation.** A root module wires child modules together and holds the backend and provider configuration. Implementation lives in children.

**Small scope, small blast radius.** The unit of a root module is a set of resources with a shared lifecycle and a single owner. A change should touch exactly one environment and nothing else.

What belongs *inside* a module:

- Tightly coupled resources (a VPC and its subnets)
- Resources sharing a lifecycle
- A boundary you can describe in one sentence

What stays *outside*:

- Cross-cutting concerns — tagging, monitoring
- Resources with a different lifecycle
- Provider and backend configuration

Every module carries `variables.tf`, `outputs.tf` and a `README.md` documenting inputs, outputs and purpose. `terraform-docs` generates this from the code; hand-written is acceptable if it stays accurate.

Make inter-module dependencies explicit through variables and outputs, or through `terraform_remote_state` when the modules sit in separate states. Never duplicate the same literal in two places and hope they stay in sync.

## 10. State: backends, isolation, locking

Non-negotiable properties of a remote backend:

| Property | Why |
|---|---|
| Encryption at rest | State contains every attribute of every resource, including many secrets |
| Versioning | A corrupted apply is recoverable |
| Locking | Two concurrent applies against one state corrupt it |
| Access control | State access is effectively production read access |

Isolate state per environment and per lifecycle boundary. Separate directories with separate backend keys is the standard approach outside HCP Terraform. The goal is that a mistake in `dev` cannot cascade into `prod`.

Do not share whole state files between teams. Expose the specific values another configuration needs through outputs consumed by `terraform_remote_state`, or through provider data sources that query the live API.

On AWS, S3 now supports native state locking via `use_lockfile`, which removes the separate DynamoDB lock table that older guides require.

## 11. Secrets: keeping them out of state

This is the area where guidance has changed most, and where older documentation actively misleads.

`sensitive = true` redacts a value from CLI output. **It does not remove it from state.** For years the honest answer was "secrets end up in state; protect the state." That is no longer the whole story.

Terraform 1.10 introduced **ephemeral resources**, and 1.11 introduced **write-only arguments**. Together they let a provider use a secret during an operation without Terraform ever persisting it — not to state, not to the plan file.

```hcl
# The secret is fetched at runtime and never persisted
ephemeral "aws_secretsmanager_secret_version" "db" {
  secret_id = var.secret_arn
}

resource "aws_db_instance" "main" {
  # password_wo is write-only: it is sent to the API and then discarded
  password_wo         = ephemeral.aws_secretsmanager_secret_version.db.secret_string
  password_wo_version = var.password_version
}
```

The mechanics that trip people up:

- Write-only arguments require **explicit provider support per argument**. They are not a global Terraform feature you can apply anywhere; check the resource's documentation.
- Every `*_wo` argument pairs with a `*_wo_version` counterpart. Because Terraform cannot read the current value back, it cannot detect a change — you signal an update by incrementing the version.
- Values are write-only, so `terraform plan` will not show a diff when the underlying secret rotates. That is the intended behaviour, not a bug.

**Directly applicable here:** `aws_ssm_parameter` supports `value_wo` and `value_wo_version` (AWS provider 5.99.1+, Terraform 1.11+). This is a better fit than the common workaround of writing a placeholder value and adding `lifecycle { ignore_changes = [value] }`, because the placeholder pattern still puts whatever value Terraform last knew into state and leaves the parameter's real content outside Terraform's model entirely.

Independent of all this: never hardcode a credential in HCL, and never commit a `.tfvars` file containing one.

## 12. Refactoring without destroying

Terraform tracks resources by address. **Rename the address in the code and Terraform reads it as "destroy the old one, create a new one."** For a database or a NAT gateway that is an outage.

Use refactoring blocks, which record the change in the configuration itself:

```hcl
# Renaming a resource or moving it into a module
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web_api
}

# Dropping a resource from Terraform without destroying the real thing
removed {
  from = aws_s3_bucket.legacy

  lifecycle {
    destroy = false
  }
}

# Bringing an existing resource under management
import {
  to = aws_vpc.main
  id = "vpc-0123456789abcdef0"
}
```

`moved` blocks can be removed once every state has been applied through them. Until then they are load-bearing.

This is the single most important rule for AI-assisted refactoring, and it is restated as a hard rule in [§16](#16-non-negotiable-agent-rules).

## 13. Testing

Terraform's native framework (`.tftest.hcl`, 1.6+) validates module behaviour against temporary resources without touching real state.

```
modules/network/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    ├── defaults_unit_test.tftest.hcl          # plan mode — fast, no resources
    └── full_stack_integration_test.tftest.hcl # apply mode — creates real resources
```

Name files `*_unit_test.tftest.hcl` and `*_integration_test.tftest.hcl` so CI can filter the cheap ones from the expensive ones.

```hcl
run "nat_gateway_disabled" {
  command = plan

  variables {
    create_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 0
    error_message = "NAT gateway should not be created when disabled"
  }
}
```

Two modes: `plan` validates logic and costs nothing; `apply` creates real infrastructure and verifies it. Mock providers (1.7+) let plan-mode tests run with no credentials at all, which is what makes them viable as a PR gate.

Start with plan-mode tests on conditional logic, resource counts, and output shape. That is where refactors break, and it is where an agent's changes are least likely to be reviewed carefully.

## 14. Version control hygiene

**Never commit:**

- `terraform.tfstate`, `terraform.tfstate.backup`
- `.terraform/`
- `.terraform.tfstate.lock.info`
- Saved plan files (`*.tfplan`) — they can contain sensitive values
- `.tfvars` files with real values

**Always commit:**

- Every `.tf` file
- `.terraform.lock.hcl` (root modules)
- `.gitignore`
- Module `README.md`

---

# Part II — Rules for AI agents

This is the part that generic Terraform guides do not cover, and the part this project specifically needs.

## 15. The eight failure modes

Recurring patterns in AI-generated Terraform, as documented across HashiCorp, Scalr, Spacelift and Sonar during 2026:

| # | Failure | Why it happens | Caught by |
|---|---|---|---|
| 1 | **Hallucinated arguments** — attributes that do not exist in the pinned provider | The model interpolates a plausible schema | `terraform validate` |
| 2 | **Deprecated idioms** — superseded resource types and patterns | Training data is older than the provider | `tflint`, review |
| 3 | **Missing `moved` blocks** — a rename read as destroy-and-recreate | The model edits text, not addresses | Plan review only |
| 4 | **Overly broad IAM** — a wildcard because a scoped policy errored | Wildcards make the error go away | Policy as code |
| 5 | **Hardcoded values** — regions, account IDs, AMI IDs, CIDRs | The model needs *a* value and invents one | Review, linting |
| 6 | **Invented inputs** — guessed instance sizes, retention periods, CIDR ranges | Same cause, subtler symptom | Human review |
| 7 | **No state awareness** — code that ignores what already exists | The model sees files, not state | Plan review |
| 8 | **Wrong target** — right change, wrong workspace or account | Context was never established | Pre-flight check |

Note the asymmetry: **failures 3, 6 and 7 are invisible to every automated tool.** They surface only in the plan. That is why plan review is not optional.

## 16. Non-negotiable agent rules

### Always

1. **Read `.terraform.lock.hcl` and `required_providers` before writing a single line.** Every argument used must exist in the pinned provider version. Cite that version when referencing documentation.
2. **Use `moved` blocks to rename or relocate a resource.** Never a text find-and-replace on a resource address.
3. **Declare `type` and `description` on every variable, `description` on every output.**
4. **Run `terraform fmt -recursive` and `terraform validate` before presenting work as finished.**
5. **State the target explicitly** — which stack, which environment, which account, which region — before proposing a change.
6. **Prefer `for_each` over `count`** for multiple instances; reserve `count` for conditional creation.
7. **Pin versions.** New provider dependency, new pin.
8. **Surface every `destroy` and every replacement** in the plan, explicitly, in the summary given to the human. Never bury them.
9. **Say so when uncertain.** A named assumption is cheap; a silent guess is expensive. If a CIDR, an instance size or a retention period was not specified, ask — do not invent one and move on.

### Never

1. **Never run `terraform apply`.** The agent plans; a human applies. See [§18](#18-identity-separation-the-agent-plans-a-human-applies).
2. **Never run `terraform destroy`,** nor any operation that reduces to one.
3. **Never edit state directly** — no `terraform state rm`, `state mv` or `import` without explicit, in-the-moment authorisation.
4. **Never hardcode a credential, token, key or password,** not even a placeholder that looks real.
5. **Never widen an IAM policy to make an error go away.** A permissions error is a signal to scope precisely, not to add `*`.
6. **Never open a security group, endpoint or bucket to `0.0.0.0/0`** without the human asking for it in those words.
7. **Never loosen a version constraint** to resolve a conflict without saying that is what happened and why.
8. **Never commit `.tfstate`, `.tfvars` with real values, `.terraform/`, or a saved plan.**
9. **Never claim a plan succeeded without showing its output.**

### On being wrong

Provider schemas change faster than model training data. When `terraform validate` rejects an argument, **the provider is right and the model is wrong.** Read the schema — through the MCP server or the registry — and correct the code. Do not try alternative spellings of a hallucinated argument until one passes.

## 17. Grounding the agent in truth

An agent working from memory will drift. Three mechanisms pull it back to ground truth, in ascending order of strength.

**1. The lock file and provider schemas.** Cheapest and most effective. Before generating, read `.terraform.lock.hcl` to learn the exact provider builds in play, then check arguments against *that* schema.

**2. The Terraform MCP server.** HashiCorp's official MCP server exposes the Terraform Registry, provider schemas, module metadata and — for HCP Terraform users — workspaces and policies, as structured tool calls. Its purpose is precisely this: to ground agents in current, validated configuration data instead of probabilistic recall. It is the highest-leverage single addition to an AI-assisted Terraform workflow, and it directly addresses failure modes 1 and 2.

**3. A curated module registry.** The strongest form of grounding is removing the choice. When an agent composes vetted internal modules rather than authoring raw resources, the standards are enforced by construction, not by review.

Beyond tooling, keep the agent rule file honest. **Treat it as a failure log, not a wishlist** — the framing Mitchell Hashimoto popularised. Every time an agent makes the same mistake twice, the rule file is missing a line. That feedback loop is what makes agent guidance improve instead of ossify.

## 18. Identity separation: the agent plans, a human applies

The most important structural control, and the one most often skipped. Three identities, never merged:

| Identity | Capability |
|---|---|
| **Agent credentials** | Plan only. Read state, run `plan`. No apply, no destroy, no state mutation. |
| **Pipeline identity** | Runs the automated gates with platform credentials, keyless via OIDC. |
| **Human approver** | Approves a *specific saved plan*, not a branch or a pull request title. |

The binding matters: approval attaches to a concrete plan artifact. Approving "the PR" and then applying whatever `main` looks like at apply time is not an approval — it is a race condition with a signature on it.

For this project, the practical consequence is that the AWS role an agent can reach must not be the role that can apply. Today `GitHubActionsDeployRole` is a single identity with `iam:*`; splitting plan from apply is the structural fix.

## 19. Drop-in rule block

Paste into `docket-ai-sdd/CLAUDE.md` or an `AGENTS.md`. Written to be copied verbatim.

```markdown
## Terraform rules

Full standard: TERRAFORM-IAC-BEST-PRACTICES.md at the project root.

### Before writing
- Read `.terraform.lock.hcl` and `required_providers`. Every argument you use
  must exist in that pinned provider version. Cite the version you checked.
- State the target: which stack, which environment, which account, which region.
- If a value was not specified (CIDR, instance size, retention), ask. Do not invent it.

### While writing
- `type` + `description` on every variable. `description` on every output.
- `sensitive = true` on secrets. For values a provider supports it on, prefer
  write-only arguments (`*_wo` + `*_wo_version`) so nothing reaches state.
- `for_each` for multiple instances. `count` only for `enabled ? 1 : 0`.
- Renaming or moving a resource requires a `moved` block. Never rename the
  address in place — that is a destroy and recreate.
- Meta-arguments first, then arguments, then `tags`, then blocks, then
  `lifecycle`, then `depends_on`.
- No hardcoded account IDs, regions, AMI IDs or credentials. Variables or data sources.

### Before saying you are done
- `terraform fmt -recursive` and `terraform validate` both run clean.
- Show the plan. Call out every destroy and every replacement explicitly.
- If validate rejects an argument, the provider is right and you are wrong.
  Read the schema. Do not guess alternative spellings.

### Never
- `terraform apply` or `terraform destroy`. You plan; a human applies.
- `terraform state rm` / `state mv` / `import` without authorisation in the moment.
- Widening an IAM policy to clear a permissions error.
- Opening anything to `0.0.0.0/0` unless asked for in those words.
- Loosening a version constraint silently.
- Committing `.tfstate`, `.terraform/`, saved plans, or `.tfvars` with real values.
```

---

# Part III — The pipeline

## 20. Gate order and tooling

Gates run cheapest-first, so a formatting error costs two seconds rather than a full plan.

```
terraform fmt -check  →  terraform validate  →  tflint  →  Trivy / Checkov
                                                              ↓
     human approves saved plan  ←  speculative plan  ←  policy as code (OPA)
```

| Gate | Tool | Catches |
|---|---|---|
| Format | `terraform fmt -check -recursive` | Style drift |
| Validity | `terraform validate` | Hallucinated resources and arguments, syntax, internal inconsistency |
| Lint | `tflint` | Deprecated arguments, invalid instance types, provider-specific mistakes |
| Security | Trivy or Checkov | Misconfiguration: unencrypted storage, public exposure, missing logging |
| Policy | OPA / Sentinel | Organisational rules a scanner cannot know |
| Plan | `terraform plan` | Blast radius, ground truth |
| Approval | Human | Intent |

Tool notes worth having:

- **`terraform validate` is the highest-value gate against AI-specific failures.** It checks references against installed provider schemas, which is exactly the hallucinated-argument failure mode. It cannot catch semantically wrong values or the wrong workspace.
- **tfsec no longer exists as a standalone tool.** Aqua Security merged it into **Trivy** in 2023 and the tfsec repository redirects there. Guides recommending tfsec are out of date.
- **Trivy scans both container images and IaC files.** For this project that is a convenient consolidation: the Trivy required by the security area covers Terraform misconfiguration with the same tool and the same workflow.
- **Checkov has the deepest Terraform-specific coverage** — 1,000+ policies with graph-based cross-resource analysis. Trivy is broader; Checkov is deeper. Running both is common and they are not redundant.
- **tflint is a linter, not a security scanner.** Its security rules are shallow by design. Run it *alongside* a scanner, never instead of one.
- **Infracost** attaches a cost delta to the plan. On a credit-limited AWS account that is a meaningful gate, not a nicety.

Everything above is safe to run on a pull request. `terraform plan` against real state requires credentials, so it runs with the pipeline identity, not the agent's.

## 21. Policy as code

Linters check syntax and known-bad configuration. Policy engines check *your* rules. The starting set every source recommends:

- No security group, endpoint or bucket open to `0.0.0.0/0`
- No IAM wildcards — neither `Action: "*"` nor `Resource: "*"` without a condition
- All resources carry the mandatory tags
- Encryption at rest enabled on every storage resource
- No `local-exec` provisioners
- Audit logging enabled on managed control planes

Write these once, as OPA policies, and they apply to every change regardless of whether a human or an agent wrote it. That property — **the same rule binds both** — is what makes policy as code the right layer for AI guardrails, rather than trying to make the agent perfectly obedient.

Keep policies in their own repository with their own review. A policy an agent can edit is not a control.

## 22. Reviewing a plan

Automation clears the mechanical checks. What is left for the human is the part no tool can do. Read the plan in this order:

1. **Destroys and replacements first.** Every one. An undocumented replacement is an automatic stop — this is where the missing `moved` block surfaces, and nothing upstream catches it.
2. **Provisioners and external invocations.** Do not trust a resource-count summary; read what actually runs.
3. **Output changes.** Outputs feed other workspaces and pipelines. A changed output can break a consumer that is not in this diff.
4. **Unrelated drift.** Does this change codify existing drift, or silently revert it? An agent has no way to tell the difference.

Before any of that, three context checks that do not require reading code at all:

- **Is the workspace, account and region stated?** If the PR does not say, send it back.
- **Did `.terraform.lock.hcl` change?** New module sources and loosened constraints deserve scrutiny — planning untrusted code is code execution.
- **Do the cited docs match the pinned provider version?** Documentation for a newer provider is the tell for failure mode 1.

---

# Part IV — Applied to docket-infrastructure

## 23. Conformance table

Measured against the repository as it stands. The baseline is genuinely strong — the gaps are concentrated in verification, not in authoring.

| Practice | Standard | Today | Action |
|---|---|---|---|
| Formatting | `fmt` clean | **Pass**, verified recursively | — |
| Module structure | `main`/`variables`/`outputs`/`README` per module | **Pass**, 8 modules | — |
| No backend or provider in child modules | Required | **Pass** | — |
| Variable `type` + `description` | Required | **Pass** | — |
| Lock file committed in roots, excluded in children | Required | **Pass**, with the reasoning written into `.gitignore` | — |
| Version pinning | `~>` providers, `required_version` floor | **Pass** — `>= 1.13`, `~> 6.0` | Consider raising to `>= 1.14` |
| Remote state: encrypted, versioned, locked | Required | **Pass** — S3, SSE, versioning, native `use_lockfile`, `prevent_destroy` | — |
| State isolation | Per environment and lifecycle | **Pass** — 7 stacks, independent keys | — |
| Mandatory tagging | Enforced | **Pass**, including propagation to ASG-created instances | — |
| Keyless CI credentials | OIDC, no static keys | **Pass**, with immutable subject matching | — |
| `terraform validate` in CI | Required gate | **Missing** — `make validate` exists, nothing invokes it | Add PR workflow |
| Linting | tflint | **Missing** | Add to PR workflow |
| IaC security scanning | Trivy or Checkov | **Missing** | Trivy is already required by the security area — one tool, two requirements |
| Policy as code | OPA | **Missing** | Would have caught the two findings below |
| Native tests | `.tftest.hcl` | **Missing** | Start with `red` and `namespace` |
| Secrets out of state | Write-only arguments | **Workaround** — placeholder `"PENDIENTE"` + `ignore_changes` | Migrate to `value_wo` / `value_wo_version`; supported on the pinned versions |
| No IAM wildcards | Policy rule | **Violated** — `iam:*` on `*` in `GitHubActionsDeployRole` | Scope, or add a permissions boundary |
| No `0.0.0.0/0` exposure | Policy rule | **Violated** — `public_access_cidrs` default | Restrict, or record an explicit ADR |
| Audit logging | Policy rule | **Violated** — `enabled_log_types = []` | Enable `audit` and `authenticator` |
| No environment-specific defaults | Standard | **Deviates** — account ID, org ID, repo IDs, IAM user ARNs as defaults | Contradicts the repo's own `CONVENCIONES.md` |
| `moved` blocks on refactor | Required | **Not yet applicable** | Adopt the rule before the first module refactor |
| Agent rules for Terraform | Required | **Missing** | Paste [§19](#19-drop-in-rule-block) into `CLAUDE.md` |

Two observations worth stating plainly.

**The authoring standard here is already high.** Native S3 locking instead of a DynamoDB table, lock files scoped correctly to roots, tag propagation through `tag_specifications`, immutable OIDC subjects, and documentation that explains *why* a decision was made and warns the next person not to undo it. That last quality is rare and worth protecting.

**Every open gap is a verification gap.** There is no automated check on any pull request in this repository. The three policy violations in the table are exactly the three rules that appear in every recommended starter policy set — which is the argument for policy as code, made empirically.

## 24. Adoption order

Ordered by leverage per hour, not by severity.

1. **Add the agent rule block** ([§19](#19-drop-in-rule-block)) to `docket-ai-sdd/CLAUDE.md`. Minutes. Constrains everything written from here on.
2. **Add the PR workflow**: `fmt -check` → `validate` → `tflint` → Trivy. The `Makefile` targets already exist. This also closes ADR-007, which is accepted and unimplemented.
3. **Fix the three policy violations** — `iam:*`, `public_access_cidrs`, `enabled_log_types` — then encode all three as OPA policies so they cannot come back.
4. **Install the Terraform MCP server and HashiCorp's Terraform agent skills.** Grounding beats correction.
5. **Migrate SSM parameters to `value_wo`.** Removes the placeholder workaround and takes secret values out of state entirely.
6. **Write plan-mode tests** for `modules/red` and `modules/namespace`. Cheap, no credentials, and they run as a PR gate.
7. **Split plan from apply** in the CI role. The agent gets a plan-only identity; apply stays behind human approval of a saved plan.

Steps 1 through 3 are a single working session and remove most of the risk.

---

## 25. Sources

Consulted 7 September 2026. Primary sources are listed first within each group.

**HashiCorp official**

- [Terraform Style Guide — HashiCorp Developer](https://developer.hashicorp.com/terraform/language/style)
- [hashicorp/agent-skills — `terraform-style-guide` skill](https://github.com/hashicorp/agent-skills/blob/main/plugins/terraform/skills/terraform-style-guide/SKILL.md)
- [hashicorp/agent-skills — `terraform-test` skill](https://github.com/hashicorp/agent-skills/blob/main/plugins/terraform/skills/terraform-test/SKILL.md)
- [hashicorp/agent-skills — `refactor-module` skill](https://github.com/hashicorp/agent-skills/blob/main/plugins/terraform/skills/refactor-module/SKILL.md)
- [Terraform recommended practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- [Use temporary write-only arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/write-only)
- [Terraform 1.11: ephemeral values and write-only arguments](https://www.hashicorp.com/en/blog/terraform-1-11-ephemeral-values-managed-resources-write-only-arguments)
- [Ephemeral values in Terraform](https://www.hashicorp.com/en/blog/ephemeral-values-in-terraform)
- [hashicorp/terraform-mcp-server](https://github.com/hashicorp/terraform-mcp-server)
- [Terraform MCP server: four real-world AI infrastructure patterns](https://www.hashicorp.com/en/blog/terraform-mcp-server-four-real-world-ai-infrastructure-patterns)
- [Build secure, AI-driven workflows with Terraform and Vault MCP servers](https://www.hashicorp.com/en/blog/build-secure-ai-driven-workflows-with-new-terraform-and-vault-mcp-servers)
- [aws_ssm_parameter resource — Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter)

**AI-specific guidance**

- [How to Review AI-Generated Terraform Code: A Checklist — Scalr](https://scalr.com/learning-center/how-to-review-ai-generated-terraform-code)
- [Guardrails for AI-Generated Infrastructure — Spacelift](https://spacelift.io/blog/guardrails-for-ai-generated-infrastructure)
- [AI is Writing More of Your Terraform — Sonar](https://www.sonarsource.com/blog/ai-is-writing-more-of-your-terraform/)
- [antonbabenko/terraform-skill — Terraform skill for AI agents](https://github.com/antonbabenko/terraform-skill)
- [Claude Code for Infrastructure as Code — Spacelift](https://spacelift.io/blog/claude-code-for-infrastructure-as-code)
- [AGENTS.md spec and recommended sections](https://www.morphllm.com/agents-md-guide)
- [Infrastructure as Code in 2026: where AI fits, and where it doesn't](https://clankercloud.ai/blog/iac-ai)

**Community conventions and tooling**

- [Terraform Best Practices — naming conventions](https://www.terraform-best-practices.com/naming)
- [Terraform Best Practices — code structure](https://www.terraform-best-practices.com/code-structure)
- [Best practices for root modules — Google Cloud](https://docs.cloud.google.com/docs/terraform/best-practices/root-modules)
- [21 Terraform best practices — Spacelift](https://spacelift.io/blog/terraform-best-practices)
- [Terraform security scanning: tools and CI/CD, 2026](https://appsecsanta.com/iac-security-tools/terraform-security-scanning)
- [Top Terraform scanning tools — Spacelift](https://spacelift.io/blog/terraform-scanning-tools)
- [Terraform Style Guide — Gruntwork](https://docs.gruntwork.io/guides/style/terraform-style-guide/)
