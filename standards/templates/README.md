# Distributed templates

The files copied into every repository, or into the ones a template applies
to. Each one names, in its own header comment, where it goes and which
repositories carry it. Changing a template here is the source change;
redistributing it to the repositories that carry a copy is the follow-up
pull request, the same path `AGENTS.md` itself follows.

| File | Goes to | What it is |
|---|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Every repository | The short, human-facing contribution guide; links the canonical `AGENTS.md` |
| [`pull_request_template.md`](pull_request_template.md) | Every repository except `docket-gitops` (its own variant) and `.github` (named `PULL_REQUEST_TEMPLATE.md` there) | The pull request checklist: what and why, card, acceptance criteria, verification, risk and rollback |
| [`CODEOWNERS`](CODEOWNERS) | Every repository that can enforce it | Required reviewers per path; production-affecting paths in `docket-gitops` carry their own approver section |
| [`.gitmessage`](.gitmessage) | Every repository | The Conventional Commits template `git commit` shows when configured as the repository's `commit.template` |
| [`pr-conventions.yml`](pr-conventions.yml) | Every repository, as `.github/workflows/pr-conventions.yml` | The two convention checks: PR title is a Conventional Commit, and `AGENTS.md` matches the canonical copy |
| [`terraform-ci.yml`](terraform-ci.yml) | `docket-infrastructure`, as `.github/workflows/terraform-ci.yml` | Terraform quality gates: `fmt`, `validate`, `tflint`, `trivy config`, `checkov`, the OPA policy evaluation |
| [`module-ci.yml`](module-ci.yml) | `docket-terraform-modules`, as `.github/workflows/module-ci.yml` | Module quality gates and release automation, public so `terraform init` can clone the repository with no credential |
| [`release.yml`](release.yml) | `docket-terraform-modules` | Release automation ([ADR-013](../../decisions.md#adr-013-semantic-versioning-for-services-and-modules)): opens or updates one release pull request from Conventional Commits touching `modules/` |
| [`.tflint.hcl`](.tflint.hcl) | Every repository with Terraform | The naming, typed-variable and required-provider rules `tflint --recursive` enforces |
| [`trivy.yaml`](trivy.yaml) | Every repository with Terraform or a container image | Scanner configuration for infrastructure and image findings |
| [`.trivyignore.example`](.trivyignore.example) | Reference only, not distributed as is | The shape an accepted-finding entry takes: why it is accepted, and when it must be revisited |
| [`policy/docket.rego`](policy/docket.rego) | `docket-infrastructure`, as `policy/docket.rego` | The OPA policy behind the security invariants of `AGENTS.md` §7.10 |
| [`verify-iac-rules.sh`](verify-iac-rules.sh) | `docket-infrastructure` and `docket-terraform-modules`, as `scripts/verify-iac-rules.sh` | Runs every IaC compliance criterion of `AGENTS.md` §7.12 in one pass |

Linked from [`documentation-map.md`](../../documentation-map.md).
