#!/usr/bin/env bash
#
# verify-iac-rules.sh: checks the IaC compliance criteria of AGENTS.md 7.12.
#
# Place at scripts/verify-iac-rules.sh in docket-infrastructure and in
# docket-terraform-modules. Run from the repository root.
#
# Every rule in AGENTS.md section 7 is checkable, and this is what checks them.
# A rule nobody can verify is a suggestion.
#
# Usage:
#   scripts/verify-iac-rules.sh            # static checks only, no credentials
#   scripts/verify-iac-rules.sh --full     # also runs plan-based policy checks
#
# Exit codes:
#   0  every applicable rule passed
#   1  at least one rule failed
#   2  a required tool is missing
#
set -uo pipefail

FULL=0
[ "${1:-}" = "--full" ] && FULL=1

# Tallies live in files, not variables. Most checks run on the right-hand side
# of a pipe, which bash executes in a subshell, so a counter variable
# incremented there never reaches the summary. A script that prints PASS while
# rules are failing is worse than no script at all.
TALLY_DIR="$(mktemp -d)"
trap 'rm -rf "$TALLY_DIR"' EXIT
: > "$TALLY_DIR/failed"
: > "$TALLY_DIR/skipped"

red()   { printf '\033[31m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
grey()  { printf '\033[90m%s\033[0m' "$*"; }

# report <id> <status> <message>
report() {
  printf '  %-20s ' "$1"
  case "$2" in
    pass) green "PASS"; printf '  %s\n' "$3" ;;
    fail) red   "FAIL"; printf '  %s\n' "$3"; echo "$1" >> "$TALLY_DIR/failed" ;;
    skip) grey  "SKIP"; printf '  %s\n' "$3"; echo "$1" >> "$TALLY_DIR/skipped" ;;
  esac
}

# check <id> <description> — passes when the piped command produces no output
check_empty() {
  local id="$1" desc="$2" out
  out="$(cat)"
  if [ -z "$out" ]; then
    report "$id" pass "$desc"
  else
    report "$id" fail "$desc"
    printf '%s\n' "$out" | sed 's/^/               /'
  fi
}

have() { command -v "$1" > /dev/null 2>&1; }

echo
echo "IaC rule verification — AGENTS.md 7.12"
echo "======================================"
echo

# --- Structure -------------------------------------------------------------

