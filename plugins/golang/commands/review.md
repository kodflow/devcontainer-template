# /review - Professional Go code review

Reviews Go code for production readiness, focusing on correctness, maintainability, and performance.

Checks code structure, error handling, testing, and Go best practices. Provides clear feedback on what needs fixing and why.

## COMPREHENSIVE GO BEST PRACTICES CHECKLIST

### 1. ERROR HANDLING (Required)

- [ ] Never ignore errors with `_` blank identifier
- [ ] Always check and handle ALL error return values
- [ ] Wrap errors with context using `fmt.Errorf("%w", err)` or `errors.Wrap()`
- [ ] Return errors instead of panicking (except in init() or unrecoverable situations)
- [ ] Use custom error types for sentinel errors: `var ErrNotFound = errors.New("not found")`
- [ ] Use `errors.Is()` and `errors.As()` for error checking, not `==`
- [ ] Errors should be lowercase and not end with punctuation
- [ ] Prefix error messages with context: `fmt.Errorf("failed to open file %s: %w", path, err)`
- [ ] Use `defer` with error checking for cleanup operations
- [ ] Never use `panic()` for expected errors or user input validation
- [ ] Check errors from `Close()`, `Flush()`, `Write()` operations
- [ ] Return early on errors to avoid deep nesting

### 2. NAMING CONVENTIONS (Target COMPLIANCE)

#### 2.1 Basic Naming Rules

- [ ] Package names: lowercase, single-word, no underscores (e.g., `httputil`, not `http_util`)
- [ ] Exported names: UpperCamelCase (e.g., `UserRepository`)
- [ ] Unexported names: lowerCamelCase (e.g., `userCache`)
- [ ] Interface names: end with `-er` suffix when possible (e.g., `Reader`, `Writer`, `Formatter`)
- [ ] Avoid stutter: prefer `user.Repository` over `user.UserRepository`
- [ ] Acronyms: all uppercase (e.g., `HTTPServer`, `URLParser`, `IDGenerator`)
- [ ] Receiver names: 1-2 character abbreviation of type (e.g., `u *User`, not `this` or `self`)
- [ ] Use consistent receiver names across all methods of same type
- [ ] Boolean variables: use `is`, `has`, `can`, `should` prefix (e.g., `isValid`, `hasPermission`)
- [ ] Avoid generic names: prefer `userCount` over `count`, `userList` over `list`
- [ ] Constants: MixedCaps or ALL_CAPS for exported constants
- [ ] Test functions: `TestFunctionName_scenario` pattern

#### 2.2 Package & File Naming Consistency (REQUIRED)

**ANTI-PATTERNS TO FLAG AND FIX:**

- [ ] **NO `Impl` suffix** - `PropertyServiceImpl` → `Service` (package already says "property")
- [ ] **NO `Implementation` suffix** - `UserRepositoryImplementation` → `Repository`
- [ ] **NO `Manager` generic suffix** - `DataManager` → be specific: `DataStore`, `DataCache`, `DataValidator`
- [ ] **NO `Helper` suffix** - `StringHelper` → use specific names: `StringFormatter`, `StringValidator`
- [ ] **NO `Utils` or `Utilities`** - Create focused packages: `validation`, `formatting`, `conversion`
- [ ] **NO redundant prefixes** - In package `user`: `UserService` → `Service`, `UserRepository` → `Repository`

**FILE NAMING RULES:**

```go
// ❌ WRONG - Suffixes and redundant names
internal/domain/services/
├── property_service_impl.go     // Bad: Impl suffix
├── user_service_implementation.go // Bad: Implementation suffix
├── order_manager.go              // Bad: Generic Manager
└── helper_utils.go               // Bad: Helper + Utils

// ✅ CORRECT - Clean, package-contextual names
internal/domain/property/
├── service.go           // Package says "property", file says "service"
├── repository.go        // Clean, no redundancy
├── validator.go         // Specific purpose
└── statistics.go        // What it does, not "helper"

internal/domain/user/
├── service.go
├── repository.go
└── authenticator.go     // Specific, not "Manager"
```

**STRUCT NAMING IN CONTEXT:**

```go
// ❌ WRONG - Verbose and redundant
package services

type PropertyServiceImpl struct { }          // Bad: Impl suffix
func NewPropertyServiceImpl() { }            // Bad: Verbose

type UserServiceImplementation struct { }    // Bad: Implementation
type OrderManagerService struct { }          // Bad: Redundant

// ✅ CORRECT - Package provides context
package property

type Service struct { }      // Clean: property.Service
func NewService() { }        // Clean: property.NewService()

type Repository struct { }   // Clean: property.Repository

// ✅ ALSO CORRECT - If you must keep "services" package
package services

type PropertyService struct { }   // OK: services.PropertyService (no Impl!)
func NewPropertyService() { }     // OK: Clear, no suffix

type UserService struct { }       // OK: Not "UserServiceImpl"
```

**WHEN TO SUGGEST RENAMING:**

During review, if you find these patterns, **SUGGEST RENAMING**:

1. **File with `*_impl.go` suffix**:
   ```
   ❌ Found: property_service_impl.go
   ✅ Suggest:
      Option 1: Rename to service.go in property/ package
      Option 2: Rename to property.go in services/ package (remove _impl)
   ```

2. **Struct with `Impl` or `Implementation` suffix**:
   ```
   ❌ Found: type PropertyServiceImpl struct
   ✅ Suggest:
      Option 1: type Service struct (in property package)
      Option 2: type PropertyService struct (remove Impl suffix)
   ```

3. **Generic `Manager`, `Helper`, `Utils` names**:
   ```
   ❌ Found: type DataManager struct
   ✅ Suggest: Be specific about what it manages:
      - DataStore (if it stores data)
      - DataCache (if it caches data)
      - DataValidator (if it validates data)
      - DataTransformer (if it transforms data)
   ```

4. **Redundant package/type names**:
   ```
   ❌ Found: package user with type UserService
   ✅ Suggest: type Service struct (package already says "user")

   ❌ Found: package services with type ServiceManager
   ✅ Suggest: type Manager struct OR better: specific name
   ```

**NAMING CONSISTENCY CHECKLIST:**

- [ ] No `Impl` or `Implementation` suffixes anywhere
- [ ] No `Manager`, `Helper`, `Utils` unless truly necessary
- [ ] File names match struct names (lowercase): `service.go` → `type Service`
- [ ] Package name provides context, type name stays concise
- [ ] Related files in same package: `service.go`, `repository.go`, `validator.go`
- [ ] No stutter: avoid `user.UserService`, prefer `user.Service`

**EXAMPLE REFACTORING SUGGESTIONS:**

```markdown
## Naming Issues Found

### File: internal/domain/services/property_service_impl.go

❌ **Issue**: File and struct use anti-pattern suffix `Impl`

**Current**:
- File: `property_service_impl.go`
- Struct: `PropertyServiceImpl`
- Constructor: `NewPropertyServiceImpl(cfg PropertyServiceImplConfig)`

**Suggested Refactoring** (Option 1 - BEST):
1. Create package: `internal/domain/property/`
2. Rename file: `service.go`
3. Rename struct: `Service`
4. Rename config: `Config`
5. Update constructor: `NewService(cfg Config) *Service`

**Result**:
```go
// internal/domain/property/service.go
package property

