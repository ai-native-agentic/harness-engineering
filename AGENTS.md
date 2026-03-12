# HARNESS-ENGINEERING - KNOWLEDGE BASE

**Generated:** 2026-03-10
**Commit:** 719bffb
**Branch:** main

## OVERVIEW

Agent scaffolding infrastructure for safe, incremental, agent-driven development. Formalizes OpenAI's Harness Engineering approach: repo-enforced constraints, mechanical quality gates, architecture-as-code, taste-as-code. Provides Claude Code skills, agent definitions, prompt hooks, and RPEQ workflow (Research → Plan → Execute → QA).

Stack: Shell scripts, YAML configs, Markdown docs

## STRUCTURE

```
.
├── docs/                        # Specifications
│   ├── harness-engineering.md   # Full HES v1 specification
│   └── workflows/RPEQ.md        # Research → Plan → Execute → QA
├── agents/                      # Agent role definitions
│   ├── analysis/                # Codebase analysis agents
│   ├── development/             # TDD, refactoring agents
│   ├── documentation/           # Docs generation agents
│   ├── research/                # Research + synthesis
│   ├── performance/             # Profiling, optimization
│   └── security/                # Security review
├── commands/                    # Claude Code slash commands
│   ├── context-engineering/     # Research, plan, execute workflow
│   ├── integration/             # External tool integrations
│   ├── quality-assurance/       # QA + inspection
│   └── utilities/               # Helpers
├── skills/                      # Reusable skill definitions
│   ├── ast-grep-setup/          # TypeScript ast-grep rules
│   ├── codebase-research/       # Codebase mapping
│   ├── execute-from-plan/       # Plan execution
│   ├── planning-from-research/  # Plan generation
│   └── qa-from-execution/       # Post-exec QA
├── prompt-hooks/                # Automation hooks
├── alias/                       # Model alias configs
├── rules/                       # Linting/enforcement rules
└── status-line/                 # Status display utilities
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Understand Harness Engineering | `docs/harness-engineering.md` | Full HES v1 spec |
| RPEQ workflow | `docs/workflows/RPEQ.md` | Research → Plan → Execute → QA |
| Agent definitions | `agents/` | Role-specific agent configs |
| Claude Code commands | `commands/` | Slash command implementations |
| Skills | `skills/` | Reusable workflow components |
| Prompt hooks | `prompt-hooks/` | Automation triggers |
| AST rules setup | `skills/ast-grep-setup/` | TypeScript pattern enforcement |
| Codebase research | `skills/codebase-research/` | Map codebase for agents |
| Plan generation | `skills/planning-from-research/` | Create execution plans |
| Execution | `skills/execute-from-plan/` | Execute from plan docs |
| QA review | `skills/qa-from-execution/` | Post-execution verification |

## CONVENTIONS

### Harness Engineering Principles
1. **One canonical command**: `just check` runs all gates locally + CI
2. **Architecture as code**: Import boundaries enforced mechanically (Import Linter, grimp)
3. **Taste as code**: AST rules (ast-grep) ban anti-patterns
4. **Evidence-based chunks**: Every change → tests, snapshots, golden diffs
5. **Progressive disclosure**: AGENTS.md = map, not encyclopedia
6. **Agent-to-agent review**: Council of models votes on risky changes

### RPEQ Workflow
```
Research → Plan → Execute → QA
- Research: Map codebase, identify patterns
- Plan: Create execution plan from research
- Execute: Implement changes incrementally
- QA: Verify with tests, gates, review
```

### Agent Role Structure
```yaml
name: "agent-name"
role: "description"
capabilities: [...]
constraints: [...]
quality_gates: [...]
```

### Progressive Disclosure
- AGENTS.md: High-level map (50-150 lines)
- Deeper docs: Linked for context expansion
- "What Codex can't see doesn't exist" — encode in repo

## ANTI-PATTERNS (THIS PROJECT)

| Forbidden | Why | Reference |
|-----------|-----|-----------|
| Knowledge in Slack/Docs | Illegible to agents | `docs/harness-engineering.md` |
| Skipping mechanical gates | Defeats safety guarantee | Core principles |
| Manual import boundary checks | Must be mechanically enforced | Architecture-as-code |
| Large monolithic changes | Violates incremental safety | Evidence-based chunks |
| Single-model approval | Need agent council for risky changes | Agent-to-agent review |
| AGENTS.md > 150 lines | Defeats progressive disclosure | HES v1 spec |

## PROVEN RESULTS

**Harness Engineering Benefits**:
- Safe agent-driven development at scale
- Mechanical enforcement prevents regressions
- Incremental changes with evidence (tests/snapshots)
- Repo as single source of truth for agents
- Agent-to-agent review for quality control

**OpenAI Insights**:
> "What Codex can't see doesn't exist."
- Knowledge must live in repo
- Architecture, taste, standards → code
- Mechanical verification over manual review

## COMMANDS

```bash
# Run all quality gates (local + CI)
just check

# Research phase
claude /research [topic]

# Planning phase
claude /plan-from-research [research-doc]

# Execution phase
claude /execute-from-plan [plan-doc]

# QA phase
claude /qa-from-execution [execution-doc]
```

## NOTES

- **Inspired by**: OpenAI's Harness Engineering approach
- **Active formalization**: This is an active attempt to implement HES v1
- **Claude Code native**: Skills and commands designed for Claude Code CLI
- **Mechanical enforcement**: Import boundaries (Import Linter, grimp), AST patterns (ast-grep)
- **Agent council**: Multi-model voting for risky changes
- **Progressive disclosure**: AGENTS.md = map → deeper docs on demand
- **RPEQ workflow**: Standard process for agent-driven work
- **Status line**: Utilities for displaying harness state
- **Prompt hooks**: Automation triggers for consistent behavior
- **Model aliases**: Custom model configurations for specific roles