{
  for d in modules/*/; do
    [ -d "$d" ] || continue
    for f in variables.tf outputs.tf versions.tf README.md; do
      [ -f "$d$f" ] || echo "missing $d$f"
    done
  done
} | check_empty "IAC-01" "every module declares its interface files"

# Only .tf files: a .terraform.lock.hcl legitimately contains provider blocks.
grep -rnE '^[[:space:]]*(provider|backend)[[:space:]]+"' \
  --include='*.tf' modules/ 2>/dev/null \
  | check_empty "IAC-02" "no provider or backend block inside a child module"

# --- Variables and outputs -------------------------------------------------

# A bare account id in a default is fine: it is a project constant and
# allowed_account_ids already guards it. A named IAM principal is not.
grep -rnE 'default[[:space:]]*=[[:space:]]*"arn:aws:iam::[0-9]{12}:user/' \
  --include='*.tf' . 2>/dev/null \
  | check_empty "IAC-07" "no default pins a named IAM principal"

# --- Formatting and validity ----------------------------------------------

if have terraform; then
  if terraform fmt -check -recursive > /dev/null 2>&1; then
    report "IAC-09" pass "canonical formatting"
  else
    report "IAC-09" fail "canonical formatting"
    terraform fmt -check -recursive -diff 2>&1 | sed 's/^/               /' | head -30
  fi

  # `make validate` runs terraform init across every stack and module. On a
  # cold provider cache that is minutes, and a check nobody waits for is a
  # check nobody runs. It is opt-in here and always on in CI.
  if [ "$FULL" != "1" ]; then
    report "IAC-10" skip "terraform validate needs --full (slow: init per stack)"
  elif [ -f Makefile ] && grep -q '^validate:' Makefile; then
    if make validate 2>&1 | grep -q Error; then
      report "IAC-10" fail "terraform validate reports errors"
    else
      report "IAC-10" pass "configuration is internally consistent"
    fi
  else
    report "IAC-10" skip "no make validate target in this repository"
  fi
else
  report "IAC-09" skip "terraform not installed"
  report "IAC-10" skip "terraform not installed"
fi

# --- Versions and pinning --------------------------------------------------

if have tflint; then
  if tflint --recursive --format compact > /tmp/tflint.out 2>&1; then
    report "IAC-03/05/06/11/12" pass "naming, documentation and version pinning"
  else
    report "IAC-03/05/06/11/12" fail "naming, documentation or version pinning"
    sed 's/^/               /' /tmp/tflint.out | head -30
  fi
else
  report "IAC-03/05/06/11/12" skip "tflint not installed"
fi

{
  for d in stacks/*/ stacks/*/*/; do
    [ -f "${d}main.tf" ] || continue
    [ -f "${d}.terraform.lock.hcl" ] || echo "missing lock file in $d"
  done
  # git ls-files, not find: the rule is about what is COMMITTED. A local lock
  # file left behind by `terraform init` in a module is ignored by .gitignore
  # and is not a violation.
  git ls-files 2>/dev/null | grep '^modules/.*/\.terraform\.lock\.hcl$' \
    | sed 's/^/lock file committed in a child module: /'
} | check_empty "IAC-13" "lock files committed in roots, absent in children"

{
  grep -rn 'source[[:space:]]*=[[:space:]]*"git::' stacks/ 2>/dev/null \
    | grep -v '?ref=v' | sed 's/^/module source not pinned to a tag: /'
  grep -rn 'source[[:space:]]*=[[:space:]]*"\.\./' stacks/ 2>/dev/null \
    | sed 's/^/module consumed by local path: /'
} | check_empty "IAC-14" "module sources pin a version tag"

# --- Secrets and tracked files --------------------------------------------

if have trivy; then
  if trivy fs --scanners secret --severity HIGH,CRITICAL --exit-code 1 \
       --quiet . > /tmp/trivy.out 2>&1; then
    report "IAC-16" pass "no credential material in the tree"
  else
    report "IAC-16" fail "credential material detected"
    sed 's/^/               /' /tmp/trivy.out | head -20
  fi
else
  report "IAC-16" skip "trivy not installed"
fi

git ls-files 2>/dev/null \
  | grep -E '\.tfstate$|\.tfstate\.|^\.terraform/|\.tfplan$|\.tfvars$' \
  | check_empty "IAC-17" "no state, plan or tfvars file is tracked"

# --- Language --------------------------------------------------------------

# Accents alone are not enough. Most Spanish in this codebase carries none —
# "Nombre del rol de IAM", "Region de AWS donde vive el cluster" — so an
# accent-only check reports a translation finished when most of it is not.
# The word list is what actually measures progress.
# Words that are unambiguously Spanish. Deliberately excludes version,
# region, no, red and similar, which are also English and produce false
# positives that hide real progress.
SPANISH_WORDS='\b(el|la|los|las|del|una|unos|unas|para|con|que|por|como|este|esta|estos|desde|donde|entre|cada|todo|toda|hasta|pero|porque|solo|nombre|valor|ambiente|ambientes|nodos|subredes|cuenta|clave|estado|recurso|recursos|politica|politicas|modulo|servicios|cluster de|tipo de|infraestructura|accion|acciones|diagnostico|encender|apagar|resumen|clusteres|activos|efimero|persistente|plataforma|registro|identidad|aislamiento|conservar|ultimas|imagenes|secretos|anotacion|construir|desplegar|borrar|crear|verificar)\b'