type Service struct { ... }
type Config struct { ... }
func NewService(cfg Config) *Service { ... }

// Usage:
import "yourapp/internal/domain/property"
svc := property.NewService(property.Config{...})
```

**Suggested Refactoring** (Option 2 - If keeping services/ package):
1. Keep in `internal/domain/services/`
2. Rename file: `property.go`
3. Rename struct: `PropertyService` (remove Impl)
4. Rename config: `PropertyConfig`
5. Update constructor: `NewPropertyService(cfg PropertyConfig)`

**Rationale**:
- Go convention: No `Impl` suffixes (this is Java/C# pattern)
- Cleaner imports: `property.Service` vs `services.PropertyServiceImpl`
- Shorter code: `NewService()` vs `NewPropertyServiceImpl()`
- More idiomatic Go
```

### 3. CODE ORGANIZATION & STRUCTURE

- [ ] **Required**: Every `.go` file should have Package Descriptor above `package` declaration
- [ ] **Required**: Package Descriptor must include: Purpose, Responsibilities, Features
- [ ] **Target**: Functions should be < 35 lines of code ()
- [ ] **Target**: Cyclomatic complexity should be < 10 (use `gocyclo -over 9 .`)
- [ ] Max 3 levels of indentation (use early returns)
- [ ] One clear responsibility per function (Single Responsibility Principle)
- [ ] **Required FILE STRUCTURE**:
  - **Key**: ONE FILE PER STRUCT (e.g., `user.go` for User, `user_config.go` for UserConfig)
  - `constants.go` contains ALL package constants
  - `errors.go` contains ALL package errors
  - One `interfaces.go` file per package containing ALL interfaces
  - One `interfaces_test.go` for ALL mock helpers and test utilities
  - Every `xxx.go` file should have corresponding `xxx_test.go` in same package
  - NO `*_helper.go` files outside of tests (helpers are for tests only)
  - NO mixing of interfaces and implementations in same file
  - NO `models.go` with multiple structs - split into separate files
- [ ] Example package structure:
  ```
  package/
  ├── constants.go          # ALL constants
  ├── errors.go             # ALL errors
  ├── interfaces.go         # ALL interfaces
  ├── interfaces_test.go    # ALL mocks
  ├── user.go              # User struct + methods
  ├── user_test.go         # User tests
  ├── user_config.go       # UserConfig struct
  ├── order.go             # Order struct + methods
  ├── order_test.go        # Order tests
  └── order_status.go      # OrderStatus type
  ```
- [ ] Place interfaces in consumer package, not producer
- [ ] Use internal/ directory for non-exported packages
- [ ] Organize by domain/feature, not by technical layer
- [ ] Avoid circular dependencies between packages
- [ ] Keep package-level state to absolute minimum
- [ ] Use cmd/ for application entry points

### 3.1 PACKAGE DESCRIPTOR (Required)

- [ ] **Target**: Every **production** `.go` file should start with Package Descriptor comment block
- [ ] **EXCEPTION**: `*_test.go` files with `package xxx_test` do NOT need Package Descriptor
- [ ] **Rationale**: Test files are external to the package, not part of its public API
- [ ] Package Descriptor format (see PACKAGE_DESCRIPTOR.md):
  ```go
  // Package <name> <one-line description>
  //
  // Purpose:
  //   <What this package does>
  //
  // Responsibilities:
  //   - <Responsibility 1>
  //   - <Responsibility 2>
  //
  // Features:
  //   - <Feature 1>  (e.g., Metrics, Tracing, Database)
  //
  // Constraints:
  //   - <Constraint 1>
  ```
- [ ] **Key**: Features should be explicitly declared
- [ ] **Avoid**: Metrics/Tracing/Telemetry WITHOUT explicit Feature declaration
- [ ] If `Features: Metrics` declared → `otel/metric` imports allowed
- [ ] If `Features: Tracing` declared → `otel/trace` imports allowed
- [ ] If NO telemetry in Features → zero telemetry imports allowed
- [ ] Verify code matches declared Features (no undeclared features used)
- [ ] Dependencies section lists all external systems/APIs
- [ ] Constraints section documents important limitations

### 4. TYPES & INTERFACES

- [ ] Keep interfaces small (1-3 methods ideal, max 5)
- [ ] Accept interfaces, return concrete types
- [ ] Define interfaces at point of use, not point of implementation
- [ ] **Required**: ALL interfaces should be in dedicated `interfaces.go` file
- [ ] Use empty interface `interface{}` / `any` sparingly
- [ ] Zero values must be valid and usable
- [ ] Make zero-value useful (e.g., `var buf bytes.Buffer` works immediately)
- [ ] Use pointer receivers for mutating methods
- [ ] Use value receivers for read-only methods and small structs
- [ ] Be consistent: if one method uses pointer receiver, use for all
- [ ] Embed interfaces to compose larger interfaces
- [ ] Use type aliases for clarity: `type UserID string`
- [ ] Prefer composition over inheritance
- [ ] Tag struct fields appropriately: `json:"name,omitempty"`

### 4.1 CONSTRUCTORS & CONFIGURATION (Required)

- [ ] **Target**: Every struct should have a constructor function `NewXXXX()`
- [ ] **Target**: Services/Repositories/Handlers should have `XXXXConfig` struct
- [ ] Constructor signature: `func NewXXXX(cfg XXXXConfig) (*XXXX, error)`
- [ ] Config struct must be a DTO with all dependencies and configuration
- [ ] Simple entities (User, Product, etc.) can use: `func NewXXXX(params...) *XXXX`
- [ ] Validate ALL config parameters in constructor, fail fast
- [ ] Constructor must return error for invalid configuration
- [ ] Config struct example:
  ```go
  type UserServiceConfig struct {
      Repository UserRepository  // dependencies
      Logger     *slog.Logger
      MaxRetries int             // configuration
      Timeout    time.Duration
  }
  ```
- [ ] Alternative: Functional Options pattern for complex cases
- [ ] Never use struct literals outside of constructors: `svc := &Service{...}` is Avoid
- [ ] Zero-value structs should not be usable without constructor

### 5. CONCURRENCY & GOROUTINES

