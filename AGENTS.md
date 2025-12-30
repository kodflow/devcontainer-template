# Repository Guidelines

## Project Structure & Module Organization

The repository ships a reusable Dev Container template rather than application source. All infrastructure lives under `.devcontainer/`, with `devcontainer.json`, `docker-compose.yml`, lifecycle hooks, custom features, and the base image definition in `images/`. GitHub automation, workflow instructions, and AI reviewer policies live in `.github/`. Cross-cutting policies for contributors are in `CLAUDE.md`, `.qodo-merge.toml`, `.codacy.yaml`, and `.coderabbit.yaml` at the repo root. When you bootstrap an actual project from this template, migrate your application code into `/src` and `/tests` (per `CLAUDE.md`) and keep documentation in `/docs`.

## Build, Test, and Development Commands

```bash
# Rebuild the VS Code Dev Container after editing .devcontainer/*
Dev Containers: Rebuild Container

# Run Claude CLI with the project MCP config (alias created in postCreate.sh)
super-claude /review --all

# Tear down helper services and named volumes when the environment drifts
docker compose -f .devcontainer/docker-compose.yml down -v
```

## Coding Style & Naming Conventions

- **Indentation**: Two spaces for YAML, JSON, and shell snippets shipped in this repo. Language-specific rules come from `.devcontainer/features/languages/<lang>/RULES.md` (for Node.js: TypeScript + ESLint + Prettier, strict TS compiler options, ES modules).
- **File naming**: Template assets use kebab-case or snake_case; Node code that you scaffold must keep files and directories in kebab-case (see `nodejs/RULES.md`).
- **Function/variable naming**: Align with the selected language RULES (e.g., camelCase for functions/variables, PascalCase for classes and types in TypeScript).
- **Linting**: Shell scripts must satisfy ShellCheck (see `.coderabbit.yaml`). Language-specific lint/format tooling is bootstrapped via devcontainer features (Node feature installs ESLint, Prettier, TypeScript, tsx, pnpm, etc.).

## Testing Guidelines

- **Framework**: Follow each language RULES file; the default Node setup expects Vitest or Jest with >=80% coverage.
- **Test files**: Place suites under `/tests` (or next to Go source). Keep parity between `/src` modules and their test directories.
- **Running tests**: Expose a `pnpm test -- --coverage` (or equivalent) script in `package.json` once you add code. The Dev Container ships pnpm/node tooling so the command works immediately.
- **Coverage**: Enforce the 80% floor mandated by `nodejs/RULES.md`; update CI to fail if the threshold drops.

## Commit & Pull Request Guidelines

- **Commit format**: Use conventional commits with branch-scoped prefixes described in `CLAUDE.md`, e.g., `feat(devcontainer): add carbon feature` or `fix(hooks): harden gnome-keyring setup`.
- **PR process**: Always work through `/feature` or `/fix` flows (planning mode, `/plan` phases, `/apply` implementation). PRs are reviewed by Codacy and CodeRabbit, and `pr_reviewer` in `.qodo-merge.toml` enforces security, test, and compliance gates.
- **Branch naming**: `feat/<description>` for features, `fix/<description>` for bug fixes; never push directly to `main`.

---

# Repository Tour

## 🎯 What This Repository Does

Kodflow DevContainer Template provides a batteries-included VS Code Dev Container configuration that ships Claude CLI, CodeRabbit, major cloud CLIs, HashiCorp tooling, and language features so new projects can bootstrap a consistent, secure development workstation in seconds.

**Key responsibilities:**
- Curate the Docker image, docker-compose services, and lifecycle scripts that power the containerized IDE.
- Encode company-wide policies (CLAUDE.md, RULES.md, compliance checklists) and enforce them via hooks and MCP tools.
- Document contributor workflows so projects cloned from this template inherit repeatable build/test/deploy practices.

---

## 🏗️ Architecture Overview

```
Developer IDE (VS Code Dev Containers)
        ↓
.devcontainer/docker-compose.yml → devcontainer service (Docker)
        ↓
Base image (.devcontainer/images/Dockerfile)
        ↓
Lifecycle hooks + features → Tools (Claude CLI, cloud CLIs, HashiCorp suite)
        ↓
MCP servers (github, codacy, taskwarrior) via /workspace/mcp.json
```

### System Context
```
[Contributor Workstation]
      ↓ (VS Code Dev Containers)
[DevContainer Template] → [Claude CLI, HashiCorp, Cloud CLIs]
      ↓                                     ↓
 [GitHub/Codacy APIs] ← MCP servers → [Taskwarrior CLI]
```