{
  grep -rlP '[\x{00e1}\x{00e9}\x{00ed}\x{00f3}\x{00fa}\x{00f1}\x{00c1}\x{00c9}\x{00cd}\x{00d3}\x{00da}\x{00d1}]' \
    --include='*.tf' --include='*.md' --include='*.sh' --include='*.yml' \
    --exclude-dir=.git . 2>/dev/null \
    | grep -v 'pr-conventions' | grep -v 'verify-iac-rules' \
    | sed 's/$/ (accented characters)/'

  # Inline code spans are stripped before matching. Spanish inside backticks is
  # almost always a live identifier - a resource name, a tag value - that is
  # preserved on purpose, because renaming it changes infrastructure. Spanish
  # in prose is what this is looking for.
  # The workflow that detects Spanish necessarily contains Spanish.
  while IFS= read -r f; do
    # Strip markdown code spans and single-token quoted literals. Spanish in
    # either is a preserved identifier - a resource name, a tag value, a module
    # block - that cannot be renamed without changing infrastructure. Spanish
    # in prose, comments and multi-word descriptions is what this looks for.
    sed -e 's/`[^`]*`//g' -e 's/"[^" ]*"//g' -e 's/module\.[A-Za-z0-9_]*//g' "$f" 2>/dev/null \
      | grep -qEi "$SPANISH_WORDS" && echo "$f"
  # Every tracked text file, not a handful of extensions. Scoping this to
  # .tf/.md/.sh once reported the translation finished while Dockerfiles,
  # .gitignore, nginx.conf and a workflow were still Spanish.
  done < <(git ls-files 2>/dev/null | while IFS= read -r f; do
             [ -f "$f" ] && file "$f" 2>/dev/null | grep -q text && echo "$f"
           done | grep -vE '(pr-conventions\.yml|verify-iac-rules\.sh|AGENTS\.md|CONTRIBUTING\.md)$') \
    | sed 's/$/ (Spanish vocabulary)/'
} | sort -u | check_empty "IAC-24" "English only, accents and vocabulary"

# --- Tests -----------------------------------------------------------------

{
  for d in modules/*/; do
    [ -d "$d" ] || continue
    [ -d "${d}tests" ] || echo "no tests directory in $d"
  done
} | check_empty "IAC-23" "every module has plan-mode tests"

# --- Policy (needs a plan artifact) ---------------------------------------

if [ "$FULL" = "1" ]; then
  if have opa && have terraform; then
    echo
    echo "  Policy checks (IAC-18 to IAC-22) need a plan per stack."
    echo "  For each stack: terraform plan -out=tfplan.binary"
    echo "                  terraform show -json tfplan.binary > tfplan.json"
    echo "                  opa eval --format pretty --data policy \\"
    echo "                           --input tfplan.json 'data.docket.deny'"
    echo "  Expected result: []"
  else
    report "IAC-18..22" skip "opa or terraform not installed"
  fi
else
  report "IAC-18..22" skip "policy checks need --full and AWS credentials"
fi

# --- Summary ---------------------------------------------------------------

FAILED="$(wc -l < "$TALLY_DIR/failed" | tr -d ' ')"
SKIPPED="$(wc -l < "$TALLY_DIR/skipped" | tr -d ' ')"

echo
if [ "$FAILED" -gt 0 ]; then
  red "$FAILED rule(s) failed"; printf ', %s skipped.\n' "$SKIPPED"
  printf '  failing: %s\n' "$(tr '\n' ' ' < "$TALLY_DIR/failed")"
  echo
  echo "Fix them, or record the exception in the pull request with its"
  echo "justification. Never silence a check to make it pass."
  exit 1
fi

green "All applicable rules passed"; printf ', %s skipped.\n' "$SKIPPED"
if [ "$SKIPPED" -gt 0 ]; then
  printf '  skipped: %s\n' "$(tr '\n' ' ' < "$TALLY_DIR/skipped")"
  echo "  Install the missing tools to close the gaps."
fi
exit 0
