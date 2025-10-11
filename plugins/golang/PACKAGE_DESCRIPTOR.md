# Package Descriptor - Specification

## Overview

**Every Go file MUST start with a Package Descriptor comment block** above the `package` declaration.

This descriptor defines:
- Purpose of the file/package
- Responsibilities and scope
- **Explicit feature flags** (metrics, tracing, caching, etc.)

**RULE**: Features like telemetry, metrics, tracing are Not allowed unless explicitly declared with `// Feature: <name>`

## Format

```go
// Package <name> <one-line description>
//
// Purpose:
//   <Detailed purpose of this package/file>
//
// Responsibilities:
//   - <Responsibility 1>
//   - <Responsibility 2>
//   - <Responsibility N>
//
// Dependencies:
//   - <External dependency 1>
//   - <External dependency 2>
//
// Features:
//   - <Feature 1>
//   - <Feature 2>
//
// Constraints:
//   - <Constraint 1>
//   - <Constraint 2>
//
package <name>
```

## Mandatory Fields

| Field | Required | Description |
|-------|----------|-------------|
| `Package` | ✅ Yes | Package name and one-line description |
| `Purpose` | ✅ Yes | Detailed explanation of package purpose |
| `Responsibilities` | ✅ Yes | List of responsibilities (min 1) |
| `Dependencies` | ⚠️ If applicable | External dependencies (DB, APIs, etc.) |
| `Features` | ⚠️ If applicable | **Explicit feature flags** |
| `Constraints` | ⚠️ If applicable | Design constraints or limitations |

## Feature Flags

### Available Features

Features MUST be explicitly declared to be used in the code:

| Feature | Description | Required Dependencies |
|---------|-------------|----------------------|
| `Metrics` | OpenTelemetry metrics collection | `go.opentelemetry.io/otel/metric` |
| `Tracing` | Distributed tracing with spans | `go.opentelemetry.io/otel/trace` |
| `Logging` | Structured logging | `log/slog` or `go.uber.org/zap` |
| `Caching` | In-memory or distributed cache | Cache interface |
| `RateLimiting` | Request rate limiting | Rate limiter interface |
| `CircuitBreaker` | Circuit breaker pattern | Circuit breaker interface |
| `Retry` | Automatic retry logic | Retry policy |
| `Validation` | Input validation | Validator interface |
| `Authentication` | Auth/AuthZ logic | Auth provider |
| `Database` | Database operations | Database interface |
| `HTTP` | HTTP client/server | `net/http` |
| `gRPC` | gRPC client/server | `google.golang.org/grpc` |
| `PubSub` | Message queue pub/sub | Message broker interface |
| `EventSourcing` | Event sourcing pattern | Event store |
| `CQRS` | Command Query Responsibility Segregation | Command/Query buses |
| `Saga` | Saga pattern for distributed transactions | Saga orchestrator |
| `Webhooks` | Webhook handling | Webhook registry |
| `Encryption` | Data encryption/decryption | Crypto interface |
| `Compression` | Data compression | Compression interface |

### Feature Declaration Rules

**STRICT RULES:**
1. ❌ **NO implicit features** - If not declared, it's Not allowed
2. ✅ **Explicit only** - Declare with `// Feature: <name>`
3. 🔍 **Review check** - Reviewer MUST verify features match code
4. ⚠️ **Violation = REJECT** - Using undeclared feature = immediate rejection

### Examples

**✅ CORRECT - Feature declared:**
```go
// Package userservice provides user management operations
//
// Purpose:
//   Handles user CRUD operations, authentication, and profile management.
//
// Responsibilities:
//   - User creation and validation
//   - User authentication and authorization
//   - Profile updates and retrieval
//
// Dependencies:
//   - PostgreSQL database for user storage
//   - Redis cache for session management
//
// Features:
//   - Metrics
//   - Tracing
//   - Caching
//   - Validation
//   - Database
//
// Constraints:
//   - Max 1000 users per organization
//   - Password must meet complexity requirements
//
package userservice

import (
    "go.opentelemetry.io/otel/metric"  // ✅ OK: Metrics feature declared
    "go.opentelemetry.io/otel/trace"   // ✅ OK: Tracing feature declared
)
```

