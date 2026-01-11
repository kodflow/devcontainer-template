# Proxy Pattern

> Fournir un substitut ou placeholder pour controler l'acces a un objet.

## Intention

Fournir un intermediaire pour un autre objet afin de controler l'acces,
reduire le cout, ou ajouter des fonctionnalites sans modifier l'objet original.

## Types de Proxy

### 1. Virtual Proxy (Lazy Loading)

```typescript
interface Image {
  display(): void;
  getSize(): { width: number; height: number };
}

class RealImage implements Image {
  private data: Buffer;

  constructor(private filename: string) {
    this.loadFromDisk(); // Couteux!
  }

  private loadFromDisk(): void {
    console.log(`Loading image: ${this.filename}`);
    // Simulation chargement lourd
    this.data = Buffer.alloc(1024 * 1024 * 10); // 10MB
  }

  display(): void {
    console.log(`Displaying: ${this.filename}`);
  }

  getSize(): { width: number; height: number } {
    return { width: 1920, height: 1080 };
  }
}

class ImageProxy implements Image {
  private realImage: RealImage | null = null;

  constructor(private filename: string) {}

  private ensureLoaded(): RealImage {
    if (!this.realImage) {
      this.realImage = new RealImage(this.filename);
    }
    return this.realImage;
  }

  display(): void {
    this.ensureLoaded().display();
  }

  // Metadata accessible sans charger l'image
  getSize(): { width: number; height: number } {
    // Lire seulement les headers du fichier
    return { width: 1920, height: 1080 };
  }
}
```

### 2. Protection Proxy (Controle d'acces)

```typescript
interface Document {
  read(): string;
  write(content: string): void;
  delete(): void;
}

interface User {
  id: string;
  role: 'admin' | 'editor' | 'viewer';
}

class RealDocument implements Document {
  constructor(
    private id: string,
    private content: string,
  ) {}

  read(): string {
    return this.content;
  }

  write(content: string): void {
    this.content = content;
  }

  delete(): void {
    console.log(`Document ${this.id} deleted`);
  }
}

class ProtectedDocument implements Document {
  constructor(
    private document: Document,
    private currentUser: User,
  ) {}

  read(): string {
    // Tout le monde peut lire
    return this.document.read();
  }

  write(content: string): void {
    if (this.currentUser.role === 'viewer') {
      throw new Error('Permission denied: viewers cannot write');
    }
    this.document.write(content);
  }

  delete(): void {
    if (this.currentUser.role !== 'admin') {
      throw new Error('Permission denied: only admins can delete');
    }
    this.document.delete();
  }
}
```

### 3. Remote Proxy (RPC/API)

```typescript
interface UserService {
  getUser(id: string): Promise<User>;
  updateUser(id: string, data: Partial<User>): Promise<User>;
}

class RemoteUserService implements UserService {
  constructor(private baseUrl: string) {}

  async getUser(id: string): Promise<User> {
    const response = await fetch(`${this.baseUrl}/users/${id}`);
    if (!response.ok) {
      throw new Error(`User not found: ${id}`);
    }
    return response.json();
  }

  async updateUser(id: string, data: Partial<User>): Promise<User> {
    const response = await fetch(`${this.baseUrl}/users/${id}`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return response.json();
  }
}

// Le client utilise l'interface comme si c'etait local
class UserController {
  constructor(private userService: UserService) {}

  async showProfile(userId: string): Promise<void> {
    const user = await this.userService.getUser(userId);
    console.log(`Profile: ${user.name}`);
  }
}
```

### 4. Cache Proxy

```typescript
interface DataService {
  fetchData(key: string): Promise<Data>;
}

class CachedDataService implements DataService {
  private cache = new Map<string, { data: Data; expires: number }>();

  constructor(
    private service: DataService,
    private ttl: number = 60000,
  ) {}

  async fetchData(key: string): Promise<Data> {
    const cached = this.cache.get(key);

    if (cached && cached.expires > Date.now()) {
      console.log(`Cache hit: ${key}`);
      return cached.data;
    }

    console.log(`Cache miss: ${key}`);
    const data = await this.service.fetchData(key);

    this.cache.set(key, {
      data,
      expires: Date.now() + this.ttl,
    });

    return data;
  }

  invalidate(key: string): void {
    this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }
}
```

### 5. Logging Proxy

```typescript
interface Database {
  query(sql: string): Promise<Result>;
  execute(sql: string): Promise<number>;
}

class LoggingDatabaseProxy implements Database {
  constructor(
    private db: Database,
    private logger: Logger,
  ) {}

  async query(sql: string): Promise<Result> {
    const start = Date.now();
    this.logger.debug(`Query: ${sql}`);

    try {
      const result = await this.db.query(sql);
      this.logger.info(`Query completed in ${Date.now() - start}ms`);
      return result;
    } catch (error) {
      this.logger.error(`Query failed: ${error}`);
      throw error;
    }
  }

  async execute(sql: string): Promise<number> {
    this.logger.debug(`Execute: ${sql}`);
    return this.db.execute(sql);
  }
}
```

## Variantes avancees

### Smart Reference Proxy

