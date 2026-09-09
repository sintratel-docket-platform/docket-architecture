# Policy as code — the security invariants of AGENTS.md section 7.10.
#
# Linters check syntax and known-bad configuration. Policy engines check OUR
# rules. Written once, they bind human-authored and agent-authored changes
# identically, which is what makes policy the right layer for AI guardrails
# rather than trying to make an agent perfectly obedient.
#
# Evaluate against a plan, not against source:
#   terraform plan -out=tfplan.binary
#   terraform show -json tfplan.binary > tfplan.json
#   opa eval --format pretty --data templates/policy --input tfplan.json \
#            "data.docket.deny"
#
# Every one of these five rules would have caught a finding that reached main.

package docket

import rego.v1

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

changed contains resource if {
	some resource in input.resource_changes
	"no-op" != resource.change.actions[_]
}

after(resource) := resource.change.after

# ---------------------------------------------------------------------------
# 1. No IAM wildcard on both action and resource
#    Real finding: GitHubActionsDeployRole granted iam:* on "*", which lets a
#    workflow create an administrator or rewrite its own trust policy.
# ---------------------------------------------------------------------------

deny contains msg if {
	some resource in changed
	resource.type in {"aws_iam_policy", "aws_iam_role_policy"}
	document := json.unmarshal(after(resource).policy)
	some statement in document.Statement
	statement.Effect == "Allow"
	wildcard_action(statement)
	wildcard_resource(statement)
	not statement.Condition
	msg := sprintf(
		"%s: statement '%s' allows a wildcard action on a wildcard resource with no condition. Scope the action or add a condition (AGENTS.md 7.10).",
		[resource.address, object.get(statement, "Sid", "<unnamed>")],
	)
}

wildcard_action(statement) if {
	some action in to_list(statement.Action)
	endswith(action, ":*")
}

wildcard_action(statement) if {
	some action in to_list(statement.Action)
	action == "*"
}

wildcard_resource(statement) if {
	some resource in to_list(statement.Resource)
	resource == "*"
}

to_list(value) := value if is_array(value)

to_list(value) := [value] if is_string(value)

# ---------------------------------------------------------------------------
# 2. Nothing open to the whole internet
#    Real finding: the EKS module defaulted public_access_cidrs to 0.0.0.0/0
#    and no stack overrode it.
# ---------------------------------------------------------------------------

open_cidr := "0.0.0.0/0"

deny contains msg if {
	some resource in changed
	resource.type == "aws_eks_cluster"
	some config in after(resource).vpc_config
	open_cidr in config.public_access_cidrs
	msg := sprintf(
		"%s: the cluster API endpoint accepts connections from 0.0.0.0/0. Restrict public_access_cidrs, or record an ADR (AGENTS.md 7.10).",
		[resource.address],
	)
}

deny contains msg if {
	some resource in changed
	resource.type == "aws_security_group_rule"
	after(resource).type == "ingress"
	open_cidr in after(resource).cidr_blocks
	msg := sprintf(
		"%s: ingress rule open to 0.0.0.0/0 (AGENTS.md 7.10).",
		[resource.address],
	)
}

# ---------------------------------------------------------------------------
# 3. Control plane audit logging enabled
#    Real finding: enabled_log_types defaulted to [], so there was no record
#    of who did what against the cluster API.
# ---------------------------------------------------------------------------

required_log_types := {"audit", "authenticator"}

deny contains msg if {
	some resource in changed
	resource.type == "aws_eks_cluster"
	enabled := {t | some t in object.get(after(resource), "enabled_cluster_log_types", [])}
	missing := required_log_types - enabled
	count(missing) > 0
	msg := sprintf(
		"%s: control plane log types %v are not enabled (AGENTS.md 7.10).",
		[resource.address, missing],
	)
}

# ---------------------------------------------------------------------------
# 4. Mandatory tags on every taggable resource
# ---------------------------------------------------------------------------

mandatory_tags := {"Project", "Environment", "Stack", "ManagedBy"}

deny contains msg if {
	some resource in changed
	tags := object.get(after(resource), "tags_all", null)
	tags != null
	missing := mandatory_tags - {key | some key, _ in tags}
	count(missing) > 0
	msg := sprintf(
		"%s: missing mandatory tags %v (AGENTS.md 7.10).",
		[resource.address, missing],
	)
}

# ---------------------------------------------------------------------------
# 5. No local-exec provisioners
# ---------------------------------------------------------------------------

deny contains msg if {
	some resource in input.configuration.root_module.resources
	some provisioner in object.get(resource, "provisioners", [])
	provisioner.type == "local-exec"
	msg := sprintf(
		"%s: local-exec provisioner is not permitted (AGENTS.md 7.10).",
		[resource.address],
	)
}

# ---------------------------------------------------------------------------
# 6. Deletions must be deliberate
#    Not a hard denial: surfaces every destroy so a reviewer reads it. This is
#    the failure mode no linter catches — a rename without a moved block.
# ---------------------------------------------------------------------------

warn contains msg if {
	some resource in input.resource_changes
	"delete" in resource.change.actions
	msg := sprintf(
		"%s will be DESTROYED. If this is a rename, use a moved block (AGENTS.md 7.7).",
		[resource.address],
	)
}
