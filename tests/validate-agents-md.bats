#!/usr/bin/env bats

setup() {
  export TEST_TMPDIR="$(mktemp -d)"
  export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  export SCRIPT="$REPO_ROOT/validate-agents-md.sh"
}

teardown() {
  [[ -d "$TEST_TMPDIR" ]] && rm -rf "$TEST_TMPDIR"
}

create_valid_agents_file() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
# Harness Knowledge Base

## OVERVIEW
This document provides an overview.

## STRUCTURE
- Item 1
- Item 2

## COMMANDS
- ./run.sh
- ./test.sh

## NOTES
Line 1
Line 2
Line 3
EOF
}

@test "exits 0 for valid AGENTS.md in subdirectory workspace" {
  local workspace="$TEST_TMPDIR/workspace"
  create_valid_agents_file "$workspace/project/AGENTS.md"

  run "$SCRIPT" "$workspace"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[PASS]"* ]]
  [[ "$output" == *"Validation PASSED"* ]]
}

@test "exits 1 when workspace has no AGENTS.md" {
  local workspace="$TEST_TMPDIR/empty"
  mkdir -p "$workspace"

  run "$SCRIPT" "$workspace"

  [ "$status" -eq 1 ]
  [[ "$output" == *"No AGENTS.md files found"* ]]
}

@test "reports WARN for subdirectory AGENTS.md exceeding 200 lines" {
  local workspace="$TEST_TMPDIR/workspace"
  local file="$workspace/large/AGENTS.md"
  create_valid_agents_file "$file"
  for i in $(seq 1 220); do
    printf 'extra line %s\n' "$i" >> "$file"
  done

  run "$SCRIPT" "$workspace"

  [ "$status" -eq 0 ]
  [[ "$output" == *"[WARN]"* ]]
  [[ "$output" == *"very long"* ]]
}

@test "exits 1 when required section headers are missing" {
  local workspace="$TEST_TMPDIR/workspace"
  local file="$workspace/bad/AGENTS.md"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<'EOF'
# Only One Header

## OVERVIEW
short content

additional line 1
additional line 2
additional line 3
additional line 4
additional line 5
additional line 6
additional line 7
additional line 8
EOF

  run "$SCRIPT" "$workspace"

  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL]"* ]]
  [[ "$output" == *"only 1/7 expected headers found"* ]]
}

@test "exits 1 when placeholder markers are present" {
  local workspace="$TEST_TMPDIR/workspace"
  local file="$workspace/placeholder/AGENTS.md"
  create_valid_agents_file "$file"
  printf 'TODO: finish this section\n' >> "$file"

  run "$SCRIPT" "$workspace"

  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL]"* ]]
  [[ "$output" == *"contains placeholder markers"* ]]
}

@test "handles empty workspace directory argument" {
  local workspace="$TEST_TMPDIR/blank"
  mkdir -p "$workspace"

  run "$SCRIPT" "$workspace"

  [ "$status" -eq 1 ]
  [[ "$output" == *"Workspace: $workspace"* ]]
  [[ "$output" == *"No AGENTS.md files found"* ]]
}
