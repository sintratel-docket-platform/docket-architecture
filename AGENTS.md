# AGENTS.md — Docket Platform Engineering Constitution

**Normative for every human and every AI agent that writes code, infrastructure, manifests or documentation in any `sintratel-docket-platform` repository.**

Version 1.0 · 7 September 2026 · Owner: Docket platform team

---

## 0. Scope, precedence and distribution

This file is the single source of truth for how work is produced in this project. It is not advisory. Where it conflicts with habit, memory, a tutorial, or a model's prior training, **this file wins**.

**Precedence, highest first:**

1. An explicit instruction from the user in the current conversation
2. This file
3. `TERRAFORM-IAC-BEST-PRACTICES.md` (the long-form Terraform standard this file condenses)
4. Repository-local `CONTRIBUTING.md`
5. Existing conventions visible in the surrounding code
6. General best practice

**Distribution.** This file lives at the macro-project root and is copied verbatim into every repository as `AGENTS.md`, with `CLAUDE.md` importing it on its first line (`@AGENTS.md`). It is never edited in a copy — edit the root, then redistribute. A copy that has drifted from the root is a bug.

**Maintenance.** Treat this file as a *failure log, not a wishlist*. When an agent makes the same mistake twice, this file is missing a line. Add the line.

---

## 1. Prime directives

If you read nothing else, read these ten.

1. **English only.** Code, comments, documentation, commits, PR titles and bodies, branch names, file names, directory names. No exceptions.
2. **You plan; a human applies.** Never run `terraform apply`, `terraform destroy`, `kubectl apply`, or `argocd app sync` against real infrastructure.
3. **Never publish without authorisation.** `git push`, opening a PR, creating a release, creating a repository — ask first, every time. Local commits are free and expected.
4. **Renaming a Terraform resource requires a `moved` block.** Never rename an address in place. That is a destroy and recreate.
5. **Read the lock file before writing Terraform.** Every argument must exist in the pinned provider version.
6. **Never widen an IAM policy to clear a permissions error.** Scope it correctly or ask.
7. **Never invent a value.** If a CIDR, instance size, retention period or region was not specified, ask. A named assumption is cheap; a silent guess is expensive.
8. **Every commit follows Conventional Commits and references its Kanban card.**
9. **Show your verification.** "Done" means `fmt`, `validate` and the relevant tests ran, and you showed the output.
10. **When a tool contradicts you, the tool is right.** Read the schema. Do not guess alternative spellings.

---

## 2. Language

**English, everywhere, without exception.**

| Surface | Rule |
|---|---|
| Source code, identifiers | English |
| Comments | English |
| Documentation, README, ADRs | English |
| File and directory names | English, `kebab-case` for files, `kebab-case` for directories |
| Commit messages | English, imperative mood |
| Branch names | English |
| PR titles and bodies | English |
| Terraform variables, resources, outputs | English, `snake_case` |
| Kubernetes resource names | English, `kebab-case` |
| Issue and Kanban card titles | English |

No accents, no Spanish words, no mixed-language identifiers. Use descriptive English names such as `check-orphans.sh` and `environment`.

This supersedes the language section of `docket-infrastructure/CONVENTIONS.md`, which previously specified Spanish.

---

## 3. Repository model

Two classes of repository. The distinction determines what may be written where.

**Process repository — `docket-ai-sdd`, exactly one.**
Holds `specs/`, `scripts/`, `docs/`, and the agent configuration (`CLAUDE.md`, `AGENTS.md`, `.claude/`, `.mcp.json`).

**Delivery repositories — every other repository.**
Hold product: application code, infrastructure, manifests, technical documentation.

### Rules

1. **Never create agent-process files in a delivery repository** except the distributed `AGENTS.md` and `CLAUDE.md` pointer. No `specs/`, no `.claude/commands/`, no session notes.
2. **Never assume a target repository.** If the spec or plan does not name it, ask. Do not infer from name similarity or from where something similar went last time.
3. **A repository that does not exist is a task, not an assumption.** Creating one is explicit work requiring authorisation.
4. **Never commit build output, state, or local configuration.** See §7.9.

### Current repositories