### Key Components
- **`.devcontainer/devcontainer.json`** – Declares the docker-compose service, features, VS Code settings, and lifecycle commands that bootstrap the container.
- **Lifecycle hooks (`hooks/lifecycle/*.sh`)** – Harden environment setup (safe directories, alias injection, Claude restore, MCP template generation, keyring bootstrap).
- **Custom devcontainer features** – Modular installers for languages (`features/languages/*`) and Claude-specific assets (`features/claude`).
- **Base image (`images/Dockerfile`)** – Builds the GHCR image with Ubuntu 24.04, shell tooling, Claude CLI, CodeRabbit CLI, and CLIs for AWS/GCP/Azure/Kubernetes/HashiCorp.
- **Automation configs (`.qodo-merge.toml`, `.codacy.yaml`, `.coderabbit.yaml`)** – Enforce review severity, compliance, and lint exclusions across downstream repos.

### Data Flow
1. Developer opens the project in VS Code → Dev Containers uses `devcontainer.json` and `docker-compose.yml` to build and run the `devcontainer` service.
2. `onCreate.sh` and `postCreate.sh` provision safe caches, environment shims, and developer aliases (e.g., `super-claude`).
3. `postStart.sh` restores Claude defaults, injects secrets into `/workspace/mcp.json`, and configures keyrings/npm caches before starting background tasks.
4. MCP-aware tools (`super-claude`, Codacy, Taskwarrior) run inside the container, using generated tokens and compliance configs to talk to GitHub/Codacy APIs.

---

## 📁 Project Structure [Partial Directory Tree]

```
workspace/
├── .devcontainer/            # Dev Container definition, hooks, features, base image
│   ├── devcontainer.json     # Main entry point for VS Code
│   ├── docker-compose.yml    # Single service + named volumes
│   ├── hooks/                # Lifecycle + shared utilities
│   ├── features/             # Custom language/tool installers
│   └── images/               # GHCR-ready Docker build context
├── .github/                  # Workflow and reviewer instructions
│   ├── workflows/            # e.g., docker-images.yml
│   └── instructions/         # Codacy MCP guidance
├── CLAUDE.md                 # Mandatory repository/branch/product rules
├── README.md                 # High-level template overview
├── .qodo-merge.toml          # Qodo Merge reviewer configuration
├── .codacy.yaml              # Codacy path exclusions
└── .coderabbit.yaml          # CodeRabbit reviewer profile
```

### Key Files to Know

| File | Purpose | When You'd Touch It |
|------|---------|---------------------|
| `.devcontainer/devcontainer.json` | Declares features, lifecycle commands, VS Code settings | Add/remove languages, tweak hooks, change workspace folder |
| `.devcontainer/docker-compose.yml` | Defines the `devcontainer` service, mounts, volumes, env vars | Adjust persistent volumes, ports, or environment defaults |
| `.devcontainer/hooks/lifecycle/onCreate.sh` | First-time container bootstrap (cache dirs, CLAUDE.md injection) | Extend setup tasks that run once per container creation |
| `.devcontainer/hooks/lifecycle/postCreate.sh` | User-scoped env wiring (NVM, pyenv, aliases) | Add language managers or shell configuration exports |
| `.devcontainer/hooks/lifecycle/postStart.sh` | Per-start routines (Claude restore, keyring, MCP template, secret fetch) | Modify recurring startup behavior or token sourcing |
| `.devcontainer/hooks/shared/utils.sh` | Logging + retry helpers for all hooks | Reuse logging/polling helpers inside new scripts |
| `.devcontainer/images/Dockerfile` | Base GHCR image with core tooling and CLIs | Upgrade OS/tool versions or add baked-in binaries |
| `.github/workflows/docker-images.yml` | Builds/pushes the base image for amd64/arm64 via Buildx | Adjust build triggers, pin action SHAs, or add platforms |
| `.qodo-merge.toml` | Configures Qodo Merge reviewer severity, MCP compliance, PR automation | Update review policies, RAG settings, or compliance toggles |
| `CLAUDE.md` | Source layout, branch policy, MCP-first rules | Communicate repo-wide expectations inherited by downstream projects |

---

## 🔧 Technology Stack

### Core Technologies
- **Container base:** `mcr.microsoft.com/devcontainers/base:ubuntu-24.04` extended in `.devcontainer/images/Dockerfile` for a reproducible Ubuntu environment.
- **Tooling layer:** HashiCorp suite (Terraform, Vault, Consul, Nomad, Packer), AWS CLI v2, Google Cloud SDK, Azure CLI, Kubernetes (kubectl v1.35.0, Helm v4.0.4), Ansible, Bazelisk, Claude CLI, and CodeRabbit CLI are preinstalled globally.
- **Orchestration:** VS Code Dev Containers + Docker Compose single-service stack defined in `.devcontainer/docker-compose.yml`.
- **Language expansion:** Custom features under `.devcontainer/features/languages/` install Node.js (via NVM), Python (via pyenv), Go, Rust, Carbon, etc., on demand with pinned versions.

### Key Libraries & Utilities
- **Lifecycle helpers (`hooks/shared/utils.sh`)** – Provide retry/backoff, apt locking mitigation, download helpers, and logging wrappers for consistent scripting.
- **MCP servers (`images/mcp.json.tpl`)** – Template for GitHub, Codacy, and Taskwarrior servers executed through `npx` inside the container with secrets injected post-start.
- **Status-line & ktn-linter binaries** – Installed into `~/.local/bin` for interactive feedback and linting within the container.

