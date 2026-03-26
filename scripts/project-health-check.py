#!/usr/bin/env python3
"""Scan sub-projects and write health report as JSON state."""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SKIP_DIRS = {
    "audio",
    "data",
    "docs",
    "logs",
    "monitoring",
    "reports",
    "shared",
    "scripts",
    "demo",
}


def now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def detect_language(project_dir: Path) -> str:
    if (project_dir / "package.json").exists():
        return "typescript"
    if (project_dir / "pyproject.toml").exists():
        return "python"
    if (project_dir / "Cargo.toml").exists():
        return "rust"
    return "unknown"


def run_command(command: list[str], cwd: Path) -> dict[str, Any]:
    try:
        proc = subprocess.run(
            command,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        output = (proc.stdout + "\n" + proc.stderr).strip()
        return {
            "ok": proc.returncode == 0,
            "returncode": proc.returncode,
            "output": output,
            "command": " ".join(command),
        }
    except FileNotFoundError:
        return {
            "ok": False,
            "returncode": 127,
            "output": f"command not found: {command[0]}",
            "command": " ".join(command),
        }
    except subprocess.TimeoutExpired:
        return {
            "ok": False,
            "returncode": 124,
            "output": "command timed out",
            "command": " ".join(command),
        }


def _count_nonempty_lines(text: str) -> int:
    return sum(1 for line in text.splitlines() if line.strip())


def run_lint(project_dir: Path, lang: str) -> dict[str, Any]:
    if lang == "typescript":
        cmd = ["oxlint", "."]
    elif lang == "python":
        cmd = ["ruff", "check", "."]
    elif lang == "rust":
        cmd = [
            "cargo",
            "clippy",
            "--all-targets",
            "--all-features",
            "--",
            "-D",
            "warnings",
        ]
    else:
        return {
            "status": "skipped",
            "errors": 0,
            "output": "unsupported language",
            "command": None,
        }

    result = run_command(cmd, project_dir)
    errors = 0 if result["ok"] else _count_nonempty_lines(result["output"])
    return {
        "status": "pass" if result["ok"] else "fail",
        "errors": errors,
        "output": result["output"],
        "command": result["command"],
        "returncode": result["returncode"],
    }


def run_tests(project_dir: Path, lang: str) -> dict[str, Any]:
    if lang == "typescript":
        cmd = ["vitest", "run"]
    elif lang == "python":
        cmd = ["pytest", "-q"]
    elif lang == "rust":
        cmd = ["cargo", "test", "--quiet"]
    else:
        return {
            "status": "skipped",
            "passed": 0,
            "failed": 0,
            "total": 0,
            "output": "unsupported language",
            "command": None,
        }

    result = run_command(cmd, project_dir)
    failed = 0 if result["ok"] else 1
    passed = 1 if result["ok"] else 0
    return {
        "status": "pass" if result["ok"] else "fail",
        "passed": passed,
        "failed": failed,
        "total": passed + failed,
        "output": result["output"],
        "command": result["command"],
        "returncode": result["returncode"],
    }


def run_gates(project_dir: Path) -> dict[str, Any]:
    gate_script = project_dir / ".harness" / "run-gates.sh"
    if not gate_script.exists():
        return {
            "status": "skipped",
            "pass": 0,
            "fail": 0,
            "skip": 1,
            "output": "gate script not found",
            "command": None,
        }

    result = run_command(["bash", str(gate_script)], project_dir)
    return {
        "status": "pass" if result["ok"] else "fail",
        "pass": 1 if result["ok"] else 0,
        "fail": 0 if result["ok"] else 1,
        "skip": 0,
        "output": result["output"],
        "command": result["command"],
        "returncode": result["returncode"],
    }


def check_project(
    project_dir: Path, previous: dict[str, Any] | None = None
) -> dict[str, Any]:
    prev = previous or {}
    lang = detect_language(project_dir)
    lint = run_lint(project_dir, lang)
    tests = run_tests(project_dir, lang)
    gates = run_gates(project_dir)

    return {
        "path": str(project_dir),
        "language": lang,
        "last_checked": now_iso(),
        "lint": lint,
        "tests": tests,
        "gates": gates,
        "known_issues": bool(prev.get("known_issues", False)),
        "last_improved": prev.get("last_improved"),
        "failure_streak": int(prev.get("failure_streak", 0)),
    }


def discover_projects(base_dir: Path) -> list[Path]:
    projects: list[Path] = []
    for child in sorted(base_dir.iterdir()):
        if not child.is_dir():
            continue
        if child.name.startswith("."):
            continue
        if child.name in SKIP_DIRS:
            continue
        projects.append(child)
    return projects


def load_previous_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def build_state(
    base_dir: Path, projects: list[Path], previous_state: dict[str, Any]
) -> dict[str, Any]:
    prev_projects = previous_state.get("projects", {})
    state_projects: dict[str, Any] = {}

    for project_dir in projects:
        name = project_dir.name
        prev = prev_projects.get(name, {})
        current = check_project(project_dir, prev)

        score = (
            int(current.get("lint", {}).get("errors", 0))
            + 5 * int(current.get("tests", {}).get("failed", 0))
            + 10 * int(current.get("gates", {}).get("fail", 0))
        )
        if score > 0:
            current["failure_streak"] = int(prev.get("failure_streak", 0)) + 1
        else:
            current["failure_streak"] = 0

        if current["failure_streak"] >= 3:
            current["known_issues"] = True

        state_projects[name] = current

    return {
        "schema_version": 1,
        "base": str(base_dir),
        "updated_at": now_iso(),
        "skip_dirs": sorted(SKIP_DIRS),
        "projects": state_projects,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Scan sub-projects and output health report as JSON"
    )
    parser.add_argument("--base", default="/home/lunark/projects/ai-native-agentic-org")
    parser.add_argument("--output", default="scripts/learning-state.json")
    parser.add_argument("--project", help="Check single project only")
    args = parser.parse_args()

    base_dir = Path(args.base).expanduser().resolve()
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = (base_dir / output_path).resolve()

    previous_state = load_previous_state(output_path)

    if args.project:
        project_dir = (base_dir / args.project).resolve()
        if not project_dir.exists() or not project_dir.is_dir():
            raise SystemExit(f"project not found: {args.project}")
        projects = [project_dir]
    else:
        projects = discover_projects(base_dir)

    state = build_state(base_dir, projects, previous_state)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(f"Wrote health state: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
