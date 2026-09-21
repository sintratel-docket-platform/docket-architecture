# Branch protection

Records the state of branch protection across every repository in
`sintratel-docket-platform`, why the gaps that remain are open, and the exact
commands that close each one. Card 39 asks for protection wherever the current
GitHub plan allows it; this document is that record, verified on 21 September
2026 through the GitHub API.

## State of every repository

| Repository | Visibility | PR required | Approvals | Code Owner review | Required checks | Stale dismissal | Linear history | Force pushes blocked | Administrators included | Squash only |
|---|---|---|---|---|---|---|---|---|---|---|
| `docket-architecture` | Public | Yes | 1 | Yes | 3 convention checks | Yes | Yes | Yes | No | Yes |
| `docket-terraform-modules` | Public | Yes | 1 | Yes | `Module tests` + 3 convention checks | Yes | Yes | Yes | No | Yes |
| `.github` | Public | Yes | 1 | Yes | 2 convention checks (title, branch) | Yes | Yes | Yes | No | Yes |
| `microservice-app-example` (fork) | Public | No | None | No | None | No | No | No | None | No, all three strategies |
| `docket-ai-sdd` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-auth-api` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-frontend` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-gitops` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-infrastructure` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-local` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-log-message-processor` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-roadmap` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-todos-api` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |
| `docket-users-api` | Private | No, plan refuses it | None | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | No, plan refuses it | None | Yes |

Every one of the thirteen team repositories, public and private alike, already
enforces squash merge only with the pull request title as the commit
(`squash_merge_commit_title: PR_TITLE`) and deletes the branch on merge. Only
`microservice-app-example` differs, and it is left as is. Nobody commits to it,
and the team decided on 21 September 2026 not to touch it as part of this card.

Organisation rulesets are also unavailable on the Free plan
(`GET /orgs/{org}/rulesets` answers the same 403 shown below), so no rule can
be applied once across every repository; each repository is protected on its
own. `docket-terraform-modules` additionally keeps its existing ruleset,
"Immutable version tags", which is unrelated to branch protection and was not
touched by this card.

## Open gaps and their justification

### The ten private repositories cannot be protected on the Free plan

`GET /repos/{org}/{repo}/branches/main/protection` on any of the ten private
repositories answers 403 with the message shown in the verification section
below. The only way to remove that limit is a plan change or making the
repository public. The team keeps the ten repositories private because they
carry the account identifier, the domain, or open security findings that must
not reach a public repository's history, which cannot be rewritten after the
fact. `docket-architecture` and `docket-terraform-modules` are the two
repositories built to be public from the start, and they now carry the full
set of rules this document records. The loop later in this document applies
the same rules to the ten private repositories, ready to run the day the plan
allows it.

### Administrators are not included in any of the three protected repositories

`enforce_admins` is `false` on `docket-architecture`, `docket-terraform-modules`
and `.github`. The team lead merges most pull requests, and a second reviewer
is not always available, including for both `AGENTS.md` redistributions of 14
and 21 September 2026, which reached `main` directly at the team lead's
request. Including administrators would block exactly that path. GitHub still
logs an administrator bypass on every merge it covers, and the
`docket-terraform-modules` protection recorded one on pull request #12, opened
to fix its `CODEOWNERS`, which `Module tests` does not run against.

### `microservice-app-example` stays unprotected

It is the 2023 upstream project the five services were forked from, kept for
reference. Nobody commits to it, so protecting it would add process with
nothing behind it. The team decided on 21 September 2026 that it stays as is,
rather than being archived as part of this card. Archiving it later, which
makes the repository read-only without needing branch protection, is one
command:

```bash
gh api -X PATCH repos/sintratel-docket-platform/microservice-app-example -F archived=true
```

### Path-filtered workflows cannot be required as they stand