- [ ] Always run with `-race` flag to detect data races
- [ ] Never share memory by communicating; communicate by sharing memory (use channels)
- [ ] Close channels from sender, not receiver
- [ ] Check if channel is closed: `val, ok := <-ch`
- [ ] Use `sync.WaitGroup` to wait for goroutines
- [ ] Use `context.Context` for cancellation and timeouts
- [ ] Pass context as first parameter: `func Process(ctx context.Context, ...)`
- [ ] Don't leak goroutines - always provide exit mechanism
- [ ] Use buffered channels for known capacity to avoid blocking
- [ ] Protect shared state with `sync.Mutex` or `sync.RWMutex`
- [ ] Use `sync.Once` for one-time initialization
- [ ] Prefer `sync.Map` for concurrent map access
- [ ] Use `atomic` package for simple counters/flags
- [ ] Don't pass `sync` types by value (use pointers)
- [ ] Channel direction: specify `chan<-` (send) or `<-chan` (receive) when possible
- [ ] Use `select` with `default` for non-blocking channel operations
- [ ] Always handle context cancellation: `case <-ctx.Done(): return ctx.Err()`
- [ ] Set appropriate timeouts: `ctx, cancel := context.WithTimeout(parent, 5*time.Second)`

### 6. MEMORY & PERFORMANCE (Key OPTIMIZATIONS)

#### 6.1 Required: Constants for ALL Default Values
- [ ] **Key**: NO magic numbers - all defaults should be named constants
- [ ] All timeout values in constants (e.g., `DefaultTimeout = 30 * time.Second`)
- [ ] All buffer sizes in constants (e.g., `DefaultBufferSize = 100`)
- [ ] All retry counts in constants (e.g., `DefaultMaxRetries = 3`)
- [ ] All numeric thresholds in constants (e.g., `MaxConnections = 1000`)
- [ ] Constants file exists: `constants.go` with ALL package constants
- [ ] Example:
  ```go
  // ❌ WRONG
  cfg.Timeout = 30 * time.Second  // magic number

  // ✅ CORRECT
  const DefaultTimeout = 30 * time.Second
  cfg.Timeout = DefaultTimeout
  ```

#### 6.2 Required: Bitwise Operations for Flags
- [ ] **Key**: Use bitwise flags (uint8) instead of multiple bool fields
- [ ] Declare flag constants using left-shift: `FlagX = 1 << n`
- [ ] Memory savings: 1 byte vs 8+ bytes for multiple bools
- [ ] Implement flag methods: `HasFlag()`, `SetFlag()`, `ClearFlag()`
- [ ] Example:
  ```go
  // ❌ WRONG
  type Task struct {
      IsUrgent    bool
      IsRetryable bool
      LogMetrics  bool
  }

  // ✅ CORRECT
  const (
      TaskFlagUrgent    uint8 = 1 << 0  // 0001
      TaskFlagRetryable uint8 = 1 << 1  // 0010
      TaskFlagMetrics   uint8 = 1 << 2  // 0100
  )

  type Task struct {
      Flags uint8  // 1 byte total
  }

  func (t *Task) HasFlag(flag uint8) bool {
      return t.Flags&flag != 0
  }
  ```

#### 6.3 Required: map[T]struct{} for Sets
- [ ] **Key**: Use `map[T]struct{}` for set operations, NOT `map[T]bool`
- [ ] Memory savings: 0 bytes vs 1 byte per entry
- [ ] Use for validation sets, deduplication, membership tests
- [ ] Example:
  ```go
  // ❌ WRONG
  var validStatuses = map[string]bool{
      "pending":    true,  // wastes 1 byte per entry
      "completed":  true,
  }

  // ✅ CORRECT
  var validStatuses = map[string]struct{}{
      "pending":    {},  // 0 bytes per entry
      "completed":  {},
  }

  func IsValid(s string) bool {
      _, exists := validStatuses[s]
      return exists
  }
  ```

#### 6.4 Required: Struct Field Ordering by Size
- [ ] **Key**: Order struct fields by size (largest to smallest)
- [ ] Memory savings: 20-50% reduction in struct size
- [ ] Field size reference (64-bit):
  - Pointers, slices, maps: 8 bytes
  - time.Time: 24 bytes (3 × int64)
  - string: 16 bytes (pointer + length)
  - int64/uint64/float64: 8 bytes
  - int32/uint32/float32: 4 bytes
  - int16/uint16: 2 bytes
  - int8/uint8/bool: 1 byte
- [ ] Example:
  ```go
  // ❌ WRONG - Random ordering (~56 bytes)
  type User struct {
      ID        string    // 16 bytes
      Active    bool      // 1 byte + 7 padding
      CreatedAt time.Time // 24 bytes
      Age       int32     // 4 bytes + 4 padding
  }

  // ✅ CORRECT - Ordered by size (~48 bytes)
  type User struct {
      CreatedAt time.Time // 24 bytes
      ID        string    // 16 bytes
      Age       int32     // 4 bytes
      Active    bool      // 1 byte
  }
  ```

#### 6.5 Required: chan struct{} for Signals
- [ ] **Key**: Use `chan struct{}` for signaling, NOT `chan bool`
- [ ] Memory savings: 0 bytes vs 1 byte
- [ ] Standard Go idiom for signals
- [ ] Example:
  ```go
  // ❌ WRONG
  done := make(chan bool)
  done <- true

  // ✅ CORRECT
  done := make(chan struct{})
  close(done)  // or: done <- struct{}{}
  ```

#### 6.6 General Performance
- [ ] Pre-allocate slices with known capacity: `make([]T, 0, capacity)`
- [ ] Reuse buffers with `sync.Pool` for high-frequency allocations
- [ ] Avoid string concatenation in loops; use `strings.Builder`
- [ ] Use `strconv` instead of `fmt.Sprintf` for simple conversions
- [ ] Avoid unnecessary allocations in hot paths
- [ ] Pass large structs by pointer, not by value
- [ ] Use `[]byte` instead of string for mutable data
- [ ] Avoid slice append in loops; pre-allocate capacity
- [ ] Clear slices after use in long-running programs: `slice = slice[:0]`
- [ ] Use `_` to ignore unused return values explicitly
- [ ] Profile with `pprof` for CPU and memory bottlenecks
- [ ] Benchmark critical paths: `go test -bench=.`
- [ ] Avoid reflection in performance-critical code
- [ ] Use map capacity hint: `make(map[K]V, capacity)`

### 7. RESOURCE MANAGEMENT

- [ ] Always use `defer` for cleanup: `defer file.Close()`
- [ ] Call `defer` immediately after acquiring resource
- [ ] Check errors from `Close()` in defer: `defer func() { err = f.Close() }()`
- [ ] Use `context.WithTimeout` for operations with time limits
- [ ] Cancel contexts: `defer cancel()` immediately after creating
- [ ] Close HTTP response bodies: `defer resp.Body.Close()`
- [ ] Set appropriate timeouts on HTTP clients
- [ ] Use connection pooling for databases
- [ ] Limit concurrent operations with semaphores or worker pools
- [ ] Set `MaxOpenConns` and `MaxIdleConns` for `sql.DB`
- [ ] Use `SetDeadline` for network operations
- [ ] Gracefully shutdown servers with `Shutdown(ctx)`

### 8. TESTING (Required)

