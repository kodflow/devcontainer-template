# Claude Code Agents

## Architecture

RLM (Recursive Language Model) decomposition with 3-tier hierarchy.

```text
Orchestrators (opus)     → Strategy, delegation, synthesis
    ├── Specialists (sonnet)  → Domain expertise, analysis
    │       └── Executors (haiku)  → Fast, focused execution
```

## Agent Inventory (32 total)

### Orchestrators (2) - opus

| Agent | Domain | Responsibility |
|-------|--------|----------------|
| `developer-orchestrator` | Development | Code strategy, review coordination |
| `devops-orchestrator` | Operations | Infrastructure strategy, deployment |

### Language Specialists (12) - sonnet

| Agent | Version | Standards |
|-------|---------|-----------|
| `developer-specialist-nodejs` | Node.js >= 25.0, TS >= 5.7 | strict, ESLint, Prettier |
| `developer-specialist-python` | Python >= 3.14 | mypy --strict, ruff, pytest |
| `developer-specialist-go` | Go >= 1.25 | golangci-lint, race detector |
| `developer-specialist-rust` | Rust >= 1.92, Edition 2024 | clippy pedantic, cargo audit |
| `developer-specialist-java` | Java >= 25 | SpotBugs, Checkstyle |
| `developer-specialist-php` | PHP >= 8.5 | PHPStan max, PHP-CS-Fixer |
| `developer-specialist-ruby` | Ruby >= 4.0 | RuboCop, Steep/Sorbet |
| `developer-specialist-scala` | Scala >= 3.7 | Scalafix, Scalafmt |
| `developer-specialist-elixir` | Elixir >= 1.19, OTP >= 28 | Dialyzer, Credo |
| `developer-specialist-dart` | Dart >= 3.10, Flutter >= 3.38 | dart analyze strict |
| `developer-specialist-cpp` | C++ >= C++23 | Clang-Tidy, sanitizers |
| `developer-specialist-carbon` | Carbon >= 0.1 | Experimental, Bazel |

### DevOps Specialists (9) - sonnet

| Agent | Domain | Focus |
|-------|--------|-------|
| `devops-specialist-aws` | AWS | CDK, Lambda, EKS, S3 |
| `devops-specialist-gcp` | GCP | GKE, Cloud Run, BigQuery |
| `devops-specialist-azure` | Azure | AKS, Functions, CosmosDB |
| `devops-specialist-kubernetes` | K8s | Helm, Operators, GitOps |
| `devops-specialist-docker` | Containers | Multi-stage, Compose |
| `devops-specialist-hashicorp` | HashiCorp | Terraform, Vault, Consul |
| `devops-specialist-infrastructure` | IaC | Terraform, Ansible |
| `devops-specialist-security` | Security | SAST, secrets, compliance |
| `devops-specialist-finops` | FinOps | Cost optimization |

### Developer Specialists (1) - sonnet

| Agent | Domain | Focus |
|-------|--------|-------|
| `developer-specialist-review` | Code Review | Quality, patterns, security |

### Executors (8) - haiku

| Agent | Type | Expertise |
|-------|------|-----------|
| `devops-executor-linux` | OS | Debian, Ubuntu, RHEL |
| `devops-executor-bsd` | OS | FreeBSD, OpenBSD |
| `devops-executor-osx` | OS | macOS, Homebrew |
| `devops-executor-windows` | OS | PowerShell, WSL |
| `devops-executor-qemu` | VM | KVM, libvirt |
| `devops-executor-vmware` | VM | vSphere, ESXi |
| `developer-executor-security` | Security | Scans, CVE checks |
| `developer-executor-quality` | Quality | Tests, coverage |

## MCP Tools (Mandatory)

All agents have access to these MCP tools:

| Tool | Package | Usage |
|------|---------|-------|
| `mcp__grepai__grepai_search` | grepai | Semantic code search |
| `mcp__grepai__grepai_trace_callers` | grepai | Find function callers |
| `mcp__grepai__grepai_trace_callees` | grepai | Find called functions |

**GREPAI-FIRST RULE:** Use grepai_search instead of Grep for semantic queries.

## Academic Standards

All language specialists enforce:

```yaml
type_safety: "Strict typing, no implicit any/null"
documentation: "Full API docs, examples, error docs"
design_patterns: "DI, Result types, Builder, RAII"
error_handling: "Explicit errors, no panics, proper context"
validation: "Format → Imports → Lint → Types"
```

## Post-Edit Hooks

Automatic pipeline on every file edit:

1. **Format** - Language-specific formatter
2. **Imports** - Sort and organize imports
3. **Lint** - Static analysis with auto-fix
4. **Types** - Type checking (mypy, tsc, etc.)

## Usage

```yaml
# Spawn specialist for TypeScript review
Task(developer-specialist-nodejs, "Review authentication module")

# Spawn orchestrator for complex task
Task(developer-orchestrator, "Design microservices architecture")

# Parallel specialist invocation
Task(developer-specialist-python, "Analyze data models")
Task(developer-specialist-go, "Review API handlers")
```
