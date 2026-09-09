# Contributing

Copy this file into the root of every repository. It is the short, repository-local form of [`AGENTS.md`](AGENTS.md), which is normative.

## Language

**English only.** Code, comments, documentation, file names, directory names, commit messages, branch names, PR titles and bodies. No exceptions, no accents, no mixed-language identifiers.

## Branching — Trunk-Based

`main` is always releasable.

- Branch from `main`, merge back to `main`. No `develop`, no release branches.
- **Maximum branch lifetime: 3 days.** Longer means the change was too big.
- **Never commit directly to `main`.** Everything arrives through a pull request, documentation included.
- Rebase on `main`; never merge `main` into your branch.
- Delete the branch on merge.

Naming: `<type>/<card-number>-<short-english-slug>`

```
feat/9-terraform-ci-pipeline
fix/16-oidc-subject-format
docs/34-architecture-decision-records
```

## Commits — Conventional Commits

```
<type>(<scope>): <subject>

<body>

Refs: #<card>
```

- **Type:** `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **Subject:** imperative mood, lowercase, no trailing period, header line ≤ 72 characters
- **Body:** explains *why*; the diff already shows *what*. Wrap at 72 columns.
- **`Refs:`** is required and names the Kanban card.
- **Breaking change:** `feat(scope)!:` or a `BREAKING CHANGE:` footer with the migration path.

```
fix(ci-identity): match the immutable OIDC subject format GitHub issues

GitHub emits the subject with numeric org and repository identifiers.
StringEquals compares character for character, so the classic format
fails with an unhelpful AssumeRoleWithWebIdentity error.

Refs: #9
```

Never include tool attribution trailers, session URLs, or notes about how the content was produced.

To have the format at hand while committing:

```bash
git config commit.template .gitmessage
```

## Pull requests

**The PR title is a Conventional Commit header.** Repositories squash-merge, so the title becomes the commit on `main`. CI rejects a title that does not parse.

Fill in the template. Every PR states what changed and why, its card, the acceptance criteria addressed, the verification run, and — for infrastructure — the `terraform plan` with every destroy and replacement called out in prose.

Rules:

1. **One approval from someone who did not write it.** Self-merge is prohibited.
2. All required checks green. Never merge past a failing or skipped check.
3. Squash merge only.
4. Under ~400 changed lines where possible.
5. Never force-push a branch under review.

## Before you open a PR

**Every change**

- [ ] English throughout
- [ ] Conventional Commit with `Refs:`
- [ ] Branch from current `main`, rebased
- [ ] Every acceptance criterion satisfied, or the gap stated

**Terraform**

- [ ] `make fmt` and `make validate` clean
- [ ] `tflint` clean
- [ ] `trivy config .` and `checkov -d .` clean, or each finding justified
- [ ] `terraform plan` reviewed; destroys and replacements called out
- [ ] `moved` blocks for any renamed or relocated resource
- [ ] Module tests pass; new behaviour has a test

**Application**

- [ ] Tests pass; new behaviour has a test
- [ ] Image builds
- [ ] No environment-specific value baked into the image

## Working with AI agents

Agents operating in these repositories follow [`AGENTS.md`](AGENTS.md). The rules that matter most for reviewers:

- **The agent plans; a human applies.** No `terraform apply`, `terraform destroy`, or `kubectl apply` against real infrastructure.
- **Publishing requires authorisation** each time — push, PR, release, repository creation.
- **Renaming a Terraform resource requires a `moved` block.** This failure is invisible to every automated check; it appears only in the plan. Read the plan.

Review agent-authored infrastructure changes by reading the plan before the diff.
