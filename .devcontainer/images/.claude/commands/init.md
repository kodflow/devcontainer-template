---
name: init
description: |
  Project initialization check and setup verification.
  Validates environment, dependencies, and configuration.
  Use when: starting work on a project, verifying setup,
  or troubleshooting environment issues.
allowed-tools:
  - "Bash(git:*)"
  - "Bash(docker:*)"
  - "Bash(terraform:*)"
  - "Bash(kubectl:*)"
  - "Bash(node:*)"
  - "Bash(python:*)"
  - "Bash(go:*)"
  - "Read(**/*)"
  - "Glob(**/*)"
  - "Grep(**/*)"
  - "mcp__github__*"
  - "mcp__codacy__*"
---

# Init - Project Initialization Check

## Overview

Comprehensive project setup verification:

- **Detect** project type and requirements
- **Verify** tools and dependencies
- **Check** configuration files
- **Validate** environment variables

## Usage

```
/init                      # Full initialization check
/init --tools              # Check tools only
/init --deps               # Check dependencies only
/init --env                # Check environment only
/init --fix                # Attempt auto-fix issues
```

## Workflow

```yaml
init_workflow:
  1_detect:
    action: "Detect project type"
    checks:
      - "package.json → Node.js"
      - "requirements.txt → Python"
      - "go.mod → Go"
      - "*.tf → Terraform"
      - "Dockerfile → Container"
      - "*.yaml (k8s) → Kubernetes"

  2_tools:
    action: "Verify required tools"
    parallel:
      - "git --version"
      - "docker --version"
      - "terraform --version"
      - "kubectl version --client"

  3_deps:
    action: "Check dependencies"
    per_type:
      nodejs: "npm ci"
      python: "pip install -r requirements.txt"
      go: "go mod download"
      terraform: "terraform init"

  4_config:
    action: "Validate configuration"
    checks:
      - ".env file exists (if .env.example)"
      - "Required env vars set"
      - "Config files valid"

  5_report:
    action: "Generate status report"
    format: "Markdown with fixes"
```

## Output Format

```markdown
# Project Init: {project_name}

## Project Detection
| Type | Detected |
|------|----------|
| Language | Node.js 20.x |
| Framework | Express |
| IaC | Terraform |
| Container | Docker |

## Tools Status
| Tool | Required | Installed | Status |
|------|----------|-----------|--------|
| git | 2.40+ | 2.42.0 | PASS |
| node | 20.x | 20.10.0 | PASS |
| terraform | 1.6+ | 1.7.0 | PASS |
| docker | 24+ | 24.0.7 | PASS |

## Dependencies
| Manager | Status | Issues |
|---------|--------|--------|
| npm | PASS | 0 vulnerabilities |
| terraform | PASS | Initialized |

## Configuration
| File | Status | Issue |
|------|--------|-------|
| .env | MISSING | Copy from .env.example |
| .gitignore | PASS | - |
| CLAUDE.md | PASS | - |

## Environment Variables
| Variable | Status | Source |
|----------|--------|--------|
| DATABASE_URL | SET | .env |
| API_KEY | MISSING | Required |

## Recommended Actions
1. `cp .env.example .env` - Create env file
2. Set `API_KEY` environment variable
3. Run `npm audit fix` - Fix 2 vulnerabilities

## Quick Start
```bash
cp .env.example .env
# Edit .env with your values
npm install
npm run dev
```
```

## Detection Patterns

```yaml
project_types:
  nodejs:
    files: ["package.json", "node_modules/"]
    tools: ["node", "npm"]

  python:
    files: ["requirements.txt", "pyproject.toml", "setup.py"]
    tools: ["python", "pip"]

  go:
    files: ["go.mod", "go.sum"]
    tools: ["go"]

  terraform:
    files: ["*.tf", ".terraform/"]
    tools: ["terraform", "tflint"]

  kubernetes:
    files: ["**/deployment.yaml", "**/service.yaml", "helm/"]
    tools: ["kubectl", "helm"]

  docker:
    files: ["Dockerfile", "docker-compose.yml"]
    tools: ["docker"]
```

## Tool Version Checks

```bash
# Git
git --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'

# Node.js
node --version | tr -d 'v'

# Python
python3 --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'

# Go
go version | grep -oE 'go[0-9]+\.[0-9]+' | tr -d 'go'

# Terraform
terraform version -json | jq -r '.terraform_version'

# Docker
docker version --format '{{.Server.Version}}'

# Kubectl
kubectl version --client -o json | jq -r '.clientVersion.gitVersion' | tr -d 'v'
```

## Environment Check

```bash
# Check .env exists
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
  echo "WARNING: .env missing, copy from .env.example"
fi

# Validate required vars
for var in DATABASE_URL API_KEY; do
  if [ -z "${!var}" ]; then
    echo "MISSING: $var"
  fi
done
```

## Auto-Fix Actions

```yaml
auto_fix:
  missing_env:
    action: "cp .env.example .env"
    message: "Created .env from template"

  npm_audit:
    action: "npm audit fix"
    message: "Fixed npm vulnerabilities"

  terraform_init:
    action: "terraform init -upgrade"
    message: "Initialized Terraform"

  docker_pull:
    action: "docker compose pull"
    message: "Pulled latest images"
```