### Development Tools
- **super-claude alias** – Created in `postCreate.sh` to run the Claude CLI with `/workspace/mcp.json` automatically when available.
- **Keyring bootstrap** – `postStart.sh` ensures `gnome-keyring-daemon` and D-Bus sockets exist so CLI tools can store credentials securely.
- **Named volumes** – `docker-compose.yml` keeps caches (`package-cache`, `npm-global`, `.claude`, `.config/op`) across rebuilds to accelerate repeated work.

---

## 🌐 External Dependencies

### Required Services
- **GitHub MCP server** (`@modelcontextprotocol/server-github`) – Provides repository metadata and PR automation; tokens are sourced via env vars or 1Password (see `postStart.sh`).
- **Codacy MCP server** (`@codacy/codacy-mcp`) – Runs security/lint analysis whenever files change; tokens are injected from `CODACY_API_TOKEN` or 1Password vault `mcp-codacy`.
- **Taskwarrior MCP server** (`mcp-server-taskwarrior`) – Integrates planning `/plan` phases with Taskwarrior tasks, ensuring `/apply` only runs against WIP tasks.

### Optional Integrations
- **Rust Analyzer MCP** – `postStart.sh` adds it if `rust-analyzer-mcp` exists in the cargo cache when the Rust feature is enabled.
- **Additional MCP servers** – Template scaffolding inside `postStart.sh` allows adding more servers by calling `add_optional_mcp` once binaries are available.

---

### Environment Variables

```bash
# Core paths set by docker-compose.yml
HOME=/home/vscode
NVM_DIR=/usr/local/share/nvm
npm_config_cache=/home/vscode/.cache/npm
CLOUDSDK_CONFIG=/home/vscode/.config/gcloud
CLAUDE_CONFIG_DIR=/home/vscode/.claude
OP_CONFIG_DIR=/home/vscode/.config/op
PATH includes ~/.local/share/npm-global/bin, ~/.local/bin, language managers, and system bins
```

These ensure every major package manager (npm, pnpm, pip, poetry, Go, Cargo, Composer, Terraform, etc.) writes caches to named volumes rather than the container filesystem.

---

## 🔄 Common Workflows

### Spin up or refresh the development environment
1. Open the folder in VS Code and run **Dev Containers: Rebuild Container** (per README) to rebuild `.devcontainer/images/Dockerfile` and apply features.
2. `onCreate.sh` provisions cache directories and injects `CLAUDE.md` if missing; `postCreate.sh` wires language managers and the `super-claude` alias.
3. `postStart.sh` restores Claude command packs, configures gnome-keyring, fixes npm/1Password permissions, regenerates `mcp.json`, and schedules `/init` to validate template drift.

**Code path:** `.devcontainer/devcontainer.json` → `hooks/lifecycle/*.sh` → `.devcontainer/images/mcp.json.tpl`

### Generate project-scoped MCP credentials
1. Provide `CODACY_API_TOKEN`, `GITHUB_API_TOKEN`, and (optionally) `CODERABBIT_API_KEY` via `.devcontainer/.env` or 1Password service account env vars referenced in `postStart.sh`.
2. On container start, the hook pulls secrets from env vars or the vault (`get_1password_field`), renders `/workspace/mcp.json`, and appends dynamic exports to `~/.devcontainer-env.sh`.
3. Run `super-claude /review --all` or Codacy MCP tools; they automatically use the regenerated JSON without manual auth.

**Code path:** `.devcontainer/hooks/lifecycle/postStart.sh` → `/etc/mcp/mcp.json.tpl` → `/workspace/mcp.json`

---

## 📈 Performance & Scale

### Performance Considerations
- Extensive caching: docker-compose volumes (`package-cache`, `npm-global`, `.claude`, `.config/op`) prevent reinstalling large toolchains, while hooks fix ownership/permissions on each start so caches remain usable.
- Buildx multi-arch workflow (`.github/workflows/docker-images.yml`) compiles the base image separately for amd64 and arm64, then merges manifests to keep pull times low for both architectures.

### Monitoring / Diagnostics
- `postStart.sh` logs into `~/.devcontainer-env.sh` and `~/.devcontainer-init.log`, giving a persistent trace of hook outcomes and `/init` health checks for debugging.

---

## 🚨 Things to Be Careful About

### 🔒 Security Considerations
- Hooks scrub git credential helpers and ensure `git config --global safe.directory /workspace` to avoid dubious ownership errors.
- Secrets flow only via env vars, 1Password CLI, or `mcp.json`; scripts explicitly avoid logging token values and remove duplicates before appending to `~/.devcontainer-env.sh`.
- Codacy instructions (`.github/instructions/codacy.instructions.md`) require running `codacy_cli_analyze` after every edit; integrate that tool into your workflow to maintain supply-chain checks.

*Last updated: 2025-01-05*