- [ ] **Key**: Test files should use `package xxx_test` (black-box testing)
- [ ] **Key**: Import package under test: `import "packagename"`
- [ ] **Avoid**: Using `package xxx` in test files (white-box)
- [ ] **Avoid**: Benchmarks in committed code (zero `Benchmark*` functions allowed)
- [ ] **Avoid**: Separate benchmark files (`*_bench.go`)
- [ ] **Policy**: Benchmarks are TEMPORARY tools for local POC/optimization only
- [ ] **Policy**: Delete all benchmarks before committing
- [ ] **Target**: 100% code coverage required (use `go test -cover -coverprofile=coverage.out`)
- [ ] **Target**: Every `xxx.go` should have `xxx_test.go` in same directory
- [ ] **Target**: All mock helpers should be in `interfaces_test.go` ONLY
- [ ] Test all error paths, not just happy path
- [ ] Use table-driven tests for multiple scenarios
- [ ] Test file naming: `xxx_test.go` for black-box, `xxx_integration_test.go` for integration
- [ ] Use `t.Helper()` for test helper functions
- [ ] Use subtests: `t.Run("scenario", func(t *testing.T) {...})`
- [ ] Use `t.Parallel()` for tests that can run concurrently
- [ ] Mock external dependencies (use interfaces from `interfaces.go`)
- [ ] Test edge cases: empty slices, nil pointers, zero values, boundaries
- [ ] Use `testify/assert` or `testify/require` for assertions
- [ ] Clean up test resources: `t.Cleanup(func() {...})`
- [ ] Use `-race` flag: `go test -race ./...`
- [ ] Use `-cover` flag: `go test -cover ./...`
- [ ] Use example tests for documentation: `func ExampleFunction() {...}`
- [ ] Test timeout behavior with `context.WithTimeout`
- [ ] Test concurrent access with `go test -race -count=100`
- [ ] **Code must be designed for 100% testability**:
  - All dependencies injected via constructor
  - All external calls through interfaces
  - Time, rand, I/O abstracted behind interfaces
  - No direct use of global state or singletons

### 9. DOCUMENTATION

- [ ] Every exported symbol should have a doc comment
- [ ] Doc comments start with symbol name: `// UserRepository manages...`
- [ ] Use complete sentences with proper punctuation
- [ ] Package documentation in `doc.go` or package comment
- [ ] Document non-obvious behavior and edge cases
- [ ] Document thread-safety guarantees
- [ ] Document whether methods are safe to call on nil receiver
- [ ] Use `//go:generate` for code generation with explanation
- [ ] Add examples with `Example` prefix in tests
- [ ] Document expected errors and return values
- [ ] Use `// Deprecated:` for deprecated symbols
- [ ] Document performance characteristics if non-obvious
- [ ] Document panics if method can panic

### 10. SECURITY

- [ ] Never hardcode credentials or secrets
- [ ] Use environment variables or secret management for sensitive data
- [ ] Validate ALL user input
- [ ] Use parameterized queries, Never string concatenation for SQL
- [ ] Sanitize file paths to prevent directory traversal
- [ ] Validate and limit file upload sizes
- [ ] Use `crypto/rand`, Never `math/rand` for security
- [ ] Use constant-time comparison for secrets: `subtle.ConstantTimeCompare()`
- [ ] Disable directory listing in web servers
- [ ] Set appropriate CORS headers
- [ ] Use HTTPS in production (enforce TLS)
- [ ] Validate redirects to prevent open redirect vulnerabilities
- [ ] Use `gosec` linter for security checks
- [ ] Hash passwords with bcrypt or argon2
- [ ] Set secure cookie flags: `HttpOnly`, `Secure`, `SameSite`
- [ ] Rate limit API endpoints
- [ ] Implement request timeouts
- [ ] Log security events (authentication failures, etc.)

### 11. DEPENDENCIES & MODULES

- [ ] Use Go modules: `go.mod` and `go.sum` present
- [ ] Pin dependency versions explicitly
- [ ] Run `go mod tidy` regularly
- [ ] Use `go mod vendor` for vendoring if needed
- [ ] Minimize external dependencies
- [ ] Prefer standard library when possible
- [ ] Review dependencies for security vulnerabilities: `go list -m all | nancy sleuth`
- [ ] Use semantic versioning for module releases
- [ ] Document breaking changes in releases
- [ ] Use `replace` directive only temporarily

### 12. CODE STYLE & FORMATTING

- [ ] Run `gofmt` or `goimports` on all files (zero tolerance)
- [ ] Use `goimports` to organize imports automatically
- [ ] Group imports: stdlib, external, internal
- [ ] Remove unused imports and variables
- [ ] Line length max 120 characters (prefer 80-100)
- [ ] Use tabs for indentation (gofmt default)
- [ ] No trailing whitespace
- [ ] One blank line between functions
- [ ] Align struct fields for readability (optional but preferred)
- [ ] Use meaningful variable names (avoid single letters except in small scopes)

### 13. STANDARD PATTERNS

- [ ] Use `init()` sparingly (only for registration)
- [ ] **Required**: Functional options OR Config struct for all constructors
- [ ] **Required**: Constructor returns `(*Type, error)` not just `*Type`
- [ ] Use factory pattern for complex object creation
- [ ] Implement `String()` for debug-friendly types
- [ ] Implement `Error()` for custom error types
- [ ] Use method chaining for builders
- [ ] Return early to reduce nesting (max 3 indentation levels)
- [ ] Fail fast: validate inputs at function start
- [ ] Use blank import for side effects: `import _ "pkg"`
- [ ] **REFACTORING RULES**:
  - If function > 35 lines: extract sub-functions
  - If cyclomatic complexity > 9: simplify logic or extract functions
  - If not 100% testable: refactor to inject dependencies
  - If > 3 parameters: use config struct or options pattern

### 14. LINTING & QUALITY TOOLS (all should PASS)

- [ ] `golangci-lint run` - zero warnings allowed
- [ ] `go vet ./...` - must pass
- [ ] `staticcheck ./...` - must pass
- [ ] `gosec ./...` - security check must pass
- [ ] `go test -race ./...` - race detector must pass
- [ ] `go test -cover ./...` - **100% coverage required**
- [ ] **`gocyclo -over 9 .`** - should return zero results
- [ ] Codacy grade A required
- [ ] Code duplication max 3%
- [ ] **Lines per function**: use `go-loc` or manual check, max 35 lines
- [ ] Run all checks in CI/CD pipeline before merge

### 15. HTTP & WEB SERVICES

- [ ] Use standard `net/http` or proven routers (chi, gorilla/mux)
- [ ] Always set timeouts: `ReadTimeout`, `WriteTimeout`, `IdleTimeout`
- [ ] Use context for request-scoped values
- [ ] Return appropriate HTTP status codes
- [ ] Handle `http.Request.Body` cleanup: `defer req.Body.Close()`
- [ ] Validate content types
- [ ] Implement graceful shutdown
- [ ] Use middleware for cross-cutting concerns
- [ ] Log all requests with correlation IDs
- [ ] Implement health check endpoints
- [ ] Use structured logging (slog, zap, zerolog)
- [ ] Return JSON errors consistently: `{"error": "message"}`