| Repository | Class | Contents | Visibility |
|---|---|---|---|
| `docket-ai-sdd` | Process | Agent config, SDD commands, specs, scripts | Private |
| `docket-roadmap` | Delivery | Backlog, user stories, iteration records | Private |
| `docket-architecture` | Delivery | Architecture documents and ADRs | **Public** |
| `docket-infrastructure` | Delivery | Terraform **stacks** — the live infrastructure | Private |
| `docket-terraform-modules` | Delivery | Reusable Terraform **modules**, versioned by tag | **Public** |
| `docket-gitops` | Delivery | Kubernetes manifests, Argo CD applications | **Public** |
| `docket-local` | Delivery | Local Compose environment | Private |
| `docket-auth-api` | Delivery | Go service | Private |
| `docket-users-api` | Delivery | Java / Spring Boot service | Private |
| `docket-todos-api` | Delivery | Node.js service | Private |
| `docket-log-message-processor` | Delivery | Python worker | Private |
| `docket-frontend` | Delivery | Vue.js SPA | Private |

**Three repositories are public.** Never write an account identifier, account-qualified ARN, internal hostname, real endpoint, credential, named principal, or client data into `docket-architecture`, `docket-gitops` or `docket-terraform-modules`.

`docket-terraform-modules` is public by design, so that `terraform init` clones it without a credential and the project keeps its "no static keys" posture (ADR-011). **Git history is public too** — a leaked identifier needs history rewriting, not a follow-up commit. CI enforces this, but do not rely on CI to catch what you should not have written.

### Modules and stacks

The two Terraform repositories have strictly separated roles.

| | `docket-terraform-modules` | `docket-infrastructure` |
|---|---|---|
| Holds | Reusable modules | Root modules (stacks) |
| Declares `provider` / `backend` | Never | Always |
| Contains an account identifier | Never | Yes, in stack configuration |
| Versioned by | Git tags (`v1.2.0`) | Not versioned; it *is* the live state |
| Changed by | A module improvement | Wiring, or a version bump |

**Never add a resource to a stack that belongs in a module, and never hardcode a project-specific name inside a module.** A module that names its own resources `docket-*` is not reusable. Take a `name_prefix` input instead.

---

## 4. Branching — Trunk-Based Development

`main` is always releasable. Everything else is short-lived.

### Rules

1. **Branch from `main`, merge back to `main`.** No `develop`, no long-running release branches.
2. **Maximum lifetime: 3 days.** A branch older than that is split into smaller pieces or merged behind a feature flag.
3. **Never commit directly to `main`.** Every change arrives through a pull request, including documentation and including your own.
4. **Rebase on `main`; never merge `main` into a feature branch.** Keeps history linear and the diff honest.
5. **Delete the branch on merge.** Repositories have auto-delete enabled; if it survived, delete it manually.
6. **One card, one branch, one PR** wherever possible. If a card needs three PRs, the card was too big — say so.

### Naming

```
<type>/<card-number>-<short-english-slug>
```

`<type>` matches the Conventional Commit type of the change.

```
feat/9-terraform-ci-pipeline
fix/16-oidc-subject-format
docs/34-architecture-decision-records
refactor/3-rename-stacks-to-english
chore/1-branch-protection
```

Lowercase, hyphens, no accents, no Spanish, no personal names, no dates.

---

## 5. Commits — Conventional Commits

