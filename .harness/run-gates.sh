#!/usr/bin/env bash
#
# QA Gates for Harness Engineering
# Runs mechanical quality checks before allowing commits/merges
#
# Usage: ./.harness/run-gates.sh [--verbose] [--gate <name>]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="harness-engineering"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Options
VERBOSE=false
SINGLE_GATE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --gate)
      SINGLE_GATE="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--verbose] [--gate <name>]"
      exit 1
      ;;
  esac
done

log_info() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${BLUE}[INFO]${NC} $*"
  fi
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

run_gate() {
  local label="$1"
  local cmd="$2"
  local description="${3:-}"
  
  # If single gate mode, skip unrelated gates
  if [[ -n "$SINGLE_GATE" && "$label" != "$SINGLE_GATE" ]]; then
    return 0
  fi

  printf "  %-20s ... " "$label"
  
  local start_time
  start_time=$(date +%s.%N)
  
  # Capture output for verbose mode
  local output
  local exit_code=0
  
  if (cd "$PROJECT_ROOT" && output=$(eval "$cmd" 2>&1) || exit_code=$?); then
    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    printf "${GREEN}PASS${NC}"
    if [[ "$VERBOSE" == "true" ]]; then
      printf " (${duration}s)${NC}\n"
      if [[ -n "$output" ]]; then
        echo -e "    ${CYAN}Output:${NC}"
        echo "$output" | sed 's/^/      /'
      fi
    else
      echo ""
    fi
    PASS=$((PASS + 1))
  else
    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    printf "${RED}FAIL${NC}"
    if [[ "$VERBOSE" == "true" ]]; then
      printf " (${duration}s)${NC}\n"
      if [[ -n "$output" ]]; then
        echo -e "    ${RED}Error output:${NC}"
        echo "$output" | sed 's/^/      /'
      fi
    else
      echo ""
    fi
    FAIL=$((FAIL + 1))
    
    if [[ -n "$description" ]]; then
      log_warn "  $description"
    fi
  fi
}

skip_gate() {
  local label="$1"
  local reason="$2"
  
  # If single gate mode, skip unrelated gates
  if [[ -n "$SINGLE_GATE" && "$label" != "$SINGLE_GATE" ]]; then
    return 0
  fi

  printf "  %-20s ... ${YELLOW}SKIP${NC} (%s)\n" "$label" "$reason"
  SKIP=$((SKIP + 1))
}

echo ""
echo -e "${CYAN}=== $PROJECT_NAME QA Gates ===${NC}"
if [[ "$VERBOSE" == "true" ]]; then
  echo "Project root: $PROJECT_ROOT"
  echo "Mode: verbose"
  if [[ -n "$SINGLE_GATE" ]]; then
    echo "Single gate: $SINGLE_GATE"
  fi
fi
echo ""

# Gate 1: Syntax — check shell scripts
run_gate "syntax" "find . -name '*.sh' -type f -exec bash -n {} \; 2>&1" \
  "Shell script syntax errors detected. Run 'shellcheck' for details."

# Gate 2: ShellCheck (if available)
if command -v shellcheck &>/dev/null; then
  run_gate "shellcheck" "shellcheck -x $(find . -name '*.sh' -type f | tr '\n' ' ')" \
    "ShellCheck found issues. Review and fix style/quality problems."
else
  skip_gate "shellcheck" "shellcheck not installed"
fi

# Gate 3: Validate — verify expected directory structure
run_gate "structure" "test -d agents && test -d commands && test -d skills" \
  "Required directories missing: agents/, commands/, skills/"

# Gate 4: AGENTS.md validation
if [[ -f "$PROJECT_ROOT/AGENTS.md" ]]; then
  run_gate "agents-md" "test -s AGENTS.md && grep -q 'OVERVIEW' AGENTS.md" \
    "AGENTS.md is empty or missing required OVERVIEW section"
else
  skip_gate "agents-md" "AGENTS.md not found"
fi

# Gate 5: YAML syntax (if YAML files exist)
if find . -name "*.yml" -o -name "*.yaml" | grep -q .; then
  if command -v python3 &>/dev/null; then
    run_gate "yaml" "python3 -c 'import yaml, sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]' $(find . -name '*.yml' -o -name '*.yaml' | head -10)" \
      "YAML syntax error in configuration files"
  else
    skip_gate "yaml" "python3 not available"
  fi
else
  skip_gate "yaml" "no YAML files found"
fi

# Gate 6: No TODO comments in production code (optional warning)
if grep -r "TODO" --include="*.sh" --include="*.md" . 2>/dev/null | grep -v ".git" | grep -q .; then
  log_warn "  Found TODO comments in codebase (consider addressing)"
fi

# Gate 7: File permissions (scripts should be executable)
run_gate "permissions" "find . -name '*.sh' -type f ! -perm -u+x -exec test -f {} \; -quit || true" \
  "Some shell scripts are not executable"

echo ""
echo -e "${CYAN}=== Results ===${NC}"
echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}SKIP: $SKIP${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}FAILED: $FAIL gate(s) failed. Fix issues before committing.${NC}"
  exit 1
else
  echo -e "${GREEN}SUCCESS: All gates passed.${NC}"
  exit 0
fi
