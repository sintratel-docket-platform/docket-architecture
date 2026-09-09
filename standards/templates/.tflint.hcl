# tflint configuration — place at the repository root.
#
# tflint is a linter, not a security scanner. Its security rules are shallow
# by design. It runs alongside Trivy and Checkov, never instead of them.
# What it is good at: deprecated arguments, invalid instance types, and
# provider-specific mistakes that `terraform validate` accepts.

config {
  call_module_type = "local"
  force            = false
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.44.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Naming: snake_case everywhere (AGENTS.md section 7.3).
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

# Every variable declares type and description (AGENTS.md section 7.4).
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Providers must be pinned (AGENTS.md section 7.6).
rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

# Catches locals, variables and data sources nobody reads.
rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}
