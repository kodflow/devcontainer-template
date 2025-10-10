Run Go tests with coverage and detailed output.

Execute the Go test suite for the current project or a specific package. This command will:
- Run all tests in the current directory and subdirectories
- Generate coverage reports
- Display detailed test results
- Identify failing tests with helpful error messages

Usage:
- `/go-test` - Run all tests in the current project
- `/go-test ./pkg/...` - Run tests for a specific package path
- `/go-test -v` - Run tests with verbose output
- `/go-test -race` - Run tests with race detector

Common workflows:
1. Run all tests: `/go-test`
2. Check specific package: `/go-test ./internal/service`
3. Generate coverage: `/go-test -cover`
4. Run with race detection: `/go-test -race`

The command will analyze test failures and suggest fixes when possible.
