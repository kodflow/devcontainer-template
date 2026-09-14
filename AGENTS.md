# Specialist Agents

29 agents in 8 categories, shipped by the `kodflow-specialists` marketplace plugin (https://github.com/kodflow/claude-marketplace), installed by `postStart.sh` — not repository files. All agents return condensed JSON to protect parent context.

## Orchestrators (2)

| Agent | Model | Purpose | Invoked By |
|-------|-------|---------|------------|
| `developer-orchestrator` | opus | Code review, refactoring, testing coordination | `/review`, `/plan` |
| `devops-orchestrator` | opus | Infrastructure, security, cost, sysadmin coordination | `/infra` |

## Language Specialists (8)

Each targets the **current stable version** and consults context7/official docs before generating code.

| Agent | Expertise | Min Version |
|-------|-----------|-------------|
| `developer-specialist-go` | Idiomatic Go, concurrency, error handling | 1.26+ |
| `developer-specialist-python` | Type hints, async, mypy strict, ruff | 3.14+ |
| `developer-specialist-nodejs` | TypeScript strict, ESLint, async patterns | 25+ |
| `developer-specialist-rust` | Ownership, lifetimes, clippy pedantic | 1.92+ |
| `developer-specialist-cpp` | C++23/26, concepts, coroutines, Clang-Tidy | C++23 |
| `developer-specialist-c` | Memory safety, UB prevention, C23 | C23 |
| `developer-specialist-react` | JSX/TSX, hooks, Server Components, Suspense, Concurrent | React 19 |
| `developer-specialist-zig` | comptime, allocator discipline, error unions, std.Io Writer/Reader | 0.15+ |

## Data & Tooling Specialists (2)

| Agent | Expertise | Invoked By |
|-------|-----------|------------|
| `data-specialist-postgres` | Schema design, query optimisation, EXPLAIN analysis, index selection | `developer-orchestrator` |
| `tooling-specialist-github-actions` | Workflows under `.github/workflows/`, composite/reusable actions | `devops-orchestrator` |

## Developer Executors (6)

| Agent | Task | Invoked By |
|-------|------|------------|
| `developer-specialist-review` | Code review orchestration (5 sub-executors) | `/review` |
| `developer-executor-correctness` | Invariants, state machines, concurrency bugs | `developer-specialist-review` |
| `developer-executor-security` | Taint analysis, OWASP Top 10, secrets detection | `developer-specialist-review` |
| `developer-executor-design` | Patterns, SOLID, DDD violations | `developer-specialist-review` |
| `developer-executor-quality` | Complexity, code smells, maintainability | `developer-specialist-review` |
| `developer-executor-shell` | Shell, Dockerfile, CI/CD safety | `developer-specialist-review` |

## DevOps Specialists (5)

| Agent | Domain | Invoked By |
|-------|--------|------------|
| `devops-specialist-infrastructure` | Terraform, OpenTofu, IaC | `devops-orchestrator`, `/infra` |
| `devops-specialist-security` | Vulnerability scanning, compliance | `devops-orchestrator`, `/infra` |
| `devops-specialist-docker` | Dockerfile optimization, Compose, security | `devops-orchestrator` |
| `devops-specialist-kubernetes` | K8s, K3s, minikube, Helm, GitOps, operators | `devops-orchestrator` |
| `devops-specialist-hashicorp` | Vault, Consul, Nomad, Packer, Boundary | `devops-orchestrator` |

## DevOps Executor / Router (1)

| Agent | Routing | Dispatch Target |
|-------|---------|-----------------|
| `devops-executor-linux` | `/etc/os-release` ID field | `os-specialist-{distro}` (3 distros) |

## OS Specialists (3)

Each agent knows its distro's package manager, init system, kernel, security model, and official documentation URLs. All return **condensed JSON**.

| Agent | Distro | Pkg Manager | Init System |
|-------|--------|-------------|-------------|
| `os-specialist-debian` | Debian | apt/dpkg | systemd |
| `os-specialist-ubuntu` | Ubuntu | apt/snap | systemd |
| `os-specialist-alpine` | Alpine | apk | OpenRC/s6 |

## Meta Agents (2)

| Agent | Model | Purpose | Invoked By |
|-------|-------|---------|------------|
| `developer-commentator` | opus | Orchestrate comment auditing across entire project | `/comment` |
| `developer-commentator-worker` | haiku | Audit/fix comments in a single file (WHY not WHAT) | `developer-commentator` |

## Routing Chains

```text
/review → developer-specialist-review (sonnet)
            → developer-executor-correctness (sonnet)
            → developer-executor-security (opus)
            → developer-executor-design (sonnet)
            → developer-executor-quality (haiku)
            → developer-executor-shell (haiku)

/plan → developer-orchestrator (opus)
          → developer-specialist-{lang} (sonnet)

/infra → devops-orchestrator (opus)
           → devops-specialist-{domain} (sonnet)
           → devops-executor-linux (haiku, router)
             → os-specialist-{distro} (haiku)

/comment → developer-commentator (opus)
             → developer-commentator-worker (haiku) × N files
```

## Decision Tree: Which Agent For My Task?

| I want to... | Agent | Model |
|--------------|-------|-------|
| Review code changes | `developer-specialist-review` | sonnet |
| Write Go/Python/Rust/etc. code | `developer-specialist-{lang}` | sonnet |
| Fix security vulnerabilities | `developer-executor-security` | opus |
| Analyze code complexity | `developer-executor-quality` | haiku |
| Check shell/Dockerfile safety | `developer-executor-shell` | haiku |
| Design/query a Postgres schema | `data-specialist-postgres` | sonnet |
| Edit a GitHub Actions workflow | `tooling-specialist-github-actions` | sonnet |
| Provision cloud infrastructure | `devops-specialist-infrastructure` | sonnet |
| Configure Kubernetes | `devops-specialist-kubernetes` | sonnet |
| Manage OS packages/services | `os-specialist-{debian,ubuntu,alpine}` | haiku |
| Audit/fix code comments | `developer-commentator` | opus |
| Scan for secrets/compliance | `devops-specialist-security` | sonnet |

## Agent Behavior

Agents must:
- Consult context7 or official docs before generating non-trivial code
- Target the current stable version of each language/OS
- Validate output against strict linting before returning
- Self-correct when linting or tests fail
- Return structured JSON for orchestrators to process
- Ask permission before destructive operations

## Registry

No machine-readable catalog. Agent definitions are one Markdown file per agent under `agents/` in the `kodflow-specialists` plugin; `postStart.sh` installs/updates the plugin into `~/.claude/plugins` at every container start (fail-open when offline — cached agents keep working).
