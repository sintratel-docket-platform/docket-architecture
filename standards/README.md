# Engineering standards

The canonical copy of how work is produced in this project. Everything here is
the source; what sits in the other repositories is a distribution of it.

## Contents

| Path | What it is |
|---|---|
| [`AGENTS.md`](AGENTS.md) | The engineering constitution. Language, repository model, branching, Conventional Commits, pull requests, Terraform, GitOps, testing, security, definition of done |
| [`terraform-iac-best-practices.md`](terraform-iac-best-practices.md) | The long-form Terraform standard, with rationale and sources. `AGENTS.md` §7 is its enforceable subset |
| [`templates/`](templates/) | The files distributed to each repository: contribution guide, PR template, CODEOWNERS, commit template, CI workflows, linter and scanner configuration, OPA policy |

## Why the constitution is copied rather than linked

An agent reads the `AGENTS.md` of the repository it is working in. It does not
follow a link to another repository, and it does not read organisation-level
files. So `AGENTS.md` has to physically exist in each repository, and the copies
have to stay identical.

`CONTRIBUTING.md`, the pull request template and `CODEOWNERS` are different:
GitHub applies the ones in the organisation's `.github` repository to any
repository that does not carry its own. Those live there and are not copied.

## Changing a standard

1. Change it here, in a pull request.
2. Redistribute `AGENTS.md` to every repository.
3. The drift check in each repository's `pr-conventions` workflow compares its
   copy against this one and fails if they differ, so a missed redistribution
   surfaces on the next pull request rather than silently.

This repository is public, which is what lets every other repository — private
ones included — fetch the canonical copy with no credential.

## What must never land here

This repository is public. No account identifier, no account-qualified ARN, no
domain, no named principal, no credential. Plans and status documents that carry
any of those live in `docket-roadmap`, which is private.
