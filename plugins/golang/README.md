# Golang Plugin for Claude Code

A comprehensive Go development plugin for Claude Code that enhances your Go programming workflow with specialized commands, expert agents, and intelligent automation.

## Features

### Slash Commands

- `/go-test` - Run tests with coverage and detailed output
- `/go-build` - Build with optimizations and cross-compilation support
- `/go-lint` - Lint code using golangci-lint
- `/go-mod` - Manage Go modules and dependencies
- `/go-benchmark` - Run benchmarks and analyze performance
- `/go-coverage` - Generate and analyze test coverage reports

### Specialized Agents

- **Go Expert** - Deep Go programming expertise with best practices
- **Performance Optimizer** - Identify and fix performance bottlenecks
- **Code Reviewer** - Thorough code reviews with constructive feedback

### Automation Hooks

- Auto-format Go files on save
- Organize imports automatically
- Smart test command suggestions
- Session initialization with quick reference

## Installation

### From Marketplace

```bash
/plugin install kodflow/golang
```

### From Local Path

```bash
/plugin install /workspace/plugins/golang
```

### From Git Repository

```bash
/plugin install https://github.com/kodflow/.repository/tree/main/plugins/golang
```

## Usage

### Running Tests

```bash
# Run all tests
/go-test

# Run tests for specific package
/go-test ./pkg/...

# Run with verbose output
/go-test -v

# Run with race detector
/go-test -race
```

### Building Projects

```bash
# Build for current platform
/go-build

# Cross-compile for Linux
/go-build linux/amd64

# Production build
/go-build -prod
```

### Code Quality

```bash
# Lint all code
/go-lint

# Auto-fix issues
/go-lint --fix

# Strict mode for CI/CD
/go-lint --strict
```

### Dependency Management

```bash
# Clean up dependencies
/go-mod tidy

# Update all dependencies
/go-mod update

# Verify dependencies
/go-mod verify

# Vendor dependencies
/go-mod vendor
```

### Performance Analysis

```bash
# Run benchmarks
/go-benchmark

# Include memory stats
/go-benchmark -mem

# Generate CPU profile
/go-benchmark -cpuprofile
```

### Coverage Reports

```bash
# Generate coverage report
/go-coverage

# Open HTML report
/go-coverage -html

# Enforce minimum coverage
/go-coverage -threshold 80
```

## Agents

### Using the Go Expert Agent

The Go Expert agent provides deep Go programming knowledge:

```
@go-expert how should I structure a REST API server?
@go-expert review this goroutine implementation
@go-expert what's the best way to handle errors here?
```

### Using the Performance Optimizer

Get performance insights and optimizations:

```
@performance-optimizer analyze this function's allocations
@performance-optimizer why is this code slow?
@performance-optimizer suggest optimizations for this hot path
```

### Using the Code Reviewer

Get thorough code reviews:

```
@code-reviewer review this PR
@code-reviewer check for race conditions
@code-reviewer is this code idiomatic?
```

## Hooks

The plugin automatically:

- Formats Go files with `gofmt` before writing
- Organizes imports with `goimports` after saving
- Suggests test commands when you mention testing
- Shows available commands when starting a session

## Configuration

### Customizing Hooks

Edit `hooks/hooks.json` to customize automation behavior.

### Linter Configuration

The plugin uses `golangci-lint` with recommended linters. Create a `.golangci.yml` in your project root to customize:

```yaml
linters:
  enable:
    - gofmt
    - goimports
    - govet
    - errcheck
    - staticcheck
    - gosec
    - revive
```

## Requirements

- Go 1.21 or later
- `golangci-lint` for linting
- `gofmt` and `goimports` (included with Go)

## Examples

### Complete Workflow

```bash
# 1. Check code quality
/go-lint

# 2. Run tests with coverage
/go-test -cover

# 3. Build for production
/go-build -prod

# 4. Review with agent
@code-reviewer review the changes
```

### Performance Optimization Workflow

```bash
# 1. Run benchmarks baseline
/go-benchmark > old.txt

# 2. Make optimizations
@performance-optimizer suggest improvements

# 3. Run benchmarks again
/go-benchmark > new.txt

# 4. Compare results
/go-benchmark -compare old.txt new.txt
```

## Best Practices

1. **Always test first**: Use `/go-test` before building
2. **Lint regularly**: Run `/go-lint` before committing
3. **Keep dependencies clean**: Run `/go-mod tidy` frequently
4. **Profile before optimizing**: Use `/go-benchmark` to identify bottlenecks
5. **Maintain coverage**: Use `/go-coverage` to track test coverage

## Troubleshooting

### Commands not found

Make sure the plugin is installed:

```bash
/plugin list
```

### Hooks not working

Check hook configuration in `hooks/hooks.json` and ensure required tools are installed.

### Agent not responding

Verify agent files exist in the `agents/` directory.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

- GitHub Issues: <https://github.com/kodflow/.repository/issues>
- Documentation: <https://docs.claude.com/en/docs/claude-code/plugins>

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.
