# Agent Guidelines

## Available Agents

### Orchestrators

| Agent | Purpose | Trigger |
|-------|---------|---------|
| `developer-orchestrator` | Code review, refactoring, testing coordination | `/review`, `/do` |
| `devops-orchestrator` | Infrastructure, security, cost optimization | `/infra` |

### Language Specialists

| Agent | Expertise |
|-------|-----------|
| `developer-specialist-go` | Go 1.24+, golangci-lint, race detection |
| `developer-specialist-python` | Python 3.14+, mypy strict, ruff |
| `developer-specialist-nodejs` | TypeScript strict, ESLint, Prettier |
| `developer-specialist-rust` | Ownership, clippy pedantic |
| `developer-specialist-java` | Java 25+, virtual threads |
| `developer-specialist-php` | PHP 8.5+, PHPStan max |
| `developer-specialist-ruby` | Ruby 4.0+, RuboCop, Sorbet |
| `developer-specialist-scala` | Scala 3.7+, Scalafix |
| `developer-specialist-elixir` | Elixir 1.19+, Dialyzer, Credo |
| `developer-specialist-dart` | Dart 3.10+, Flutter 3.38+ |
| `developer-specialist-cpp` | C++23/26, Clang-Tidy |
| `developer-specialist-carbon` | Carbon 0.1+, C++ interop |

### Executors

| Agent | Task |
|-------|------|
| `developer-executor-correctness` | Invariants, state machines, concurrency bugs |
| `developer-executor-security` | Taint analysis, OWASP, secrets detection |
| `developer-executor-design` | Patterns, SOLID, DDD violations |
| `developer-executor-quality` | Complexity, smells, maintainability |
| `developer-executor-shell` | Shell, Dockerfile, CI/CD safety |

## Agent Behavior

Agents:
- Know current stable language versions (no need to specify)
- Enforce code quality via linters and static analysis
- Return structured JSON for orchestrators to process
- Ask permission before destructive operations

## Delegation

Orchestrators delegate to specialists based on file types:
- `.go` files → `developer-specialist-go`
- `.py` files → `developer-specialist-python`
- `.ts/.js` files → `developer-specialist-nodejs`

## Limits

Agents do not:
- Execute destructive commands without permission
- Commit or push without explicit request
- Modify `.claude/` or `.devcontainer/` without approval
- Generate content mentioning AI/LLM
