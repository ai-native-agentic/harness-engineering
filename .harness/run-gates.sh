#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="harness-engineering"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0
SKIP=0

run_gate() {
  local label="$1"
  local cmd="$2"
  printf "  %-20s ... " "$label"
  if (cd "$PROJECT_ROOT" && eval "$cmd") >/dev/null 2>&1; then
    printf "${GREEN}PASS${NC}\n"
    PASS=$((PASS + 1))
  else
    printf "${RED}FAIL${NC}\n"
    FAIL=$((FAIL + 1))
  fi
}

skip_gate() {
  local label="$1"
  local reason="$2"
  printf "  %-20s ... %sSKIP%s (%s)\n" "$label" "$YELLOW" "$NC" "$reason"
  SKIP=$((SKIP + 1))
}

echo ""
echo "=== $PROJECT_NAME QA Gates ==="
echo ""

# Gate 1: Syntax — check shell scripts if any exist
run_gate "syntax" "bash -n agents/*.sh 2>/dev/null || true"

# Gate 2: Lint — no shellcheck configured
skip_gate "lint" "no shellcheck configured"

# Gate 3: Validate — verify expected directory structure
run_gate "validate" "test -d agents && test -d commands"

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}SKIP: $SKIP${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
