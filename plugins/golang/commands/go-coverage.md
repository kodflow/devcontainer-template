Generate and analyze test coverage reports.

Create comprehensive test coverage reports to identify untested code paths. This command will:
- Run tests with coverage tracking
- Generate HTML coverage reports
- Identify uncovered code
- Set coverage thresholds

Usage:
- `/go-coverage` - Generate coverage report
- `/go-coverage -html` - Open HTML report in browser
- `/go-coverage -threshold 80` - Enforce minimum coverage
- `/go-coverage -func` - Show coverage by function

Coverage metrics:
- Statement coverage percentage
- Function coverage
- Branch coverage
- Package-level coverage

Common workflows:
1. Check coverage: `/go-coverage`
2. Visual report: `/go-coverage -html`
3. CI/CD gate: `/go-coverage -threshold 85`
4. Package analysis: `/go-coverage -pkg ./internal/...`

The command will highlight areas needing more tests and suggest test cases.
