# Active Record

> "An object that wraps a row in a database table or view, encapsulates the database access, and adds domain logic on that data." - Martin Fowler, PoEAA

## Concept

Active Record combine les donnees et le comportement de persistance dans un seul objet. Chaque instance represente une ligne de la base de donnees et sait comment se sauvegarder, se charger et se supprimer.

## Caracteristiques

1. **Mapping 1:1** : Une classe = une table
2. **CRUD integre** : Methodes save(), find(), delete()
3. **Logique metier** : Peut contenir des validations et comportements
4. **Simplicite** : Pas de couche de mapping separee

## Implementation TypeScript

```typescript
// Base Active Record
abstract class ActiveRecord {
  protected static tableName: string;
  protected static db: Database;

  id?: string;
  createdAt?: Date;
  updatedAt?: Date;

  // Finders
  static async find<T extends ActiveRecord>(
    this: new () => T,
    id: string,
  ): Promise<T | null> {
    const row = await (this as any).db.queryOne(
      `SELECT * FROM ${(this as any).tableName} WHERE id = ?`,
      [id],
    );
    if (!row) return null;
    return (this as any).fromRow(row);
  }

  static async findAll<T extends ActiveRecord>(this: new () => T): Promise<T[]> {
    const rows = await (this as any).db.query(
      `SELECT * FROM ${(this as any).tableName}`,
    );
    return rows.map((row: any) => (this as any).fromRow(row));
  }

  static async findBy<T extends ActiveRecord>(
    this: new () => T,
    conditions: Partial<T>,
  ): Promise<T[]> {
    const keys = Object.keys(conditions);
    const where = keys.map((k) => `${this.toSnakeCase(k)} = ?`).join(' AND ');
    const values = Object.values(conditions);

    const rows = await (this as any).db.query(
      `SELECT * FROM ${(this as any).tableName} WHERE ${where}`,
      values,
    );
    return rows.map((row: any) => (this as any).fromRow(row));
  }

  // Persistence
  async save(): Promise<void> {
    this.validate();

    if (this.id) {
      await this.update();
    } else {
      await this.insert();
    }
  }

  async delete(): Promise<void> {
    if (!this.id) throw new Error('Cannot delete unsaved record');

    await (this.constructor as any).db.execute(
      `DELETE FROM ${(this.constructor as any).tableName} WHERE id = ?`,
      [this.id],
    );
  }

  // Override in subclasses
  protected validate(): void {
    // Default: no validation
  }

  protected abstract toRow(): Record<string, any>;
  protected static fromRow<T>(row: any): T {
    throw new Error('Must implement fromRow');
  }

  private async insert(): Promise<void> {
    this.id = crypto.randomUUID();
    this.createdAt = new Date();
    this.updatedAt = new Date();

    const row = this.toRow();
    const keys = Object.keys(row);
    const placeholders = keys.map(() => '?').join(', ');
    const columns = keys.map((k) => ActiveRecord.toSnakeCase(k)).join(', ');

    await (this.constructor as any).db.execute(
      `INSERT INTO ${(this.constructor as any).tableName} (${columns}) VALUES (${placeholders})`,
      Object.values(row),
    );
  }

  private async update(): Promise<void> {
    this.updatedAt = new Date();

    const row = this.toRow();
    const sets = Object.keys(row)
      .filter((k) => k !== 'id')
      .map((k) => `${ActiveRecord.toSnakeCase(k)} = ?`)
      .join(', ');
    const values = Object.values(row).filter((_, i) =>
      Object.keys(row)[i] !== 'id',
    );
    values.push(this.id);

    await (this.constructor as any).db.execute(
      `UPDATE ${(this.constructor as any).tableName} SET ${sets} WHERE id = ?`,
      values,
    );
  }

  private static toSnakeCase(str: string): string {
    return str.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);
  }
}

// Concrete Active Record
class User extends ActiveRecord {
  protected static tableName = 'users';

  email!: string;
  passwordHash!: string;
  role: string = 'user';
  lastLoginAt?: Date;

  // Domain logic
  static async findByEmail(email: string): Promise<User | null> {
    const users = await User.findBy<User>({ email });
    return users[0] || null;
  }

  async setPassword(password: string): Promise<void> {
    if (password.length < 8) {
      throw new ValidationError('Password must be at least 8 characters');
    }
    this.passwordHash = await bcrypt.hash(password, 10);
  }

  async checkPassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.passwordHash);
  }

  isAdmin(): boolean {
    return this.role === 'admin';
  }

  recordLogin(): void {
    this.lastLoginAt = new Date();
  }

  protected validate(): void {
    if (!this.email || !this.email.includes('@')) {
      throw new ValidationError('Invalid email');
    }
    if (!this.passwordHash) {
      throw new ValidationError('Password is required');
    }
  }

  protected toRow(): Record<string, any> {
    return {
      id: this.id,
      email: this.email,
      passwordHash: this.passwordHash,
      role: this.role,
      lastLoginAt: this.lastLoginAt,
      createdAt: this.createdAt,
      updatedAt: this.updatedAt,
    };
  }

  protected static fromRow(row: any): User {
    const user = new User();
    user.id = row.id;
    user.email = row.email;
    user.passwordHash = row.password_hash;
    user.role = row.role;
    user.lastLoginAt = row.last_login_at ? new Date(row.last_login_at) : undefined;
    user.createdAt = new Date(row.created_at);
    user.updatedAt = new Date(row.updated_at);
    return user;
  }
}

// Usage
const user = new User();
user.email = 'john@example.com';
await user.setPassword('securepassword123');
await user.save();

const found = await User.findByEmail('john@example.com');
if (found && await found.checkPassword('securepassword123')) {
  found.recordLogin();
  await found.save();
}
```

