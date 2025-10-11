# Go Development Plugin

Comprehensive Go development plugin with ultra-strict DDD architecture enforcer, hyper-strict code reviewer, performance optimizer, and Go 1.25+ expert.

## Features

### 🤖 Expert Agents

- **Go Expert** - Expert on latest Go 1.25+ features (iterators, unique package, slog, etc.)
- **DDD Architect** - Ultra-strict DDD structure enforcer with 100% coverage requirement
- **Code Reviewer** - Uncompromising quality standards with zero tolerance for substandard code
- **Performance Optimizer** - pprof master for data-driven performance optimization

### 📋 Commands

- `/review` - Hyper-strict code review with comprehensive quality checks

### 🔧 Hooks

- **Auto-format** - Automatic `gofmt` before writing Go files
- **Auto-imports** - Automatic `goimports` after writing Go files
- **Smart suggestions** - Context-aware command suggestions

## Installation

### Via Marketplace

In Claude Code:
1. Open command palette
2. Select "Add Marketplace"
3. Enter: `kodflow/.repository`
4. Install the `go-development-tools` plugin

### Manual Installation

```bash
# Create plugins directory
mkdir -p ~/.claude/plugins

# Clone or link the plugin
ln -s /path/to/.repository/plugins/golang ~/.claude/plugins/golang

# Restart Claude Code
```

## MCP Integrations

This plugin integrates with GitHub and Codacy MCP servers for enhanced functionality.

### Required Environment Variables

Create or update your `.env` file:

```bash
# GitHub Integration
GITHUB_TOKEN=ghp_your_github_token_here

# Codacy Integration
CODACY_API_TOKEN=your_codacy_api_token_here
```

### Getting API Tokens

**GitHub Token:**
1. Go to https://github.com/settings/tokens
2. Generate new token (classic)
3. Required scopes: `repo`, `read:org`, `workflow`

**Codacy API Token:**
1. Go to https://app.codacy.com/account/apiTokens
2. Generate new API token
3. Copy the token

### MCP Server Configuration

The plugin automatically configures these MCP servers:

- **GitHub MCP** - Repository operations, issues, PRs, code review
- **Codacy MCP** - Code quality analysis, security scanning, coverage reports

## Usage Examples

### Code Review

```bash
# Review specific file
/review src/user/user.go

# Review all changes
/review

# Full codebase review
/review --full
```

### Using Agents

The agents are automatically invoked in relevant contexts:

- **DDD Architect** - When working with domain model files
- **Code Reviewer** - When reviewing code or discussing quality
- **Performance Optimizer** - When discussing performance or profiling
- **Go Expert** - For Go-specific questions and best practices

### Integration with GitHub

With GitHub MCP connected, you can:

- Create and manage issues
- Create and review pull requests
- Push commits
- Manage branches
- Search code across repositories

### Integration with Codacy

With Codacy MCP connected, you can:

- Get real-time code quality metrics
- List and fix security issues
- Track test coverage
- Analyze code complexity
- Get repository quality dashboard

## Standards Enforced

### DDD Structure (Ultra-Strict)

```
mypackage/
├── interfaces.go        # ALL package interfaces (mandatory)
├── interfaces_test.go   # ALL mocks (mandatory)
├── config.go           # ALL constructors (mandatory)
├── user.go             # One struct = one file
├── user_test.go        # One file = one test file
└── order.go
    order_test.go
```

**Requirements:**
- ONE struct = ONE file
- ONE file = ONE test file
- 100% test coverage (mandatory)
- Race tests for ALL files
- Memory/CPU/disk optimization

### Code Quality

- Zero ignored errors
- 85% minimum test coverage (target 100%)
- golangci-lint compliance (zero warnings)
- Codacy A-grade
- No code duplication (max 3%)
- Max complexity 10 per function

### Performance

- Zero allocations in hot paths
- Pre-allocated slices
- Optimized struct memory layout
- pprof-driven optimization
- Benchmark requirements

## Configuration

### Makefile Integration

This plugin expects tools to be managed via Makefile:

```makefile
# Example Makefile targets
.PHONY: test lint build

test:
	go test -race -cover -coverprofile=coverage.out ./...

lint:
	golangci-lint run --fix

build:
	go build -o bin/app ./cmd/app
```

## License

MIT

## Author

Kodflow - contact@making.codes