### 16. DATABASE OPERATIONS

- [ ] Always use prepared statements or parameterized queries
- [ ] Use transactions for multi-step operations
- [ ] Rollback on error: `defer tx.Rollback()` before `tx.Commit()`
- [ ] Set connection pool limits
- [ ] Handle `sql.ErrNoRows` explicitly
- [ ] Use `context.Context` for query cancellation
- [ ] Close rows: `defer rows.Close()`
- [ ] Check `rows.Err()` after iteration
- [ ] Use migrations for schema changes
- [ ] Never store sensitive data unencrypted

### 17. JSON & SERIALIZATION

- [ ] Use struct tags: `json:"field_name,omitempty"`
- [ ] Validate JSON input before unmarshaling
- [ ] Handle `json.Unmarshal` errors
- [ ] Use `json.NewEncoder(w).Encode()` for streaming
- [ ] Use `omitempty` for optional fields
- [ ] Implement `MarshalJSON` and `UnmarshalJSON` for custom types
- [ ] Use `json.RawMessage` for delayed parsing
- [ ] Validate required fields after unmarshal

### 18. LOGGING

- [ ] Use structured logging (stdlib `log/slog` or zap/zerolog)
- [ ] Log at appropriate levels: Debug, Info, Warn, Error
- [ ] Include context in logs (user ID, request ID, etc.)
- [ ] Don't log sensitive information (passwords, tokens, PII)
- [ ] Use consistent log format across application
- [ ] Log errors with stack traces when appropriate
- [ ] Make logs machine-parseable (JSON format in production)

### 19. CONFIGURATION

- [ ] Use environment variables for configuration
- [ ] Provide sensible defaults
- [ ] Validate configuration on startup
- [ ] Don't commit secrets in config files
- [ ] Use `.env` files for local development (gitignored)
- [ ] Document all configuration options
- [ ] Fail fast if required config is missing

### 20. BUILD & DEPLOYMENT

- [ ] Use build tags for conditional compilation: `//go:build linux`
- [ ] Version your binaries: use `-ldflags` to embed version
- [ ] Use multi-stage Docker builds for smaller images
- [ ] Run as non-root user in containers
- [ ] Include health checks in container definitions
- [ ] Use `.dockerignore` to exclude unnecessary files
- [ ] Generate SBOMs for dependencies
- [ ] Sign releases for authenticity

## Usage

- `/review` - Review all changed files in current branch
- `/review <file_path>` - Review specific file
- `/review --full` - Full codebase review

## Review Process

### MANDATORY: Before ANY manual review, you MUST complete these phases in order

### Phase 0: FILE INVENTORY (REQUIRED FIRST STEP)

**You MUST start every review by listing ALL Go files to review:**

```bash
# List ALL .go files (excluding vendor, tests for now)
find . -name "*.go" -not -path "*/vendor/*" -not -name "*_test.go" -type f | sort
```

**Output the complete list to the user with counts:**
```
Found X .go files to review:
1. ./internal/domain/user.go
2. ./internal/domain/order.go
3. ./internal/infrastructure/repository.go
...
X. ./cmd/server/main.go
```

**Then list ALL test files:**
```bash
# List ALL test files
find . -name "*_test.go" -not -path "*/vendor/*" -type f | sort
```

**Create a review checklist:**
- [ ] File 1/X reviewed
- [ ] File 2/X reviewed
- [ ] File 3/X reviewed
...

**You MUST review EVERY file in this list. NO EXCEPTIONS.**

### Phase 1: AUTOMATED CHECKS (all should PASS)

**Run these commands BEFORE any manual review:**

```bash
# Step 1: Complexity & Size Check
gocyclo -over 9 .                    # should return zero results

# Step 2: Code Quality
golangci-lint run                     # zero warnings allowed
go vet ./...
staticcheck ./...

# Step 3: Security
gosec ./...                           # zero vulnerabilities

# Step 4: Tests & Coverage
go test -race ./...                   # Race detector should pass
go test -cover -coverprofile=coverage.out ./...
go tool cover -func=coverage.out      # 100% coverage required

# Step 5: External Quality
# Codacy analysis (via CI/CD or manual check)
```

**❌ If ANY automated check fails → Flagged immediately**

**Output the results of EVERY command to the user. Do NOT skip this step.**

### Phase 2: FILE-BY-FILE PACKAGE DESCRIPTOR CHECK (REQUIRED)

**For EACH file in the inventory from Phase 0, you MUST verify:**

**IMPORTANT: Skip `*_test.go` files with `package xxx_test` - they don't need Package Descriptor**

**Use this command to check production files only:**
```bash
# Check if file starts with Package Descriptor (production files only)
for file in $(find . -name "*.go" -not -path "*/vendor/*" -not -name "*_test.go" -type f | sort); do
  echo "=== Checking: $file ==="
  head -n 30 "$file"
  echo ""
done
```

**For EACH production file, verify the Package Descriptor exists and contains:**

1. **✓ Package Descriptor Format:**
   ```go
   // Package <name> <one-line description>
   //
   // Purpose:
   //   <What this package does>
   //
   // Responsibilities:
   //   - <Responsibility 1>
   //
   // Features:
   //   - <Feature 1>  (e.g., Metrics, Tracing, Database)
   //
   // Constraints:
   //   - <Constraint 1>
   //
   package <name>
   ```

2. **✓ Feature Declaration Compliance:**
   - If file imports `otel/metric` → must have `Features: Metrics`
   - If file imports `otel/trace` → must have `Features: Tracing`
   - If NO telemetry declared → zero telemetry imports allowed

**Create a table showing Package Descriptor status for production files:**

| File | Package Descriptor | Features Declared | Imports Match | Status |
|------|-------------------|-------------------|---------------|--------|
| user.go | ❌ Missing | - | - | FAIL |
| order.go | ✅ Present | Metrics, Database | ✅ Match | PASS |
| user_test.go | ⏭️ Skipped | N/A (test file) | N/A | SKIP |
| ... | ... | ... | ... | ... |

**❌ ANY production file missing Package Descriptor → IMMEDIATE REJECTION**

**Note**: `*_test.go` files with `package xxx_test` are skipped (black-box tests are external)

### Phase 3: STRUCTURAL COMPLIANCE (Key)

**Now check structural requirements across the codebase:**

- [ ] **File Structure Check**:
  - [ ] **Key**: ONE FILE PER STRUCT (no `models.go` with multiple structs) ✓
  - [ ] `constants.go` exists with ALL constants ✓
  - [ ] `errors.go` exists with ALL errors ✓
  - [ ] Every `.go` file has corresponding `_test.go` ✓
  - [ ] Package has `interfaces.go` file ✓
  - [ ] Package has `interfaces_test.go` for mocks ✓
  - [ ] NO `*_helper.go` files (except in tests) ✓

