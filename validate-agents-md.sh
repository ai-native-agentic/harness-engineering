#!/usr/bin/env bash
# =============================================================================
# validate-agents-md.sh — AGENTS.md quality validation
# =============================================================================
# Checks all AGENTS.md files in a workspace for:
#   1. Size (line count within expected range)
#   2. Required section headers (at least 3 of 7 expected)
#   3. No placeholder/TODO markers
#
# Usage: ./validate-agents-md.sh [WORKSPACE_DIR]
# Exit:  0 if all PASS/WARN, 1 if any FAIL
# =============================================================================
set -euo pipefail

WORKSPACE="${1:-/home/lunark/projects/ai-native-agentic-org}"
WORKSPACE="$(cd "$WORKSPACE" && pwd)"  # resolve to absolute path

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BOLD='' NC=''
fi

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

# Expected section headers (case-insensitive match)
EXPECTED_HEADERS=(
    "## OVERVIEW"
    "## STRUCTURE"
    "## WHERE TO LOOK"
    "## COMMANDS"
    "## CONVENTIONS"
    "## ANTI-PATTERNS"
    "## TECH STACK"
)

# Placeholder patterns that should NOT appear
PLACEHOLDER_PATTERNS='(^|\s)(TODO|PLACEHOLDER|\[TBD\])(\s|$|:)'

check_file() {
    local file="$1"
    local relpath="${file#"$WORKSPACE"/}"
    local issues=()
    local warnings=()
    local status="PASS"

    # --- Line count ---
    local line_count
    line_count=$(wc -l < "$file")

    # Determine if root AGENTS.md (directly in workspace root)
    local dir
    dir="$(dirname "$file")"
    if [[ "$dir" == "$WORKSPACE" ]]; then
        # Root AGENTS.md: 30-300 lines
        if (( line_count < 30 )); then
            issues+=("too short: ${line_count} lines (min 30 for root)")
            status="FAIL"
        elif (( line_count > 300 )); then
            warnings+=("very long: ${line_count} lines (max 300 for root)")
            status="WARN"
        fi
    else
        # Subdirectory AGENTS.md: 10-200 lines
        if (( line_count < 10 )); then
            issues+=("too short: ${line_count} lines (min 10)")
            status="FAIL"
        elif (( line_count > 200 )); then
            warnings+=("very long: ${line_count} lines (max 200 for subdir)")
            status="WARN"
        fi
    fi

    # --- Section header check (need at least 3 of 7) ---
    local header_count=0
    local found_headers=()
    for header in "${EXPECTED_HEADERS[@]}"; do
        if grep -qi "^${header}" "$file" 2>/dev/null; then
            (( header_count++ )) || true
            found_headers+=("$header")
        fi
    done

    if (( header_count < 3 )); then
        issues+=("only ${header_count}/7 expected headers found (need ≥3)")
        status="FAIL"
    fi

    # --- Placeholder check ---
    local placeholder_matches
    placeholder_matches=$(grep -Ecn "$PLACEHOLDER_PATTERNS" "$file" 2>/dev/null || true)
    if [[ -n "$placeholder_matches" && "$placeholder_matches" != "0" ]]; then
        # Get first match for context
        local first_match
        first_match=$(grep -En "$PLACEHOLDER_PATTERNS" "$file" 2>/dev/null | head -1 || true)
        issues+=("contains placeholder markers (${placeholder_matches} occurrences, e.g. ${first_match})")
        status="FAIL"
    fi

    # --- Print result ---
    case "$status" in
        PASS)
            printf "${GREEN}[PASS]${NC} %s (%d lines, %d/%d headers)\n" "$relpath" "$line_count" "$header_count" "${#EXPECTED_HEADERS[@]}"
            (( PASS_COUNT++ )) || true
            ;;
        WARN)
            printf "${YELLOW}[WARN]${NC} %s (%d lines, %d/%d headers)\n" "$relpath" "$line_count" "$header_count" "${#EXPECTED_HEADERS[@]}"
            for w in "${warnings[@]}"; do
                printf "       ⚠ %s\n" "$w"
            done
            (( WARN_COUNT++ )) || true
            ;;
        FAIL)
            printf "${RED}[FAIL]${NC} %s (%d lines, %d/%d headers)\n" "$relpath" "$line_count" "$header_count" "${#EXPECTED_HEADERS[@]}"
            for issue in "${issues[@]}"; do
                printf "       ✗ %s\n" "$issue"
            done
            (( FAIL_COUNT++ )) || true
            ;;
    esac
}

# =============================================================================
# Main
# =============================================================================
printf "${BOLD}AGENTS.md Validation${NC}\n"
printf "Workspace: %s\n\n" "$WORKSPACE"

# Find all AGENTS.md files, excluding common junk dirs
mapfile -t files < <(
    find "$WORKSPACE" -name "AGENTS.md" \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/.venv/*" \
        -not -path "*/venv/*" \
        -not -path "*/.tox/*" \
    | sort
)

if (( ${#files[@]} == 0 )); then
    printf "${RED}No AGENTS.md files found in %s${NC}\n" "$WORKSPACE"
    exit 1
fi

printf "Found %d AGENTS.md file(s)\n\n" "${#files[@]}"

for file in "${files[@]}"; do
    check_file "$file"
done

# --- Summary ---
printf "\n${BOLD}Summary:${NC} %d PASS, %d WARN, %d FAIL (out of %d files)\n" \
    "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "${#files[@]}"

if (( FAIL_COUNT > 0 )); then
    printf "${RED}Validation FAILED${NC}\n"
    exit 1
else
    printf "${GREEN}Validation PASSED${NC}\n"
    exit 0
fi