A required check that never runs on a given pull request leaves that pull
request waiting forever, mergeable only by an administrator. Four workflows
are path-filtered and are not required for that reason. `service-ci` runs on
`**.md` and `docs/**` excluded (`Tests`, `Build and scan`, in every service
repository); `terraform-ci` runs on paths `**.tf` and related, in
`docket-infrastructure`; `gitops-ci` runs on a path list (`Environment
changes`, in `docket-gitops`); and `module-ci` runs on `modules/**` only
(`Module tests`, in `docket-terraform-modules`). `module-ci` is the one
exception. It was already required before this card, and a pull request that
touches nothing under `modules/` waits for an administrator to merge it, which
is what happened with `docket-terraform-modules` #12 on 21 September 2026. The
pattern that makes a path-filtered workflow safe to require, an
always-reporting gate job, is given at the end of this document; building it
is out of this card's scope.

## Ready-to-run commands

### Public repositories, as applied

Each payload below is the exact body sent to
`PUT /repos/{owner}/{repo}/branches/main/protection`, kept so the same state
can be re-applied if it ever drifts. Every payload was read back after being
applied; the comparison is in the verification section.

```bash
gh api -X PUT repos/sintratel-docket-platform/docket-architecture/branches/main/protection --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "PR title is a Conventional Commit" },
      { "context": "Branch name and language" },
      { "context": "AGENTS.md matches the canonical copy" }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

```bash
gh api -X PUT repos/sintratel-docket-platform/docket-terraform-modules/branches/main/protection --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "Module tests" },
      { "context": "PR title is a Conventional Commit" },
      { "context": "Branch name and language" },
      { "context": "AGENTS.md matches the canonical copy" }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

```bash
gh api -X PUT repos/sintratel-docket-platform/.github/branches/main/protection --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "PR title is a Conventional Commit" },
      { "context": "Branch name and language" }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF

gh api -X PATCH repos/sintratel-docket-platform/.github -f delete_branch_on_merge=true
```

### The ten private repositories, once the plan allows it

Runs the same seven rules with the three convention checks that already run
in every private repository. Nothing else changes on the day the plan is
upgraded or a repository turns public; this loop is the whole remediation.

```bash
for repo in docket-ai-sdd docket-auth-api docket-frontend docket-gitops \
            docket-infrastructure docket-local docket-log-message-processor \
            docket-roadmap docket-todos-api docket-users-api; do
  gh api -X PUT "repos/sintratel-docket-platform/${repo}/branches/main/protection" --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "checks": [
      { "context": "PR title is a Conventional Commit" },
      { "context": "Branch name and language" },
      { "context": "AGENTS.md matches the canonical copy" }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
done
```

### Read back the state of any repository

```bash
gh api repos/sintratel-docket-platform/<repo>/branches/main/protection | jq .
```

### Check that `CODEOWNERS` has no unknown owner

Code Owner review enforces nothing if the file names an owner GitHub cannot
resolve. Run this before turning `require_code_owner_reviews` on, and again
whenever `CODEOWNERS` changes:

```bash
gh api repos/sintratel-docket-platform/<repo>/codeowners/errors --jq '.errors | length'
```

A result of `0` means every line resolves. `docket-terraform-modules` failed
this check before this card, naming two teams the organisation does not have.
The fix, replacing the placeholder teams with the members' handles, is the
same one `docket-architecture` already applied, and it is why the `CODEOWNERS`
template's header now carries the note in
[`standards/templates/CODEOWNERS`](templates/CODEOWNERS).

### Making a path-filtered workflow safe to require

A required check must report on every pull request, including one that does
not touch the paths the real job cares about. The pattern is a gate job with
no path filter of its own that always runs, waits on the real job through
`needs`, and passes when the real job either succeeded or did not need to run.
The gate job's name, not the real job's, is the one registered as required.

```yaml
on:
  pull_request:

jobs:
  detect:
    runs-on: ubuntu-latest
    outputs:
      relevant: ${{ steps.filter.outputs.relevant }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            relevant:
              - 'modules/**'

  module-tests:
    needs: detect
    if: needs.detect.outputs.relevant == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: echo "run the real tests here"

  module-tests-gate:
    name: Module tests
    needs: [detect, module-tests]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - run: |
          if [ "${{ needs.detect.outputs.relevant }}" = "true" ] && \
             [ "${{ needs.module-tests.result }}" != "success" ]; then
            echo "::error::module-tests did not pass"
            exit 1
          fi
          echo "OK"
```