- [ ] **Constructor Pattern Check**:
  - [ ] Every struct has `NewXXXX()` constructor ✓
  - [ ] Services/Repos have `XXXXConfig` struct ✓
  - [ ] Constructors return `(*Type, error)` ✓
  - [ ] NO struct literals outside constructors ✓

- [ ] **Function Size Check** (line by line):
  - [ ] Count lines per function: ALL < 35 lines ✓
  - [ ] Functions > 35 lines → should be refactored ✓

- [ ] **Performance Optimization Check**:
  - [ ] **Key**: NO magic numbers - all defaults in constants ✓
  - [ ] **Key**: Bitwise flags (uint8) used instead of multiple bools ✓
  - [ ] **Key**: `map[T]struct{}` used for sets (not `map[T]bool`) ✓
  - [ ] **Key**: Struct fields ordered by size (largest to smallest) ✓
  - [ ] **Key**: `chan struct{}` used for signals (not `chan bool`) ✓

**❌ If structural compliance fails → REJECTION with refactoring required**

### Phase 4: MANUAL CODE REVIEW (FILE-BY-FILE REQUIRED)

**YOU MUST REVIEW EACH FILE INDIVIDUALLY AGAINST ALL CHECKPOINTS**

**For EACH file from Phase 0 inventory, you MUST:**

1. **Read the entire file** using the Read tool
2. **Apply ALL 20 checkpoint categories** (283+ points total)
3. **Document violations for THIS specific file**
4. **Move to next file** - repeat until ALL files reviewed

**Review format for EACH file:**

```markdown
## File X/Total: path/to/file.go

### ✓ Checkpoints Applied:
- [x] 1. Error Handling (12 points)
- [x] 2. Naming Conventions (12 points)
- [x] 3. Code Organization (22 points)
- [x] 4. Types & Interfaces (14 points)
- [x] 5. Constructors & Config (11 points)
- [x] 6. Concurrency (18 points)
- [x] 7. Memory & Performance (45 points)
- [x] 8. Resource Management (12 points)
- [x] 9. Testing (22 points)
- [x] 10. Documentation (12 points)
- [x] 11. Security (18 points)
- [x] 12. Dependencies (10 points)
- [x] 13. Code Style (10 points)
- [x] 14. Standard Patterns (14 points)
- [x] 15. Linting & Quality (11 points)
- [x] 16. HTTP & Web (12 points) - N/A if no HTTP
- [x] 17. Database (10 points) - N/A if no DB
- [x] 18. JSON (8 points) - N/A if no JSON
- [x] 19. Logging (7 points)
- [x] 20. Configuration (7 points)

### Issues Found:
- ❌ Line 45: [Category] Description of violation
- ❌ Line 67: [Category] Description of violation
- ✅ No issues in [Category]

### Status: PASS / FAIL
```

**IMPORTANT: You CANNOT skip files. If you have 50 files, you must review all 50 files.**

**The 20 checkpoint categories to verify for EACH file:**

1. **Error Handling** (12 points)
   - Never ignore errors with `_`
   - Always wrap errors with context
   - Use `errors.Is()` and `errors.As()`
   - Check errors from `Close()`, `Flush()`, `Write()`
   - Return early on errors
   - No panic for expected errors
   - Error messages lowercase
   - Defer with error checking

2. **Naming Conventions** (12 points)
   - Package: lowercase, single-word, no underscores
   - Interfaces: `-er` suffix
   - No stutter
   - Acronyms uppercase
   - Receiver names: 1-2 char
   - Boolean: `is/has/can/should` prefix
   - Consistent receiver names

3. **Code Organization** (22 points)
   - Package Descriptor present
   - Features declared
   - Functions < 35 lines
   - Complexity < 10
   - Max 3 indentation levels
   - One file per struct
   - Constants in constants.go
   - Errors in errors.go
   - Interfaces in interfaces.go

4. **Types & Interfaces** (14 points)
   - Small interfaces (1-5 methods)
   - Accept interfaces, return concrete
   - Zero values valid
   - Pointer receivers for mutation
   - Consistent receivers
   - Proper struct tags

5. **Constructors & Config** (11 points)
   - Every struct has `NewXXXX()`
   - Services have `XXXXConfig`
   - Constructor validates
   - Returns `(*Type, error)`
   - No struct literals outside constructors

6. **Concurrency** (18 points)
   - Context as first param
   - No goroutine leaks
   - Close channels from sender
   - Use `sync.WaitGroup`
   - Protect shared state
   - Handle context cancellation
   - Buffered channels for capacity

7. **Memory & Performance** (45 points)
   - NO magic numbers (constants required)
   - Bitwise flags instead of multiple bools
   - `map[T]struct{}` for sets
   - Struct fields ordered by size
   - `chan struct{}` for signals
   - Pre-allocate slices
   - Use `strings.Builder`
   - Use `strconv` not `fmt.Sprintf`

8. **Resource Management** (12 points)
   - Always use `defer` for cleanup
   - Check errors in defer
   - Cancel contexts
   - Close response bodies
   - Set timeouts

9. **Testing** (22 points)
   - Test files use `package xxx_test`
   - 100% coverage
   - Table-driven tests
   - Test all error paths
   - Mock external dependencies
   - Test edge cases

10. **Documentation** (12 points)
    - Every exported symbol has godoc
    - Doc starts with symbol name
    - Complete sentences
    - Document thread-safety
    - Document panics

11. **Security** (18 points)
    - No hardcoded secrets
    - Validate ALL input
    - Parameterized queries
    - `crypto/rand` not `math/rand`
    - Sanitize file paths
    - Rate limiting

12. **Dependencies** (10 points)
    - `go.mod` present
    - Pin versions
    - Run `go mod tidy`
    - Minimize dependencies

13. **Code Style** (10 points)
    - `gofmt` applied
    - Imports organized
    - No unused imports
    - No trailing whitespace

14. **Standard Patterns** (14 points)
    - Fail fast
    - Return early
    - Max 3 parameters or use config
    - Implement `String()` for types

15. **Linting & Quality** (11 points)
    - `golangci-lint` passes
    - `go vet` passes
    - `staticcheck` passes
    - `gosec` passes
    - `gocyclo < 10`

16. **HTTP & Web** (12 points) - if applicable
    - Set timeouts
    - Use context
    - Return appropriate status codes
    - Close request body

17. **Database** (10 points) - if applicable
    - Prepared statements
    - Use transactions
    - Handle `sql.ErrNoRows`
    - Close rows

18. **JSON** (8 points) - if applicable
    - Use struct tags
    - Handle unmarshal errors
    - Use `omitempty`
    - Validate required fields

19. **Logging** (7 points)
    - Structured logging
    - Appropriate levels
    - Include context
    - No sensitive data

20. **Configuration** (7 points)
    - Environment variables
    - Sensible defaults
    - Validate on startup
    - Document options

**Total: 283+ checkpoints to verify PER FILE** ⬆️ (+33 new performance rules)

**You MUST go through EVERY file in the inventory. Progress tracking required:**

```
Progress: 15/50 files reviewed
Remaining: 35 files
Status: In Progress
```