**❌ WRONG - Feature NOT declared:**
```go
// Package orderservice handles order processing
//
// Purpose:
//   Process customer orders and manage inventory.
//
// Responsibilities:
//   - Order creation and validation
//   - Inventory management
//
// Features:
//   - Database
//   - Validation
//
package orderservice

import (
    "go.opentelemetry.io/otel/metric"  // ❌ Not allowed: Metrics not in Features
    "go.opentelemetry.io/otel/trace"   // ❌ Not allowed: Tracing not in Features
)
```

**✅ CORRECT - No telemetry:**
```go
// Package calculator provides mathematical operations
//
// Purpose:
//   Provides pure mathematical calculation functions.
//
// Responsibilities:
//   - Basic arithmetic operations
//   - Statistical calculations
//
// Features:
//   - Validation
//
package calculator

// No telemetry imports - ✅ CLEAN CODE
```

## Templates

### 1. Basic Service (No Telemetry)

```go
// Package <service> provides <domain> operations
//
// Purpose:
//   <Detailed explanation of what this service does>
//
// Responsibilities:
//   - <Core responsibility 1>
//   - <Core responsibility 2>
//   - <Core responsibility 3>
//
// Dependencies:
//   - <Dependency 1>
//   - <Dependency 2>
//
// Features:
//   - Database
//   - Validation
//   - Logging
//
// Constraints:
//   - <Design constraint 1>
//   - <Design constraint 2>
//
package <service>
```

### 2. Service with Observability

```go
// Package <service> provides <domain> operations with full observability
//
// Purpose:
//   <Detailed explanation>
//
// Responsibilities:
//   - <Responsibility 1>
//   - <Responsibility 2>
//
// Dependencies:
//   - <Dependency 1>
//   - <Dependency 2>
//
// Features:
//   - Metrics        // OpenTelemetry metrics
//   - Tracing        // Distributed tracing
//   - Logging        // Structured logging
//   - Database
//   - Validation
//
// Constraints:
//   - <Constraint 1>
//
package <service>
```

### 3. HTTP Handler

```go
// Package handlers provides HTTP request handlers for the API
//
// Purpose:
//   Handles incoming HTTP requests, validates input, and returns responses.
//
// Responsibilities:
//   - Request parsing and validation
//   - Response serialization
//   - Error handling and HTTP status codes
//
// Dependencies:
//   - UserService for business logic
//   - AuthMiddleware for authentication
//
// Features:
//   - HTTP
//   - Validation
//   - Logging
//   - Authentication
//
// Constraints:
//   - All responses must be JSON
//   - Max request size: 10MB
//
package handlers
```

### 4. Repository/Data Access

```go
// Package repository provides data access layer for <entity>
//
// Purpose:
//   Abstracts database operations for <entity> management.
//
// Responsibilities:
//   - CRUD operations for <entity>
//   - Query optimization and connection pooling
//   - Transaction management
//
// Dependencies:
//   - PostgreSQL 14+ for data persistence
//   - pgx driver for database connectivity
//
// Features:
//   - Database
//   - Logging
//
// Constraints:
//   - All queries must use prepared statements
//   - Max connection pool size: 25
//   - Query timeout: 30 seconds
//
package repository
```

### 5. Domain Entity (Pure)

```go
// Package domain defines core business entities and value objects
//
// Purpose:
//   Represents the core domain model with business rules and invariants.
//
// Responsibilities:
//   - Entity definitions
//   - Business rule validation
//   - Value object implementations
//
// Features:
//   - Validation
//
// Constraints:
//   - No external dependencies
//   - Pure business logic only
//   - Immutable value objects
//
package domain
```

### 6. Client/Integration

```go
// Package client provides HTTP client for <external-service> API
//
// Purpose:
//   Integrates with <external-service> REST API for <functionality>.
//
// Responsibilities:
//   - API request construction
//   - Response parsing and error handling
//   - Connection management and retries
//
// Dependencies:
//   - <External service> API v2.0
//   - OAuth2 authentication
//
// Features:
//   - HTTP
//   - Retry
//   - CircuitBreaker
//   - Logging
//   - Tracing
//
// Constraints:
//   - Max retry attempts: 3
//   - Request timeout: 10s
//   - Circuit breaker opens after 5 failures
//
package client
```

