Perform a hyper-strict code review on Go code using the Code Reviewer agent.

This command triggers the **UNCOMPROMISING** Go code reviewer with ZERO TOLERANCE for substandard code. The reviewer enforces absolute standards and provides direct, assertive feedback.

## What Gets Reviewed

**Code Quality (100% Required):**

- Error handling (ZERO ignored errors tolerated)
- Test coverage (minimum 85%, target 100%)
- golangci-lint compliance (ZERO warnings)
- Codacy grade (A-grade required)
- Code complexity (max 10 per function)
- Code duplication (max 3%)

**Architecture & Design:**

- SOLID principles compliance
- Proper separation of concerns
- Dependency injection
- Interface segregation
- DDD structure (if applicable)

**Performance & Safety:**

- Concurrency safety (race detector must pass)
- Memory optimization (pre-allocated slices, proper struct layout)
- CPU optimization (no allocations in hot paths)
- Resource management (proper cleanup with defer)

**Security:**

- No SQL injection vulnerabilities
- No command injection
- Proper input validation
- Secrets not in code
- gosec compliance

## Usage

- `/review` - Review all changed files in current branch
- `/review <file_path>` - Review specific file
- `/review --full` - Full codebase review

## Review Process

1. **Automated Checks** (must pass first):
   - golangci-lint run
   - go test -race -cover
   - Codacy analysis

2. **Manual Review**:
   - Code quality and idioms
   - Architecture patterns
   - Performance issues
   - Security vulnerabilities

3. **Verdict**:
   - ✅ APPROVED - Ready for production
   - ❌ REJECTED - Critical issues must be fixed
   - ⚠️ CHANGES REQUESTED - Improvements needed

## Example Output

```markdown
## Code Review: user.go

### ❌ CRITICAL ISSUES (Must Fix Before Re-review)

1. **Line 45: Ignored Error**
   - WHAT: `file, _ := os.Open()`
   - WHY: Error handling is MANDATORY
   - FIX: Handle error and wrap with context

2. **Coverage: 60%**
   - WHAT: Insufficient test coverage
   - REQUIREMENT: Minimum 85%
   - FIX: Add comprehensive tests

### VERDICT: **REJECTED**

Re-submit after addressing ALL critical issues.
```

## Standards Enforced

**The reviewer DEMANDS:**

- Production-ready code on FIRST submission
- Complete test coverage with edge cases
- Clean golangci-lint and Codacy reports
- Idiomatic, maintainable, performant code

**NO COMPROMISES. NO MERCY. EXCELLENCE IS THE ONLY STANDARD.**
