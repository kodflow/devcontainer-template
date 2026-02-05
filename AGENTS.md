# Specialist Agents

## Orchestrators

| Agent | Purpose | Trigger |
|-------|---------|---------|
| `developer-orchestrator` | Code review, refactoring, testing coordination | `/review`, `/do` |
| `devops-orchestrator` | Infrastructure, security, cost optimization | `/infra` |

## Language Specialists

Each agent targets the **current stable version** and consults official documentation via context7 before generating code.

| Agent | Expertise | Min Version |
|-------|-----------|-------------|
| `developer-specialist-go` | Idiomatic Go, concurrency, error handling | 1.25+ |
| `developer-specialist-python` | Type hints, async, mypy strict, ruff | 3.14+ |
| `developer-specialist-nodejs` | TypeScript strict, ESLint, async patterns | 25+ |
| `developer-specialist-rust` | Ownership, lifetimes, clippy pedantic | 1.92+ |
| `developer-specialist-elixir` | OTP, GenServer, LiveView, Dialyzer | 1.19+ |
| `developer-specialist-java` | Virtual threads, records, sealed classes | 25+ |
| `developer-specialist-php` | Strict typing, attributes, PHPStan max | 8.5+ |
| `developer-specialist-ruby` | ZJIT, Ractors, RuboCop, Sorbet | 4.0+ |
| `developer-specialist-scala` | Context functions, opaque types, Scalafix | 3.7+ |
| `developer-specialist-dart` | Sound null safety, Flutter, dart analyze | 3.10+ |
| `developer-specialist-cpp` | C++23/26, concepts, coroutines, Clang-Tidy | C++23 |
| `developer-specialist-carbon` | C++ interop, modern safety, Bazel | 0.1+ |

## Executors

| Agent | Task |
|-------|------|
| `developer-executor-correctness` | Invariants, state machines, concurrency bugs |
| `developer-executor-security` | Taint analysis, OWASP Top 10, secrets detection |
| `developer-executor-design` | Patterns, SOLID, DDD violations |
| `developer-executor-quality` | Complexity, code smells, maintainability |
| `developer-executor-shell` | Shell, Dockerfile, CI/CD safety |

## DevOps Specialists

| Agent | Domain |
|-------|--------|
| `devops-specialist-aws` | AWS services, IAM, networking |
| `devops-specialist-gcp` | GCP services, BigQuery, IAM |
| `devops-specialist-azure` | Azure services, RBAC, AD |
| `devops-specialist-kubernetes` | K8s, Helm, GitOps |
| `devops-specialist-docker` | Dockerfile optimization, security |
| `devops-specialist-infrastructure` | Terraform, OpenTofu |
| `devops-specialist-security` | Vulnerability scanning, compliance |
| `devops-specialist-finops` | Cost optimization, right-sizing |

## Agent Behavior

Agents must:
- Consult context7 or official docs before generating non-trivial code
- Target the current stable version of each language
- Validate output against strict linting before returning
- Self-correct when linting or tests fail
- Return structured JSON for orchestrators to process
- Ask permission before destructive operations

## Delegation

Orchestrators delegate to specialists based on file types:
- `.go` files → `developer-specialist-go`
- `.py` files → `developer-specialist-python`
- `.ts/.js` files → `developer-specialist-nodejs`
- `.rs` files → `developer-specialist-rust`

## Limits

Agents do not:
- Execute destructive commands without permission
- Commit or push without explicit request
- Modify `.claude/` or `.devcontainer/` without approval