### 7. Utility Package

```go
// Package <util> provides utility functions for <purpose>
//
// Purpose:
//   Collection of pure utility functions for <specific purpose>.
//
// Responsibilities:
//   - <Utility function category 1>
//   - <Utility function category 2>
//
// Features:
//   - None (Pure functions)
//
// Constraints:
//   - No side effects
//   - No external dependencies
//   - Thread-safe operations
//
package <util>
```

### 8. Worker/Background Job

```go
// Package worker provides background job processing
//
// Purpose:
//   Processes asynchronous jobs from message queue with retries.
//
// Responsibilities:
//   - Job queue consumption
//   - Job processing and error handling
//   - Dead letter queue management
//
// Dependencies:
//   - RabbitMQ for job queue
//   - Redis for job state tracking
//
// Features:
//   - PubSub
//   - Retry
//   - Logging
//   - Metrics
//
// Constraints:
//   - Max concurrent jobs: 10
//   - Job timeout: 5 minutes
//   - Max retries: 3
//
package worker
```

## Validation Checklist

Before submitting code, verify:

- [ ] Every `.go` file has Package Descriptor above `package` statement
- [ ] `Purpose` is clear and detailed
- [ ] `Responsibilities` list is complete (min 1 item)
- [ ] `Dependencies` lists all external systems
- [ ] `Features` explicitly declares ALL used features
- [ ] No metrics/tracing code unless `Features: Metrics/Tracing` declared
- [ ] `Constraints` documents important limitations
- [ ] Descriptor matches actual code behavior

## Review Process

**Reviewer MUST check:**

1. ✅ Package Descriptor exists
2. ✅ All mandatory fields present
3. ✅ Features match actual code:
   - If code uses `otel/metric` → `Metrics` must be in Features
   - If code uses `otel/trace` → `Tracing` must be in Features
   - If no telemetry declared → NO telemetry imports allowed
4. ✅ Dependencies are accurate
5. ✅ Constraints are documented

**❌ Flagged immediately if:**
- Package Descriptor missing
- Feature used but not declared
- Metrics/Tracing added without explicit declaration

## Examples by Service Type

### REST API Service

```go
// Package api provides RESTful API endpoints for user management
//
// Purpose:
//   Exposes HTTP endpoints for user CRUD operations, authentication,
//   and profile management with JSON request/response handling.
//
// Responsibilities:
//   - HTTP request routing and handling
//   - Request validation and response formatting
//   - Error handling with appropriate HTTP status codes
//   - API versioning management
//
// Dependencies:
//   - UserService for business logic
//   - AuthMiddleware for JWT validation
//   - PostgreSQL via UserRepository
//
// Features:
//   - HTTP
//   - Validation
//   - Logging
//   - Authentication
//
// Constraints:
//   - API version: v1
//   - Max request body: 5MB
//   - Response format: JSON only
//   - Rate limit: 100 req/min per client
//
package api
```

### Event-Driven Service

```go
// Package eventhandler processes domain events from event bus
//
// Purpose:
//   Subscribes to domain events and triggers corresponding actions
//   to maintain eventual consistency across bounded contexts.
//
// Responsibilities:
//   - Event consumption from message broker
//   - Event deserialization and validation
//   - Idempotent event processing
//   - Failed event handling and DLQ management
//
// Dependencies:
//   - Kafka for event streaming
//   - OrderService for order updates
//   - NotificationService for alerts
//
// Features:
//   - PubSub
//   - EventSourcing
//   - Logging
//   - Metrics
//   - Retry
//
// Constraints:
//   - Events must be processed in order per partition
//   - Max processing time: 30s per event
//   - Duplicate events must be handled idempotently
//
package eventhandler
```

## Migration Guide

For existing code without Package Descriptors:

1. **Audit existing code**: Identify all features currently used
2. **Create descriptor**: Use appropriate template
3. **Declare features**: List ALL features used (be honest!)
4. **Review dependencies**: List external systems/libraries
5. **Document constraints**: Add known limitations
6. **Commit descriptor**: Add descriptor to file
7. **Verify**: Ensure no undeclared features remain

---

**Remember: Package Descriptors are Required. No exceptions.**