**The standard is [Conventional Commits 1.0.0](https://www.conventionalcommits.org/), in English, imperative mood.**

This is not a style preference. Automated semantic versioning (card #12) and automated release notes (card #24) both consume this format. Choosing it now is what makes those two cards implementable later.

### Format

```
<type>(<scope>): <subject>

<body>

Refs: #<card>
```

### Rules

| Element | Rule |
|---|---|
| `type` | Required. From the table below. Lowercase. |
| `scope` | Optional but expected. The module, stack, service or area touched. Lowercase. |
| `subject` | Required. Imperative mood ("add", not "added" or "adds"). Lowercase first letter. No trailing period. Maximum 72 characters for the whole header line. |
| `body` | Optional. Wrap at 72 columns. Explains *why*, not *what* — the diff already shows what. |
| `Refs:` | **Required.** The Kanban card the change serves. `Refs: #9`. |
| Breaking change | `feat(cluster)!:` or a `BREAKING CHANGE:` footer explaining the migration. |

### Types

| Type | Use for | Version impact |
|---|---|---|
| `feat` | A new capability | minor |
| `fix` | A defect repair | patch |
| `docs` | Documentation only | none |
| `refactor` | Restructuring with no behaviour change | none |
| `perf` | Performance improvement | patch |
| `test` | Adding or correcting tests | none |
| `build` | Build system, dependencies, Dockerfiles | none |
| `ci` | Pipelines and workflows | none |
| `chore` | Maintenance that fits nothing else | none |
| `revert` | Reverting a previous commit | varies |

### Scope vocabulary

Constrained per repository. Do not invent scopes.

| Repository | Allowed scopes |
|---|---|
| `docket-infrastructure` | `bootstrap`, `persistent`, `ephemeral`, `platform`, `environments`, `makefile`, `scripts`, `policy`, `docs` |
| `docket-terraform-modules` | `network`, `cluster`, `registry`, `ci-identity`, `irsa`, `namespace`, `environment`, `dns`, `docs` |
| `docket-gitops` | `argocd`, `redis`, `frontend`, `auth-api`, `users-api`, `todos-api`, `log-processor`, `overlays`, `docs` |
| `docket-architecture` | `logical`, `environments`, `aws`, `adr`, `diagrams` |
| Service repositories | `api`, `auth`, `config`, `docker`, `deps`, `docs` |
| `docket-ai-sdd` | `commands`, `settings`, `scripts`, `specs`, `docs` |

### Examples

```
feat(ephemeral): add EKS control plane and its OIDC provider

The control plane is the dependency for every IRSA role, so it lands
before the platform stack. Node group follows in a separate commit.

Refs: #5
```

```
fix(ci-identity): match the immutable OIDC subject format GitHub issues

GitHub emits the subject with numeric org and repository identifiers.
StringEquals compares character for character, so the classic format
fails with an unhelpful AssumeRoleWithWebIdentity error.

Refs: #9
```

```
refactor(environments)!: rename legacy stack directories to English

BREAKING CHANGE: stack commands now use
`make apply STACK=ephemeral`. S3 state keys are unchanged in this
commit; they are migrated separately.

Refs: #3
```

### Prohibited in commit messages

- Any language other than English
- Tool attribution trailers (`Co-Authored-By` for an AI tool, `Generated with…`, session URLs). The `attribution` key in `.claude/settings.json` suppresses these; do not reintroduce them by hand.
- Notes about how the content was produced
- `wip`, `fix stuff`, `changes`, `update` as a complete subject
- Multiple unrelated changes in one commit

---

## 6. Pull requests

### Title

**The PR title is a Conventional Commit header.** Repositories squash-merge, so the PR title becomes the commit on `main`. A malformed title produces a malformed history and breaks semantic versioning.

```
feat(platform): install controllers and Argo CD with Helm
```

CI validates this. A PR whose title does not parse cannot merge.

### Body

Use the repository's `.github/pull_request_template.md`. Every PR states:

1. **What changed and why** — two or three sentences. Not a file list.
2. **Card** — `Closes #9` or `Refs: #9`.
3. **Acceptance criteria addressed** — quoted from the card, with how each is satisfied.
4. **Verification** — the commands run and their result.
5. **For infrastructure changes: the `terraform plan` output**, with every destroy and every replacement called out explicitly in prose above it.
6. **Risk and rollback** — what breaks if this is wrong, and how to undo it.

### Rules

1. **One approval minimum, from someone who did not write it.** Self-merge is prohibited. This is a hard rule; it was the single most-violated practice in the project's first phase.
2. **All required checks green.** Never merge with a failing or skipped check.
3. **Squash merge only.** Keeps `main` linear, one commit per unit of change.
4. **Small.** Under ~400 changed lines where possible. A large PR does not get reviewed; it gets approved.
5. **Draft PRs are for work in progress.** Do not open a review-ready PR you know is incomplete.
6. **Never force-push a branch under review.** It destroys the reviewer's context.

### Review checklist for infrastructure PRs

Reviewers read the plan before the diff, in this order:

1. Every `destroy` and every replacement. An undocumented replacement is an automatic stop.
2. Provisioners and external invocations.
3. Output changes that other stacks consume.
4. Unrelated drift — does this codify drift, or silently revert it?
5. Does `.terraform.lock.hcl` change? New module sources and loosened constraints deserve scrutiny.

---

## 7. Terraform

Condensed from `TERRAFORM-IAC-BEST-PRACTICES.md`. Read that file for rationale; this section is the enforceable subset.

### 7.1 Before writing

- Read `.terraform.lock.hcl` and `required_providers`. Every argument must exist in that pinned provider version. State the version you checked.
- State the target explicitly: which stack, which environment, which account, which region.
- If a value was not specified, ask. Never invent CIDRs, instance types, retention periods or AMI IDs.

### 7.2 File layout

| File | Contents |
|---|---|
| `versions.tf` | `required_version`, `required_providers` |
| `providers.tf` | `provider` blocks |
| `backend.tf` | Backend configuration (root modules only) |
| `main.tf` | Resources, data sources, module calls |
| `variables.tf` | Input variables, alphabetical |
| `outputs.tf` | Outputs, alphabetical |
| `locals.tf` | Local values |

Child modules never declare `provider` or `backend`. Every module carries `variables.tf`, `outputs.tf` and `README.md`.

### 7.3 Naming

- `snake_case`, lowercase, singular nouns.
- Never repeat the resource type in the name: `resource "aws_route_table" "public"`, not `"public_route_table"`.
- `main` or `this` when only one instance exists and no name adds information.
- Module repositories, if ever published: `terraform-<PROVIDER>-<NAME>`.

### 7.4 Variables and outputs

- **Every variable declares `type` and `description`.** No exceptions.
- Order: `description`, `type`, `default`, `sensitive`, `validation`. Apply consistently.
- A variable without `default` is required — use that deliberately.
- **No defaults that pin one concrete *environment*.** A project-wide constant is different from an environment: the AWS account, the GitHub organisation and the repository identifiers are the same for every stack, and `allowed_account_ids` already guards the account, so they belong in a default. What must never carry a default is anything where being explicit *is* the control — named IAM principals, network exposure, and secret values. Removing every default without supplying a replacement is worse than either: it leaves stacks that cannot plan at all.
- `sensitive = true` on secrets. It redacts CLI output; it does **not** remove the value from state.
- `validation` blocks on constrained inputs.
- Every output declares a `description`. Delete outputs nobody consumes.

### 7.5 Resources

Argument order inside a resource, fixed:

1. `count` or `for_each`, followed by a blank line
2. Arguments
3. `tags`, last among arguments
4. Nested blocks
5. `lifecycle`
6. `depends_on`

Two spaces, no tabs. Align consecutive single-line `=`. Comments use `#` only.

**`for_each` for multiple instances. `count` only for `enabled ? 1 : 0`.** `count` reindexes on removal and destroys the wrong resource.

### 7.6 Versions

- `required_version = ">= 1.14"` in every root module.
- Providers pinned with `~>`.
- `.terraform.lock.hcl` committed in root modules, excluded from child modules.
- Never loosen a constraint silently. If you loosen one, say so and say why.

**Module sources are pinned to a tag.** Stacks consume modules from the published repository, never by local path:

```hcl
module "network" {
  source = "git::https://github.com/sintratel-docket-platform/docket-terraform-modules.git//modules/network?ref=v1.2.0"

  name_prefix = "docket-ephemeral"
}
```

- **`?ref=` is mandatory and must name a tag on `main`.** A branch ref is allowed on a feature branch while a module change is in flight, and must become a tag before the PR merges. CI rejects a non-tag ref on a pull request into `main`.
- **Never a local path** (`../../modules/...`) in a stack. That silently un-versions the module and applies unreviewed changes on the next apply.
- **Each environment pins independently.** `prod` on the oldest confirmed version, `staging` on the rehearsal, `dev` on the newest. Promotion is a one-line `ref=` bump in a pull request — the same shape as image promotion in GitOps.
- **Changing a `source` does not change any resource address.** The address comes from the `module` block name. Repointing needs no `moved` block; renaming the block does. Never do both in one commit — a non-empty plan then has two possible causes.

### 7.7 Refactoring

**Renaming or relocating a resource requires a `moved` block.** Removing a resource from management without destroying it requires a `removed` block with `lifecycle { destroy = false }`. Adopting an existing resource requires an `import` block.

```hcl
moved {
  from = aws_instance.web
  to   = module.compute.aws_instance.web_api
}
```

Never rename an address by editing text. Terraform reads that as destroy-and-recreate, and no automated check will catch it — it appears only in the plan.

### 7.8 Secrets

- Never hardcode a credential, token, key or password. Not even a realistic-looking placeholder.
- Prefer write-only arguments (`*_wo` with their `*_wo_version` companion) where the provider supports them, so the value never reaches state or the plan file. `aws_ssm_parameter` supports `value_wo` on the pinned provider version.
- Prefer `ephemeral` resources for values fetched at runtime.
- Never commit `.tfvars` containing real values.

### 7.9 Never commit

`*.tfstate`, `*.tfstate.*`, `.terraform/`, `.terraform.tfstate.lock.info`, `*.tfplan`, `.tfvars` with real values, `kubeconfig`, `*.pem`, `*.key`, `.env`.

### 7.10 Security invariants

These are enforced by policy as code. Violating one fails the pipeline.

- No IAM wildcard on both action and resource. No `iam:*` on `*`.
- No security group, endpoint, or bucket open to `0.0.0.0/0` unless a human asked for it in those words and an ADR records why.
- Encryption at rest on every storage resource.
- Audit logging enabled on managed control planes.
- The four mandatory tags (`Project`, `Environment`, `Stack`, `ManagedBy`) on every resource.
- No `local-exec` provisioners.

### 7.11 Commands

**Allowed without asking:** `terraform fmt`, `terraform validate`, `terraform init -backend=false`, `terraform plan`, `terraform show`, `terraform output`, `terraform test`, `make fmt`, `make validate`, `make plan`, `tflint`, `trivy config`, `checkov`.

**Prohibited:** `terraform apply`, `terraform destroy`, `terraform state rm`, `terraform state mv`, `terraform import`, `terraform force-unlock`, `make apply`, `make destroy`, `make teardown`. These require explicit in-the-moment authorisation from the user, every time. Prior authorisation does not carry over.

### 7.12 Compliance criteria and validation

Every rule above is checkable. A rule that cannot be verified is a suggestion, so each one here carries an identifier, the criterion that satisfies it, and the command that proves it.

Run the whole set with `./scripts/verify-iac-rules.sh`. Individual commands assume the repository root.

| ID | Rule | Criterion | Validation |
|---|---|---|---|
| **IAC-01** | §7.2 | Every module declares `variables.tf`, `outputs.tf`, `versions.tf`, `README.md` | `for d in modules/*/; do for f in variables.tf outputs.tf versions.tf README.md; do [ -f "$d$f" ] \|\| echo "MISSING $d$f"; done; done` |
| **IAC-02** | §7.2 | No child module declares a `provider` or `backend` block | `grep -rnE '^\s*(provider\|backend)\s+"' modules/` returns nothing |
| **IAC-03** | §7.3 | Identifiers are `snake_case` | `tflint --recursive` with `terraform_naming_convention` enabled |
| **IAC-04** | §7.3 | No resource name repeats its type | Manual review; `tflint` catches the common cases |
| **IAC-05** | §7.4 | Every variable declares `type` and `description` | `tflint` rules `terraform_typed_variables`, `terraform_documented_variables` |
| **IAC-06** | §7.4 | Every output declares a `description` | `tflint` rule `terraform_documented_outputs` |
| **IAC-07** | §7.4 | No default pins a concrete environment, a named IAM principal, a CIDR or a secret. Project constants are allowed | Review; `grep -rnE 'default\s*=\s*"arn:aws:iam::[0-9]{12}:user/' .` returns nothing |
| **IAC-08** | §7.4 | Secret variables are marked `sensitive` | `grep -rniE 'variable "(.*secret\|.*password\|.*token\|.*key)"' -A6 . \| grep -c sensitive` matches the count of such variables |
| **IAC-09** | §7.5 | Canonical formatting | `terraform fmt -check -recursive -diff` exits zero |
| **IAC-10** | §7.5 | Configuration is internally consistent | `make validate` reports Success for every stack and module |
| **IAC-11** | §7.6 | Every root module sets `required_version` | `tflint` rule `terraform_required_version` |
| **IAC-12** | §7.6 | Providers are pinned | `tflint` rule `terraform_required_providers` |
| **IAC-13** | §7.6 | Lock file committed in roots, absent in children | `for d in stacks/*/; do [ -f "$d.terraform.lock.hcl" ] \|\| echo "MISSING $d"; done` and `find modules -name .terraform.lock.hcl` returns nothing |
| **IAC-14** | §7.6 | Module sources pin a tag, never a branch or local path | `grep -rn 'source *= *"git::' stacks/ \| grep -v '?ref=v'` and `grep -rn 'source *= *"\.\./' stacks/` both return nothing |
| **IAC-15** | §7.7 | A rename carries a `moved` block | `terraform plan` reports no unexpected destroy or replacement |
| **IAC-16** | §7.8 | No credential material in the tree | `trivy fs --scanners secret .` reports nothing HIGH or CRITICAL |
| **IAC-17** | §7.9 | Nothing forbidden is tracked | `git ls-files \| grep -E '\.tfstate\|^\.terraform/\|\.tfplan$\|\.tfvars$'` returns nothing |
| **IAC-18** | §7.10 | No IAM wildcard on action and resource together | `opa eval --data policy --input tfplan.json "data.docket.deny"` returns `[]` |
| **IAC-19** | §7.10 | Nothing exposed to `0.0.0.0/0` | Same OPA evaluation |
| **IAC-20** | §7.10 | Control plane audit logging enabled | Same OPA evaluation |
| **IAC-21** | §7.10 | The four mandatory tags on every resource | Same OPA evaluation |
| **IAC-22** | §7.10 | No `local-exec` provisioner | Same OPA evaluation |
| **IAC-23** | §9 (modules) | Every module has plan-mode tests | `for d in modules/*/; do [ -d "${d}tests" ] \|\| echo "NO TESTS $d"; done`, then `terraform test` |
| **IAC-24** | §2 | No non-English identifier, comment or path | `grep -rP '[\x{00e1}\x{00e9}\x{00ed}\x{00f3}\x{00fa}\x{00f1}\x{00c1}\x{00c9}\x{00cd}\x{00d3}\x{00da}\x{00d1}]' --include='*.tf' --include='*.md' .` returns nothing |

**Where each one is enforced.** IAC-01 through IAC-17 and IAC-24 run on every pull request in the `terraform-ci` workflow. IAC-18 through IAC-22 need a plan artifact, so they run against `terraform show -json` in the plan job. IAC-23 runs in the module repository's own pipeline.

A finding that is accepted rather than fixed goes in the pull request with its justification, and — when it is an architectural choice rather than a temporary exception — as an ADR. **Never silence a check to make it pass.**

---

## 8. Kubernetes and GitOps

1. **Git is the only way into the cluster.** Never `kubectl apply`, `kubectl edit`, `kubectl scale`, `kubectl delete` or `argocd app sync` against a real cluster. Change the manifest, open a PR, let Argo CD reconcile.
2. **Read-only `kubectl` is allowed** for diagnosis: `get`, `describe`, `logs`, `top`, `events`.
3. **Namespaces are `dev`, `staging`, `prod`.** These match the Terraform `environments` variable. Never introduce a fourth name for the same thing.
4. **Kustomize overlays, not duplicated manifests.** Base in `apps/<name>/base`, per-environment differences in `apps/<name>/overlays/<env>`.
5. **Image tags are immutable digests or `sha-<commit>` tags.** Never `latest`.
6. **Production sync policy is manual.** Automated sync with self-heal is for `dev` and `staging` only.
7. **Promotion happens by changing an image reference in Git and opening a PR**, never by mutating a running workload.

---

## 9. Testing

Four of the five services currently have **no test harness at all**. The first testing task in a service therefore installs the harness before it writes a test. That is expected work, not scope creep.

### 9.1 The three levels

| Level | Scope | Dependencies | Speed | Runs |
|---|---|---|---|---|
| **L1 · Unit** | One function, class or component in isolation | None. No network, no container, no filesystem, no clock | Milliseconds | Every push, every PR |
| **L2 · Integration** | One service with its real collaborators | Real, but ephemeral: containers, in-memory doubles | Seconds | Every PR into `main` |
| **L3 · End-to-end** | A complete user journey through the front door | A fully deployed environment | Minutes | Before promotion |

The boundary that matters: **L1 never touches anything outside the process.** If a test needs Redis, a database or an HTTP call, it is L2 by definition, no matter how small it looks.

### 9.2 Tooling per service

Chosen for the stack that exists, not the stack we would pick today. **Do not substitute a more modern tool without changing the stack first.**

| Service | Stack | L1 | L2 |
|---|---|---|---|
| `auth-api` | Go 1.24, Echo v3 | `testing` + `testify/assert` | `net/http/httptest`; `users-api` as a stubbed HTTP server |
| `users-api` | Java 8, **Spring Boot 1.5.6** | **JUnit 4** + Mockito, via `spring-boot-starter-test` | `@SpringBootTest` with the H2 dependency already present |
| `todos-api` | Node, Express 4 | **Jest** + `supertest` | Jest + a Redis double (`ioredis-mock`) or Testcontainers |
| `log-message-processor` | Python | **pytest** | pytest + `fakeredis` |
| `frontend` | **Vue 2 + webpack** | **Jest** + `@vue/test-utils` v1 | — |

L3 is one shared suite for the whole platform, in **Playwright**, living in its own repository or in `docket-gitops`. It runs against a deployed environment, never against a local build.

**Two traps to avoid, both of which a model will walk into:**

- **Not Vitest** for the frontend. Vitest is Vite-based; this is Vue 2 on webpack 3. Jest with `@vue/test-utils` v1 is the fit.
- **Not JUnit 5** for `users-api`. Spring Boot 1.5.6 is from 2017 and ships JUnit 4. Upgrading the framework is a separate, deliberate card.

### 9.3 Conventions

| Stack | Location | Naming |
|---|---|---|
| Go | Beside the code | `foo_test.go`, `TestFoo_ReturnsErrorWhenTokenExpired` |
| Java | `src/test/java/...` mirroring `src/main/java` | `FooTest.java`, `shouldReturnErrorWhenTokenExpired` |
| Node | `__tests__/` or `*.test.js` beside the code | `describe('login')` / `it('rejects an expired token')` |
| Python | `tests/` | `test_foo.py`, `test_rejects_expired_token` |
| Vue | `tests/unit/` | `Foo.spec.js` |

Rules that apply in every stack:

- **Test names state behaviour, not method names.** `rejects an expired token`, not `testValidate`.
- **Arrange, act, assert** — in that order, visibly separated.
- **One behaviour per test.** Several assertions about the same behaviour are fine; several behaviours are not.
- **Deterministic.** No `sleep`, no real clock, no unseeded randomness, no network in L1. A test that fails one run in twenty is worse than no test.
- **Builders and fixtures over copied setup.** Duplicated setup is where test suites go to die.

### 9.4 Coverage

Coverage is a floor, not a goal. A suite at 90% that asserts nothing meaningful is worse than one at 60% that does.

- Report line coverage per service on every PR.
- **Coverage on new code must not fall below the service's current overall coverage.** That ratchet is what raises the number without a big-bang effort.
- Enforcement lands in SonarQube (card #11). Until then, report the number and let the reviewer judge.
- Never chase coverage by testing getters, constructors or framework code.

### 9.5 Promotion gates

This is the link between testing and environment promotion (area 05, cards #23 and #25). A change moves forward only when the gate below it is green.

| Transition | Required to pass |
|---|---|
| PR → `main` | L1 green · lint green · image builds · coverage ratchet held |
| `main` → `dev` | L1 + L2 green · Trivy image scan clean of HIGH/CRITICAL |
| `dev` → `staging` | L2 green against `dev` · L3 smoke suite green |
| `staging` → `prod` | **Full L3 suite green** · manual approval on the manifests PR |

A gate is never skipped to unblock a release. If a gate is wrong, fix the gate in its own PR.

### 9.6 Rules for agents writing tests

These are the rules that keep AI-written test suites honest. They matter more than the tooling.

**Never**

1. **Never delete, skip or weaken a test to make a build green.** A failing test is correct until proven otherwise. If you believe the test is wrong, say so and explain why — do not edit it into passing.
2. **Never assert on implementation details** — private methods, call counts on things you own, internal state. Assert on observable behaviour.
3. **Never mock what you own at L2.** Mock the boundary you do not control; use the real thing inside your own service.
4. **Never add a `sleep` to fix a flaky test.** Wait on a condition, or fix the race.
5. **Never commit a skipped or pending test** without a `Refs:` to the card that will finish it.
6. **Never write a test that passes against broken code.** If you cannot see it fail, you do not know it tests anything.
7. **Never claim a suite passes without showing the output.**

**Always**

1. **A bug fix starts with a failing test that reproduces the bug.** Then the fix. The test is the proof.
2. **New behaviour ships with its test in the same PR.** Not a follow-up card.
3. **State which level you are writing** and why it belongs there.
4. **Install the harness first** when a service has none, in its own commit, with no tests in it. Then add tests. Two commits, two concerns.
5. **When a test is hard to write, say so.** Difficulty is usually the design telling you something, and that is worth reporting rather than working around.

---

## 10. Secrets and security

1. Never write a secret to a file, a log, a commit, a PR body, or a comment.
2. Never read `.env`, `*.tfstate`, `kubeconfig`, `*.pem`, `*.key`, `id_rsa*`, or anything under `secrets/` unless the user explicitly asks in that turn.
3. Secrets live in SSM Parameter Store as `SecureString`, segmented by environment (`/docket/<env>/...`), read by External Secrets Operator through IRSA. They do not live in Git.
4. CI authenticates to AWS through OIDC. Never introduce a long-lived access key.
5. Apply least privilege by default. A permissions error is a signal to scope precisely, not to add a wildcard.
6. If you discover a committed secret, stop, tell the user, and do not propagate it into any new file. Assume it is compromised and needs rotation, not just deletion.

---

## 11. Definition of done

A task is not done until every applicable line is true and you have shown the evidence.

**Every change**

- [ ] English throughout — code, comments, docs, commit, branch, PR
- [ ] Conventional Commit with a `Refs:` to its card
- [ ] Branch created from current `main`
- [ ] Every acceptance criterion on the card is satisfied, or the gap is stated explicitly

**Terraform changes**

- [ ] `terraform fmt -recursive` clean
- [ ] `terraform validate` clean on every affected stack and module
- [ ] `tflint` clean
- [ ] `trivy config` and `checkov` clean, or each finding justified in the PR
- [ ] `terraform plan` reviewed, with every destroy and replacement called out in the PR body
- [ ] `moved` blocks present for any renamed or relocated resource
- [ ] Module unit tests pass, and new behaviour has a test

**Application changes**

- [ ] L1 tests pass; new behaviour has a test at the right level (§9.1)
- [ ] A bug fix has a test that reproduced the bug before the fix
- [ ] No test was deleted, skipped or weakened to reach green
- [ ] Coverage on new code holds the ratchet (§9.4)
- [ ] Image builds
- [ ] No environment-specific value baked into the image

**Documentation changes**

- [ ] Links resolve
- [ ] Diagrams re-exported if their source changed
- [ ] An architectural decision is recorded as a numbered ADR, never as prose buried in a document

**Never mark done** a task whose verification you did not run. "It should work" is not a verification.

---

## 12. Never / Always quick reference

### Never

| | |
|---|---|
| Run `terraform apply` / `destroy` | The agent plans; a human applies |
| Mutate state directly | `state rm`, `state mv`, `import` need authorisation |
| `kubectl apply` / `edit` / `scale` against a cluster | Git is the only path in |
| Push, open a PR, release, or create a repository | Requires authorisation each time |
| Force-push, `reset --hard`, delete a repository | Prohibited outright |
| Rename a Terraform resource by editing text | Use a `moved` block |
| Widen an IAM policy to clear an error | Scope it or ask |
| Open anything to `0.0.0.0/0` | Unless asked in those words, with an ADR |
| Hardcode a credential, account ID, region or AMI | Variables and data sources |
| Hardcode a project name inside a module | Modules take `name_prefix`; they are public and reusable |
| Consume a module by local path from a stack | Pin a tag: `?ref=v1.2.0` |
| Merge to `main` with a module pinned to a branch | Tags only on `main` |
| Invent an unspecified value | Ask |
| Commit state, plans, `.terraform/`, real `.tfvars` | See §7.9 |
| Write in any language but English | §2 |
| Delete, skip or weaken a test to go green | §9.6 |
| Add a `sleep` to fix a flaky test | §9.6 |
| Add tool attribution trailers to commits | §5 |
| Merge your own PR | §6 |
| Commit directly to `main` | §4 |

### Always

| | |
|---|---|
| Read the lock file before writing Terraform | §7.1 |
| State the target stack, environment, account, region | §7.1 |
| Use `moved` blocks when refactoring | §7.7 |
| Declare `type` and `description` on every variable | §7.4 |
| Prefer `for_each` over `count` | §7.5 |
| Run `fmt`, `validate` and tests before claiming done | §11 |
| Write the failing test before fixing a bug | §9.6 |
| Surface every destroy and replacement explicitly | §6 |
| Reference the Kanban card in the commit | §5 |
| Ask when the target repository is unclear | §3 |
| Say when you are assuming something | §1 |

---

## 13. When you are wrong

Provider schemas, APIs and tooling change faster than a model's training data. Being wrong is expected; handling it badly is not.

- **`terraform validate` rejects an argument** → the provider is right, you are wrong. Read the schema through the Terraform MCP server or the registry. Do not try alternative spellings until one passes.
- **A permissions error** → the policy is too narrow *or* the action is wrong. Determine which. Never widen to `*`.
- **A test fails** → the test is right until proven otherwise. Do not delete or weaken a test to make a build green.
- **You cannot satisfy an acceptance criterion** → say so, name the blocker, and deliver everything else. Never quietly narrow the scope.
- **You are unsure which of two approaches the team wants** → do the part that does not depend on the answer, then ask the specific question.

Report outcomes faithfully. If a check failed, say it failed and show the output. If a step was skipped, say it was skipped. A green summary over a red result is the worst failure mode available to you.