### Phase 4: TESTABILITY VERIFICATION

- [ ] All dependencies injected via constructor
- [ ] All external I/O behind interfaces
- [ ] No global state or singletons
- [ ] Time/rand abstracted for testing
- [ ] 100% branch coverage achieved
- [ ] All error paths tested
- [ ] Edge cases covered

### Phase 5: REFACTORING REQUIREMENTS

If code violates rules, provide SPECIFIC refactoring instructions:

**Example for complexity > 9:**
```
❌ Function `ProcessOrder` has cyclomatic complexity 12 (max: 9)
📍 Location: orders.go:45

REQUIRED REFACTORING:
1. Extract validation logic → validateOrder()
2. Extract payment processing → processPayment()
3. Extract notification → notifyCustomer()

Result: Main function complexity: 4, extracted functions: 3-4 each
```

**Example for function > 35 lines:**
```
❌ Function `HandleRequest` is 48 lines (max: 35)
📍 Location: handler.go:120

REQUIRED REFACTORING:
1. Extract request parsing → parseRequest() [~10 lines]
2. Extract business logic → processBusiness() [~15 lines]
3. Extract response building → buildResponse() [~8 lines]

Result: Main function: ~15 lines, 3 focused sub-functions
```

### Phase 6: VERDICT

- ✅ **APPROVED** - All 250+ checkpoints pass, ready for production
- ❌ **REJECTED** - Critical violations, see refactoring requirements
- ⚠️ **CHANGES REQUESTED** - Minor issues, resubmit after fixes

**REJECTION CRITERIA (immediate fail):**
- Missing Package Descriptor
- Undeclared features used (e.g., telemetry without Features: Metrics)
- **Wrong test package** (using `package xxx` instead of `package xxx_test`)
- **Multiple structs in one file** (must be 1 file per struct)
- Any function > 35 lines
- Any function gocyclo > 9
- Coverage < 100%
- Missing constructors
- Missing Config for services
- Wrong file structure
- Any ignored errors
- Any security vulnerability
- golangci-lint warnings
- **Magic numbers** (not using constants for defaults)
- **Multiple bools as flags** (should use bitwise uint8)
- **map[T]bool for sets** (should use map[T]struct{})
- **Unordered struct fields** (not ordered by size)

## Example Output

```markdown
## Code Review: user_service.go

### ❌ PHASE 1: AUTOMATED CHECKS - FAILED

1. **gocyclo: 2 violations**
   ```
   12  ProcessUser   user_service.go:45
   11  ValidateData  user_service.go:89
   ```
   ➜ REJECTED: Complexity > 9 not allowed

2. **golangci-lint: 3 warnings**
   - Line 67: exported function missing comment
   - Line 112: ineffectual assignment to err
   - Line 145: G104: Errors unhandled
   ➜ REJECTED: zero warnings policy

3. **Coverage: 78%**
   ```
   user_service.go         78.5%
   user_service_test.go    100%
   ```
   ➜ REJECTED: Requires 100% coverage

### ❌ PHASE 2: STRUCTURAL COMPLIANCE - FAILED

1. **Package Descriptor Violations**:
   - ❌ user_service.go: Missing Package Descriptor
   - ❌ File must start with:
     ```go
     // Package userservice provides user management operations
     //
     // Purpose:
     //   Handles user CRUD, authentication, and profile management
     //
     // Responsibilities:
     //   - User creation and validation
     //   - User authentication
     //
     // Features:
     //   - Database
     //   - Validation
     //   - Logging
     //
     package userservice
     ```
   - ⚠️ Line 45: Using `otel/metric` but `Features: Metrics` NOT declared
   - ⚠️ Line 67: Using `otel/trace` but `Features: Tracing` NOT declared

2. **Missing Files**:
   - ❌ interfaces.go not found in package
   - ❌ interfaces_test.go not found
   - ✅ user_service_test.go exists

3. **Constructor Violations**:
   - ❌ Line 23: `UserService` struct has no `NewUserService()` constructor
   - ❌ No `UserServiceConfig` struct defined
   - ❌ Line 156: Direct struct literal used: `svc := &UserService{...}`

3. **Function Size Violations**:
   - ❌ `ProcessUser()` - 48 lines (max: 35)
   - ❌ `ValidateData()` - 42 lines (max: 35)
   - ❌ `HandleRequest()` - 38 lines (max: 35)

### 🔧 REQUIRED REFACTORING

#### Issue 1: ProcessUser() - Complexity 12, Size 48 lines

**Current Structure (WRONG):**
```go
func (s *UserService) ProcessUser(ctx context.Context, userID string) error {
    // 48 lines of mixed responsibilities
    // - Validation (10 lines)
    // - Database fetch (8 lines)
    // - Business logic (15 lines)
    // - Notification (8 lines)
    // - Logging (7 lines)
}
```

**REQUIRED REFACTORING:**
```go
// 1. Create interfaces.go
type UserRepository interface {
    Get(ctx context.Context, id string) (*User, error)
}

type NotificationService interface {
    Notify(ctx context.Context, user *User) error
}

// 2. Create Config struct in user_service.go
type UserServiceConfig struct {
    Repository  UserRepository
    Notifier    NotificationService
    Logger      *slog.Logger
    MaxRetries  int
    Timeout     time.Duration
}

// 3. Add constructor
func NewUserService(cfg UserServiceConfig) (*UserService, error) {
    if cfg.Repository == nil {
        return nil, errors.New("repository is required")
    }
    if cfg.Notifier == nil {
        return nil, errors.New("notifier is required")
    }
    if cfg.Logger == nil {
        cfg.Logger = slog.Default()
    }
    return &UserService{
        repo:     cfg.Repository,
        notifier: cfg.Notifier,
        logger:   cfg.Logger,
        retries:  cfg.MaxRetries,
        timeout:  cfg.Timeout,
    }, nil
}

// 4. Refactor ProcessUser
func (s *UserService) ProcessUser(ctx context.Context, userID string) error {
    if err := s.validateUserID(userID); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }

    user, err := s.fetchUser(ctx, userID)
    if err != nil {
        return fmt.Errorf("fetch failed: %w", err)
    }

    if err := s.applyBusinessLogic(ctx, user); err != nil {
        return fmt.Errorf("business logic failed: %w", err)
    }

    if err := s.notifyUser(ctx, user); err != nil {
        s.logger.Error("notification failed", "error", err)
        // Don't fail on notification error
    }

    return nil
}
// Result: 18 lines, complexity: 4

func (s *UserService) validateUserID(id string) error {
    // 8 lines, complexity: 3
}

func (s *UserService) fetchUser(ctx context.Context, id string) (*User, error) {
    // 12 lines, complexity: 3
}

func (s *UserService) applyBusinessLogic(ctx context.Context, user *User) error {
    // 15 lines, complexity: 4
}

