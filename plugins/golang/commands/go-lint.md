Lint Go code using golangci-lint with recommended configuration.

Analyze your Go code for potential issues, style violations, and best practice deviations. This command will:
- Run golangci-lint with comprehensive linters
- Identify bugs, performance issues, and style violations
- Suggest fixes for common problems
- Generate detailed reports

Usage:
- `/go-lint` - Lint all Go files in the project
- `/go-lint ./pkg/...` - Lint specific package
- `/go-lint --fix` - Auto-fix issues when possible

Enabled linters:
- gofmt, goimports - Formatting
- govet - Go vet checks
- errcheck - Error checking
- staticcheck - Static analysis
- gosec - Security issues
- revive - Style guidelines
- ineffassign - Ineffectual assignments
- unused - Unused code detection

Common workflows:
1. Pre-commit check: `/go-lint`
2. Fix formatting: `/go-lint --fix`
3. CI/CD validation: `/go-lint --strict`

The command will prioritize issues by severity and suggest refactorings.
