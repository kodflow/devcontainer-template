# Design Patterns Knowledge Base

## Purpose

250+ patterns for Claude agents. **Consult during /plan and /review.**

## Categories

| Category | Patterns | Use For |
|----------|----------|---------|
| `principles/` | SOLID, DRY, KISS | Always applicable |
| `creational/` | Factory, Builder, Singleton | Object creation |
| `structural/` | Adapter, Decorator, Proxy | Structure |
| `behavioral/` | Observer, Strategy, Command | Behavior |
| `performance/` | Cache, Lazy Load, Pool | Optimization |
| `concurrency/` | Thread Pool, Actor, Mutex | Parallelism |
| `enterprise/` | PoEAA (40+ patterns) | Enterprise apps |
| `ddd/` | Aggregate, Entity, Repository | Domain logic |
| `cloud/` | Circuit Breaker, Saga | Distributed |
| `security/` | OAuth, JWT, RBAC | Auth & authz |
| `testing/` | Mock, Stub, Fixture | Test isolation |

## Quick Lookup

| Problem | Pattern | File |
|---------|---------|------|
| Complex creation | Builder | `creational/builder.md` |
| Expensive objects | Object Pool | `performance/object-pool.md` |
| Race conditions | Mutex | `concurrency/mutex-semaphore.md` |
| Cascade failures | Circuit Breaker | `cloud/circuit-breaker.md` |
| Authentication | OAuth/JWT | `security/oauth2.md` |

## When to Consult

**During /plan:**
1. Read `README.md` for category index
2. Find applicable patterns (1-3)
3. Include in plan with justification

**During /review:**
1. Identify patterns in code
2. Verify correct implementation
3. Suggest alternatives if needed

## Pattern Format

Each pattern contains:
- Title + one-line description
- Go code example
- When to use
- Related patterns

Templates: `TEMPLATE-PATTERN.md`, `TEMPLATE-README.md`

## Sources

GoF (23), Fowler PoEAA (40+), EIP (65), Azure Patterns, DDD, FP patterns
