# Entity Pattern

## Definition

An **Entity** is a domain object with a distinct identity that runs through time and different representations. Unlike Value Objects, entities are distinguished by their identity, not their attributes.

```
Entity = Identity + State + Behavior + Lifecycle
```

**Key characteristics:**
- **Identity**: Unique identifier that persists across changes
- **Continuity**: Same entity even when attributes change
- **Lifecycle**: Creation, modification, and potentially deletion
- **Mutability**: State can change while identity remains constant

## TypeScript Implementation

```typescript
// Base Entity with identity
abstract class Entity<TId> {
  protected readonly _id: TId;

  constructor(id: TId) {
    this._id = id;
  }

  get id(): TId {
    return this._id;
  }

  equals(other: Entity<TId>): boolean {
    if (other === null || other === undefined) return false;
    if (!(other instanceof Entity)) return false;
    return this._id === other._id;
  }

  hashCode(): string {
    return String(this._id);
  }
}

// Domain Entity Example
class User extends Entity<UserId> {
  private _email: Email;
  private _name: Name;
  private _status: UserStatus;
  private _createdAt: Date;
  private _updatedAt: Date;

  private constructor(
    id: UserId,
    email: Email,
    name: Name,
    status: UserStatus
  ) {
    super(id);
    this._email = email;
    this._name = name;
    this._status = status;
    this._createdAt = new Date();
    this._updatedAt = new Date();
  }

  // Factory method - encapsulates creation logic
  static create(email: Email, name: Name): Result<User, ValidationError> {
    const id = UserId.generate();
    return Result.ok(new User(id, email, name, UserStatus.Active));
  }

  // Reconstitution from persistence
  static reconstitute(
    id: UserId,
    email: Email,
    name: Name,
    status: UserStatus,
    createdAt: Date,
    updatedAt: Date
  ): User {
    const user = new User(id, email, name, status);
    user._createdAt = createdAt;
    user._updatedAt = updatedAt;
    return user;
  }

  // Domain behavior with invariant protection
  changeEmail(newEmail: Email): Result<void, DomainError> {
    if (this._status === UserStatus.Deactivated) {
      return Result.fail(new DomainError('Cannot change email of deactivated user'));
    }
    this._email = newEmail;
    this._updatedAt = new Date();
    return Result.ok(undefined);
  }

  deactivate(): Result<void, DomainError> {
    if (this._status === UserStatus.Deactivated) {
      return Result.fail(new DomainError('User already deactivated'));
    }
    this._status = UserStatus.Deactivated;
    this._updatedAt = new Date();
    return Result.ok(undefined);
  }

  // Getters - expose state without setters
  get email(): Email { return this._email; }
  get name(): Name { return this._name; }
  get status(): UserStatus { return this._status; }
  get isActive(): boolean { return this._status === UserStatus.Active; }
}

// Strongly-typed ID (Value Object)
class UserId {
  private readonly _value: string;

  private constructor(value: string) {
    this._value = value;
  }

  static generate(): UserId {
    return new UserId(crypto.randomUUID());
  }

  static from(value: string): Result<UserId, ValidationError> {
    if (!value || value.trim() === '') {
      return Result.fail(new ValidationError('UserId cannot be empty'));
    }
    return Result.ok(new UserId(value));
  }

  get value(): string { return this._value; }

  equals(other: UserId): boolean {
    return this._value === other._value;
  }
}
```

## OOP vs FP Comparison

| Aspect | OOP Entity | FP Entity |
|--------|-----------|-----------|
| Identity | Encapsulated in class | Separate ID type |
| State | Private mutable fields | Immutable record |
| Behavior | Instance methods | Pure functions |
| Updates | Mutate in place | Return new instance |

```typescript
// FP-style Entity using fp-ts
import { pipe } from 'fp-ts/function';
import * as E from 'fp-ts/Either';

type User = Readonly<{
  id: UserId;
  email: Email;
  name: Name;
  status: UserStatus;
  createdAt: Date;
  updatedAt: Date;
}>;

const changeEmail = (newEmail: Email) => (user: User): E.Either<DomainError, User> =>
  user.status === 'deactivated'
    ? E.left(new DomainError('Cannot change email of deactivated user'))
    : E.right({ ...user, email: newEmail, updatedAt: new Date() });

const deactivate = (user: User): E.Either<DomainError, User> =>
  user.status === 'deactivated'
    ? E.left(new DomainError('User already deactivated'))
    : E.right({ ...user, status: 'deactivated' as UserStatus, updatedAt: new Date() });
```

## Recommended Libraries

| Library | Purpose | Link |
|---------|---------|------|
| **uuid** | ID generation | `npm i uuid` |
| **nanoid** | Compact IDs | `npm i nanoid` |
| **ts-results** | Result type | `npm i ts-results` |
| **Effect** | Full FP stack | `npm i effect` |

## Anti-patterns

1. **Anemic Entity**: Entity with only getters/setters, no behavior
   ```typescript
   // BAD - No domain logic
   class User {
     id: string;
     email: string; // Public setter!
     name: string;
   }
   ```

2. **Primitive Obsession**: Using primitives instead of Value Objects for identity
   ```typescript
   // BAD
   class User extends Entity<string> { }

   // GOOD
   class User extends Entity<UserId> { }
   ```

3. **Missing Invariant Protection**: Allowing invalid state transitions
   ```typescript
   // BAD - No validation
   user.status = UserStatus.Deactivated;

   // GOOD - Controlled transition
   user.deactivate();
   ```

4. **Identity Confusion**: Comparing entities by attributes instead of ID
   ```typescript
   // BAD
   user1.email === user2.email

   // GOOD
   user1.equals(user2) // or user1.id.equals(user2.id)
   ```

## When to Use

- Object needs to be tracked through time
- Object has a lifecycle (create, update, delete)
- Two objects with same attributes should be distinguishable
- Business operations depend on object history

## See Also

- [Value Object](./value-object.md) - For objects defined by attributes
- [Aggregate](./aggregate.md) - For clustering entities
- [Repository](./repository.md) - For entity persistence