func (s *UserService) notifyUser(ctx context.Context, user *User) error {
    // 10 lines, complexity: 2
}
```

**Result:**
- ✅ Main function: 18 lines (< 35)
- ✅ All sub-functions: < 35 lines
- ✅ Complexity: all < 10
- ✅ 100% testable with injected dependencies
- ✅ Constructor with Config
- ✅ Interfaces extracted to interfaces.go

#### Issue 2: Missing Test Coverage

**Required Tests (in user_service_test.go):**
```go
func TestNewUserService_Success(t *testing.T) { ... }
func TestNewUserService_MissingRepository(t *testing.T) { ... }
func TestNewUserService_MissingNotifier(t *testing.T) { ... }
func TestProcessUser_Success(t *testing.T) { ... }
func TestProcessUser_InvalidID(t *testing.T) { ... }
func TestProcessUser_UserNotFound(t *testing.T) { ... }
func TestProcessUser_BusinessLogicError(t *testing.T) { ... }
func TestProcessUser_NotificationError(t *testing.T) { ... }
// ... all error paths and edge cases
```

**Mock Helpers (in interfaces_test.go):**
```go
type mockUserRepository struct {
    getFunc func(ctx context.Context, id string) (*User, error)
}

type mockNotificationService struct {
    notifyFunc func(ctx context.Context, user *User) error
}
```

### 📋 CHECKLIST VIOLATIONS (Manual Review)

**Error Handling:**
- ❌ Line 67: ignored error `_ = user.Validate()`
- ❌ Line 112: error reassigned and lost
- ❌ Line 145: `defer file.Close()` without checking error

**Documentation:**
- ❌ `UserService` struct missing godoc comment
- ❌ `ProcessUser()` function missing godoc
- ✅ Package documentation present

**Security:**
- ⚠️  Line 234: SQL query uses string concatenation (potential injection)
- ⚠️  Line 267: password logged in plain text

### VERDICT: **❌ REJECTED**

**Must fix before re-review:**
1. Refactor 3 functions to < 35 lines with complexity < 10
2. Create interfaces.go and interfaces_test.go
3. Add constructor NewUserService() with Config
4. Remove all struct literals, use constructor only
5. Achieve 100% test coverage
6. Fix all golangci-lint warnings
7. Fix error handling violations (3 issues)
8. Fix security issues (2 issues)

**Re-run checks after fixes:**
```bash
gocyclo -over 9 .
golangci-lint run
go test -race -cover ./...
```

**DO NOT re-submit until ALL issues are resolved.**
```

## Standards Enforced

**The reviewer DEMANDS:**

### 🔴 Key RULES (Auto-Reject):
1. **Package Descriptor**: should exist on EVERY `.go` file with Purpose, Responsibilities, Features
2. **Feature Declaration**: NO metrics/tracing/telemetry WITHOUT explicit `Features:` declaration
3. **Function size**: ALL functions < 35 lines ()
4. **Complexity**: gocyclo < 10 for ALL functions (use `gocyclo -over 9 .`)
5. **Coverage**: 100% code coverage required
6. **Constructors**: Every struct should have `NewXXXX()` constructor
7. **Config**: Services/Repos/Handlers should have `XXXXConfig` struct
8. **File structure**: 1:1 mapping `.go` ↔ `._test.go`
9. **Interfaces**: ALL interfaces in dedicated `interfaces.go`
10. **Mocks**: ALL test helpers in `interfaces_test.go` ONLY
11. **Errors**: zero ignored errors (no `_` for error returns)
12. **Linting**: zero golangci-lint warnings

### 📐 STRUCTURAL REQUIREMENTS:

**Package Structure:**
```
package/
├── interfaces.go           # ALL interfaces here
├── interfaces_test.go      # ALL mock helpers here
├── user_service.go         # Implementation
├── user_service_test.go    # Tests (1:1 mapping)
├── order_service.go
├── order_service_test.go
└── NO *_helper.go files    # Helpers only in *_test.go
```

**Constructor Pattern (Required):**
```go
// Config struct for services
type ServiceConfig struct {
    Dependency1 Interface1
    Dependency2 Interface2
    Setting1    string
    Setting2    int
}

// Constructor with validation
func NewService(cfg ServiceConfig) (*Service, error) {
    if cfg.Dependency1 == nil {
        return nil, errors.New("dependency1 required")
    }
    // ... validate all required fields
    return &Service{...}, nil
}

// NO direct struct literals allowed:
// ❌ svc := &Service{...}        // Avoid
// ✅ svc, err := NewService(cfg)  // REQUIRED
```

### 📊 QUALITY GATES (ALL Must Pass):

```bash
# Gate 1: Complexity
gocyclo -over 9 .              # should return zero

# Gate 2: Linting
golangci-lint run              # should have zero warnings
go vet ./...
staticcheck ./...

# Gate 3: Security
gosec ./...                    # should have zero issues

# Gate 4: Testing
go test -race ./...            # should pass (no races)
go test -cover ./...           # should be 100%

# Gate 5: Coverage report
go tool cover -func=coverage.out | grep total
# should show: total: (statements) 100.0%
```

### 🎯 REFACTORING MANDATE:

**If function > 35 lines or complexity > 9:**
1. Extract validation → `validateX()`
2. Extract data access → `fetchX()`
3. Extract business logic → `processX()`
4. Extract side effects → `notifyX()`
5. Main function orchestrates only

**Result:**
- Main function: 10-20 lines
- Each sub-function: < 35 lines
- All complexity: < 10
- 100% testable

### ⚡ TESTABILITY REQUIREMENTS:

**Code should be designed for testing:**
```go
// ❌ NOT TESTABLE:
func Process() error {
    db := sql.Open(...)        // hard dependency
    now := time.Now()          // hard to test
    rand.Intn(100)             // non-deterministic
}

// ✅ TESTABLE:
type Dependencies struct {
    DB      Database
    Clock   Clock
    Random  Random
}

func Process(deps Dependencies) error {
    // All dependencies injected
    // 100% mockable
}
```

### 📋 283+ CHECKPOINT REVIEW:

Every submission reviewed against ALL 20 categories:
- Error Handling (12 points)
- Naming Conventions (12 points)
- Code Organization & Structure (22 points) ⬆️ +8 for 1-file-per-struct
- Types & Interfaces (14 points)
- Constructors & Configuration (11 points)
- Concurrency & Goroutines (18 points)
- **Memory & Performance (45 points)** ⬆️ +30 for performance optimizations
- Resource Management (12 points)
- Testing (22 points)
- Documentation (12 points)
- Security (18 points)
- Dependencies & Modules (10 points)
- Code Style & Formatting (10 points)
- Standard Patterns (14 points)
- Linting & Quality Tools (11 points)
- HTTP & Web Services (12 points)
- Database Operations (10 points)
- JSON & Serialization (8 points)
- Logging (7 points)
- Configuration (7 points)
- Build & Deployment (8 points)

**Total: 283+ explicit checkpoints** ⬆️ (+33 new performance rules)

---

**Review outcome:**
- ✅ **Approved** - Ready for production
- ❌ **Changes needed** - Address issues and re-submit
