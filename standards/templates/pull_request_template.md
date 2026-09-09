<!--
Title must be a Conventional Commit header — it becomes the squashed commit on main.
  feat(platform): install controllers and Argo CD with Helm
CI rejects a title that does not parse.
-->

## What and why

<!-- Two or three sentences. What changed, and why it was needed. Not a file list. -->

## Card

<!-- Closes #N  (the change completes the card) or Refs: #N (partial) -->
Closes #

## Acceptance criteria addressed

<!-- Quote each criterion from the card and say how it is satisfied.
     If one is not addressed, say so explicitly. -->

- [ ] _criterion_ — how it is satisfied

## Verification

<!-- Commands actually run, and their result. Not "should work". -->

```
```

## Terraform plan

<!-- Infrastructure changes only. Delete this section otherwise.

     Call out EVERY destroy and EVERY replacement in prose ABOVE the plan.
     An undocumented replacement is an automatic stop for the reviewer.

     Resources destroyed: none
     Resources replaced:  none
-->

<details>
<summary>Plan output</summary>

```
```

</details>

## Risk and rollback

<!-- What breaks if this is wrong, and how to undo it. -->

## Checklist

- [ ] English throughout — code, comments, docs, commits, branch name, this PR
- [ ] Commits follow Conventional Commits and reference the card
- [ ] Branch is short-lived and rebased on current `main`
- [ ] No secrets, credentials, account identifiers or client data added
- [ ] Documentation updated if behaviour or operation changed
- [ ] Architectural decisions recorded as a numbered ADR

**Terraform only**

- [ ] `make fmt` and `make validate` clean
- [ ] `tflint`, `trivy config`, `checkov` clean or each finding justified above
- [ ] `moved` blocks present for any renamed or relocated resource
- [ ] Module unit tests pass; new behaviour has a test
- [ ] No IAM wildcards, no `0.0.0.0/0`, mandatory tags present

**Review**

- [ ] Reviewed by someone who did not write it
