Manage Go modules and dependencies efficiently.

Maintain your Go module dependencies, ensuring they are up-to-date and properly organized. This command will:
- Run `go mod tidy` to clean up dependencies
- Update outdated modules
- Verify module integrity
- Vendor dependencies when needed

Usage:
- `/go-mod tidy` - Clean up go.mod and go.sum
- `/go-mod update` - Update all dependencies
- `/go-mod verify` - Verify dependencies
- `/go-mod vendor` - Vendor dependencies
- `/go-mod graph` - Show dependency graph

Common workflows:
1. After adding imports: `/go-mod tidy`
2. Update dependencies: `/go-mod update`
3. Before deployment: `/go-mod verify`
4. For offline builds: `/go-mod vendor`

Module management tasks:
- Remove unused dependencies
- Upgrade to latest versions
- Downgrade problematic versions
- Identify indirect dependencies

The command will suggest dependency updates and identify security vulnerabilities.
