#!/usr/bin/env bash
set -euo pipefail

BASE="/home/lunark/projects/ai-native-agentic-org"
SCRIPTS_DIR="$BASE/scripts"
STATE_FILE="$SCRIPTS_DIR/learning-state.json"
DATE="$(date +%Y-%m-%d)"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DIR="$BASE/.sisyphus/notepads/self-learning"
PRE_STATE="${STATE_FILE}.pre"

mkdir -p "$REPORT_DIR"

echo "=== Self-Learning Loop: $DATE ==="

echo "[Phase 1] Scanning all projects..."
python3 "$SCRIPTS_DIR/project-health-check.py" --base "$BASE" --output "$STATE_FILE"
cp "$STATE_FILE" "$PRE_STATE"

echo "[Phase 2] Selecting TOP 5 improvement targets..."
TOP5="$({
python3 - "$STATE_FILE" <<'PY'
import json
import sys
from datetime import datetime, timezone

state_file = sys.argv[1]
state = json.load(open(state_file, encoding="utf-8"))
projects = state.get("projects", {})

def days_since(value: str | None) -> int:
    if not value:
        return 365
    try:
        when = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return 365
    now = datetime.now(timezone.utc)
    delta = now - when.astimezone(timezone.utc)
    return max(int(delta.days), 0)

scored = []
for name, data in projects.items():
    if data.get("known_issues", False):
        continue
    lint_errors = int(data.get("lint", {}).get("errors", 0))
    test_fails = int(data.get("tests", {}).get("failed", 0))
    gate_fails = int(data.get("gates", {}).get("fail", 0))
    age_days = days_since(data.get("last_improved"))
    age_score = min(age_days, 30)

    score = lint_errors * 1 + test_fails * 5 + gate_fails * 10 + age_score
    if score > 0:
        scored.append((name, score))

scored.sort(key=lambda item: item[1], reverse=True)
print(" ".join(name for name, _ in scored[:5]))
PY
} | tr -d '\n')"

if [ -z "$TOP5" ]; then
  echo "[Phase 2] All projects clean. Nothing to improve."
  rm -f "$PRE_STATE"
  exit 0
fi
echo "[Phase 2] Selected: $TOP5"

echo "[Phase 3] Running improvements..."
for project in $TOP5; do
  project_dir="$BASE/$project"
  if [ ! -d "$project_dir" ]; then
    echo "  - skip $project: directory missing"
    continue
  fi

  echo "  - improving $project"
  timeout 300 opencode run \
    --dir "$project_dir" \
    --title "Self-learning: improve $project ($DATE)" \
    --prompt "Analyze and fix issues in this project. Focus on: (1) fix lint errors using the language-appropriate linter, (2) fix failing tests, (3) make .harness/run-gates.sh pass. Keep changes minimal and safe. If fixed, commit with: fix: self-learning auto-improvement ($DATE)." \
    >/tmp/self-learning-"$project".log 2>&1 || echo "  - warning: opencode failed for $project"
done

echo "[Phase 4] Recording results..."
python3 "$SCRIPTS_DIR/project-health-check.py" --base "$BASE" --output "$STATE_FILE"

python3 - "$PRE_STATE" "$STATE_FILE" "$REPORT_DIR/$DATE.md" "$TS" <<'PY'
import json
import sys
from datetime import datetime

pre_path, post_path, report_path, ts = sys.argv[1:5]
pre = json.load(open(pre_path, encoding="utf-8"))
post = json.load(open(post_path, encoding="utf-8"))

pre_projects = pre.get("projects", {})
post_projects = post.get("projects", {})

lines = [
    f"# Self-Learning Report: {datetime.utcnow().date()}",
    "",
    f"- generated_at: {ts}",
    "",
    "| project | lint before->after | test failed before->after | gate fail before->after | known issues |",
    "|---|---:|---:|---:|---|",
]

for name in sorted(post_projects):
    before = pre_projects.get(name, {})
    after = post_projects.get(name, {})

    lint_before = int(before.get("lint", {}).get("errors", 0))
    lint_after = int(after.get("lint", {}).get("errors", 0))
    test_before = int(before.get("tests", {}).get("failed", 0))
    test_after = int(after.get("tests", {}).get("failed", 0))
    gate_before = int(before.get("gates", {}).get("fail", 0))
    gate_after = int(after.get("gates", {}).get("fail", 0))
    known = "yes" if after.get("known_issues", False) else "no"

    lines.append(
        f"| {name} | {lint_before}->{lint_after} | {test_before}->{test_after} | {gate_before}->{gate_after} | {known} |"
    )

open(report_path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print(f"Report saved to {report_path}")
PY

rm -f "$PRE_STATE"
echo "=== Self-Learning Loop Complete ==="