```typescript
class SmartReference<T extends object> {
  private references = 0;
  private instance: T | null = null;

  constructor(private factory: () => T) {}

  acquire(): T {
    if (!this.instance) {
      this.instance = this.factory();
    }
    this.references++;
    return this.instance;
  }

  release(): void {
    this.references--;
    if (this.references === 0 && this.instance) {
      console.log('No more references, cleaning up');
      this.instance = null;
    }
  }
}
```

### ES6 Proxy (JavaScript natif)

```typescript
function createLoggingProxy<T extends object>(target: T): T {
  return new Proxy(target, {
    get(obj, prop) {
      console.log(`Accessing: ${String(prop)}`);
      const value = Reflect.get(obj, prop);
      return typeof value === 'function' ? value.bind(obj) : value;
    },

    set(obj, prop, value) {
      console.log(`Setting: ${String(prop)} = ${value}`);
      return Reflect.set(obj, prop, value);
    },
  });
}

const user = createLoggingProxy({ name: 'John', age: 30 });
console.log(user.name); // Logs: Accessing: name
user.age = 31; // Logs: Setting: age = 31
```

### Validation Proxy

```typescript
interface Schema {
  [key: string]: {
    type: 'string' | 'number' | 'boolean';
    required?: boolean;
    min?: number;
    max?: number;
  };
}

function createValidatingProxy<T extends object>(target: T, schema: Schema): T {
  return new Proxy(target, {
    set(obj, prop, value) {
      const rule = schema[String(prop)];

      if (rule) {
        if (rule.required && (value === null || value === undefined)) {
          throw new Error(`${String(prop)} is required`);
        }

        if (typeof value !== rule.type) {
          throw new Error(
            `${String(prop)} must be ${rule.type}, got ${typeof value}`,
          );
        }

        if (rule.type === 'number') {
          if (rule.min !== undefined && value < rule.min) {
            throw new Error(`${String(prop)} must be >= ${rule.min}`);
          }
          if (rule.max !== undefined && value > rule.max) {
            throw new Error(`${String(prop)} must be <= ${rule.max}`);
          }
        }
      }

      return Reflect.set(obj, prop, value);
    },
  });
}
```

## Anti-patterns

```typescript
// MAUVAIS: Proxy qui change le comportement
class BadProxy implements UserService {
  async getUser(id: string): Promise<User> {
    // Modifie les donnees = pas un proxy!
    const user = await this.service.getUser(id);
    user.name = user.name.toUpperCase(); // Transformation
    return user;
  }
}

// MAUVAIS: Proxy avec logique metier
class BusinessLogicProxy implements OrderService {
  async createOrder(order: Order): Promise<Order> {
    // Calcul de prix = logique metier, pas proxy
    order.total = order.items.reduce((sum, i) => sum + i.price, 0);
    return this.service.createOrder(order);
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi } from 'vitest';

describe('ImageProxy', () => {
  it('should lazy load real image', () => {
    const loadSpy = vi.spyOn(RealImage.prototype, 'display');
    const proxy = new ImageProxy('test.jpg');

    // Pas encore charge
    expect(loadSpy).not.toHaveBeenCalled();

    // Charge au premier acces
    proxy.display();
    expect(loadSpy).toHaveBeenCalled();
  });

  it('should return metadata without loading', () => {
    const proxy = new ImageProxy('test.jpg');
    const size = proxy.getSize();

    expect(size).toEqual({ width: 1920, height: 1080 });
  });
});

describe('ProtectedDocument', () => {
  it('should allow viewers to read', () => {
    const doc = new RealDocument('1', 'content');
    const viewer: User = { id: '1', role: 'viewer' };
    const protected = new ProtectedDocument(doc, viewer);

    expect(protected.read()).toBe('content');
  });

  it('should deny viewers write access', () => {
    const doc = new RealDocument('1', 'content');
    const viewer: User = { id: '1', role: 'viewer' };
    const protected = new ProtectedDocument(doc, viewer);

    expect(() => protected.write('new')).toThrow('Permission denied');
  });
});

describe('CachedDataService', () => {
  it('should cache responses', async () => {
    const mockService: DataService = {
      fetchData: vi.fn().mockResolvedValue({ id: '1' }),
    };
    const cached = new CachedDataService(mockService, 10000);

    await cached.fetchData('key');
    await cached.fetchData('key');

    expect(mockService.fetchData).toHaveBeenCalledTimes(1);
  });

  it('should refresh expired cache', async () => {
    vi.useFakeTimers();
    const mockService: DataService = {
      fetchData: vi.fn().mockResolvedValue({ id: '1' }),
    };
    const cached = new CachedDataService(mockService, 1000);

    await cached.fetchData('key');
    vi.advanceTimersByTime(2000);
    await cached.fetchData('key');

    expect(mockService.fetchData).toHaveBeenCalledTimes(2);
    vi.useRealTimers();
  });
});
```

## Quand utiliser

| Type | Cas d'usage |
|------|-------------|
| Virtual | Objets couteux a creer |
| Protection | Controle d'acces/permissions |
| Remote | Appels reseau/RPC |
| Cache | Optimisation performance |
| Logging | Debug, monitoring |

## Patterns lies

- **Decorator** : Ajoute des comportements vs controle acces
- **Adapter** : Change l'interface vs meme interface
- **Facade** : Simplifie vs controle

## Sources

- [Refactoring Guru - Proxy](https://refactoring.guru/design-patterns/proxy)