## Active Record avec Relations

```typescript
class Post extends ActiveRecord {
  protected static tableName = 'posts';

  title!: string;
  content!: string;
  authorId!: string;

  // Belongs To
  private _author?: User;
  async getAuthor(): Promise<User> {
    if (!this._author) {
      this._author = await User.find<User>(this.authorId);
    }
    return this._author!;
  }

  // Has Many
  async getComments(): Promise<Comment[]> {
    return Comment.findBy<Comment>({ postId: this.id });
  }

  // Factory with association
  static createForAuthor(author: User, title: string, content: string): Post {
    const post = new Post();
    post.authorId = author.id!;
    post.title = title;
    post.content = content;
    post._author = author;
    return post;
  }
}
```

## Comparaison avec alternatives

| Aspect | Active Record | Data Mapper | Table Gateway |
|--------|---------------|-------------|---------------|
| Couplage | Fort (DB in entity) | Faible | Moyen |
| Simplicite | Elevee | Faible | Moyenne |
| Testabilite | Moyenne | Elevee | Moyenne |
| Rich Domain | Difficile | Facile | Non applicable |
| Frameworks | Rails, Laravel, Django | Hibernate, Doctrine | - |

## Quand utiliser

**Utiliser Active Record quand :**

- Schema DB = modele objet (1:1)
- Logique metier simple a moderee
- Prototypage rapide
- Applications CRUD
- Equipe familiere avec Rails/Laravel

**Eviter Active Record quand :**

- Domain Model complexe avec invariants
- Schema DB different du modele objet
- Tests unitaires purs necessaires
- Logique metier riche

## Relation avec DDD

Active Record est **deconseille en DDD** car :

1. **Couplage fort** : L'entite connait sa persistance
2. **Testabilite reduite** : Besoin de DB pour tester
3. **Anemic tendance** : Logique migre vers services

```typescript
// Active Record = souvent Anemic Model
class Order extends ActiveRecord {
  status: string;
  items: OrderItem[];
  // Peu de logique metier ici
}

// Logique dans un service (anti-pattern DDD)
class OrderService {
  async submit(order: Order) {
    if (order.items.length === 0) throw new Error('Empty');
    order.status = 'submitted';
    await order.save();
  }
}

// DDD prefere Data Mapper + Rich Domain
class Order {
  submit(): void {
    if (this.items.length === 0) {
      throw new DomainError('Cannot submit empty order');
    }
    this.status = OrderStatus.Submitted;
  }
}
```

## Frameworks populaires

| Framework | Langage | Active Record |
|-----------|---------|---------------|
| Ruby on Rails | Ruby | ActiveRecord |
| Laravel | PHP | Eloquent |
| Django | Python | ORM Models |
| TypeORM | TypeScript | Active Record mode |
| Prisma | TypeScript | Data Mapper (pas AR) |

## Patterns associes

- **Row Data Gateway** : AR sans logique metier
- **Data Mapper** : Alternative avec separation
- **Table Data Gateway** : Operations par table
- **Repository** : Abstraction au-dessus d'AR

## Sources

- Martin Fowler, PoEAA, Chapter 10
- [Active Record - martinfowler.com](https://martinfowler.com/eaaCatalog/activeRecord.html)
- Rails Guides - Active Record Basics
