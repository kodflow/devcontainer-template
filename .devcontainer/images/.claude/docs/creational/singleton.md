# Singleton Pattern

> Garantir une instance unique d'une classe avec un point d'acces global.

## Intention

S'assurer qu'une classe n'a qu'une seule instance et fournir un point
d'acces global a cette instance.

## Structure classique

```typescript
class Database {
  private static instance: Database | null = null;
  private connection: Connection;

  // Constructeur prive
  private constructor() {
    this.connection = this.connect();
  }

  private connect(): Connection {
    console.log('Connecting to database...');
    return new Connection();
  }

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }

  query(sql: string): Result {
    return this.connection.execute(sql);
  }
}

// Usage
const db1 = Database.getInstance();
const db2 = Database.getInstance();
console.log(db1 === db2); // true
```

## Variantes

### Singleton Thread-safe (pour environnements concurrents)

```typescript
class ThreadSafeDatabase {
  private static instance: ThreadSafeDatabase | null = null;
  private static lock = new Mutex();

  private constructor() {}

  static async getInstance(): Promise<ThreadSafeDatabase> {
    if (!ThreadSafeDatabase.instance) {
      await ThreadSafeDatabase.lock.acquire();
      try {
        // Double-check locking
        if (!ThreadSafeDatabase.instance) {
          ThreadSafeDatabase.instance = new ThreadSafeDatabase();
        }
      } finally {
        ThreadSafeDatabase.lock.release();
      }
    }
    return ThreadSafeDatabase.instance;
  }
}
```

### Singleton avec initialisation paresseuse (Lazy)

```typescript
class LazyLogger {
  private static _instance: LazyLogger;

  private constructor(private logLevel: string) {}

  static get instance(): LazyLogger {
    // Initialise seulement au premier acces
    return this._instance ??= new LazyLogger('INFO');
  }

  log(message: string): void {
    console.log(`[${this.logLevel}] ${message}`);
  }
}
```

### Singleton avec configuration

```typescript
interface ConfigOptions {
  host: string;
  port: number;
  debug: boolean;
}

class ConfigManager {
  private static instance: ConfigManager;
  private config: ConfigOptions;

  private constructor(options: ConfigOptions) {
    this.config = options;
  }

  static initialize(options: ConfigOptions): ConfigManager {
    if (ConfigManager.instance) {
      throw new Error('ConfigManager already initialized');
    }
    ConfigManager.instance = new ConfigManager(options);
    return ConfigManager.instance;
  }

  static getInstance(): ConfigManager {
    if (!ConfigManager.instance) {
      throw new Error('ConfigManager not initialized');
    }
    return ConfigManager.instance;
  }

  get(key: keyof ConfigOptions): ConfigOptions[typeof key] {
    return this.config[key];
  }
}

// Usage
ConfigManager.initialize({ host: 'localhost', port: 3000, debug: true });
const config = ConfigManager.getInstance();
console.log(config.get('host')); // localhost
```

## Pourquoi Singleton est souvent un anti-pattern

```typescript
// PROBLEMES:

// 1. Etat global cache - difficile a tracer
class OrderService {
  process(order: Order) {
    // D'ou vient cette dependance? Invisible dans la signature
    Database.getInstance().save(order);
    Logger.getInstance().log('Order processed');
  }
}

// 2. Couplage fort - difficile a tester
class UserService {
  getUser(id: string) {
    // Comment mocker Database dans les tests?
    return Database.getInstance().query(`SELECT * FROM users WHERE id=${id}`);
  }
}

// 3. Violation du SRP - gere son cycle de vie + sa logique
class BadSingleton {
  private static instance: BadSingleton;
  static getInstance() { /* ... */ }  // Responsabilite 1: cycle de vie
  processData() { /* ... */ }          // Responsabilite 2: logique metier
}

// 4. Problemes de concurrence dans les tests
// Les tests partagent la meme instance = effets de bord
```

## Alternatives modernes

### Dependency Injection (recommande)

```typescript
// 1. Interface pour l'abstraction
interface IDatabase {
  query(sql: string): Result;
}

// 2. Implementation concrete
class Database implements IDatabase {
  constructor(private connectionString: string) {}
  query(sql: string): Result { /* ... */ }
}

// 3. Container DI
class Container {
  private services = new Map<string, unknown>();

  registerSingleton<T>(token: string, instance: T): void {
    this.services.set(token, instance);
  }

  resolve<T>(token: string): T {
    const service = this.services.get(token);
    if (!service) throw new Error(`Service ${token} not found`);
    return service as T;
  }
}

// 4. Configuration
const container = new Container();
container.registerSingleton<IDatabase>('database', new Database('...'));

// 5. Usage - dependances explicites
class UserService {
  constructor(private db: IDatabase) {}

  getUser(id: string): User {
    return this.db.query(`SELECT * FROM users WHERE id=${id}`);
  }
}

const userService = new UserService(container.resolve('database'));
```

### Module pattern (ES modules)

```typescript
// database.ts
const connection = createConnection();

export const query = (sql: string): Result => {
  return connection.execute(sql);
};

export const close = (): void => {
  connection.close();
};

// Usage - le module est naturellement singleton
import { query } from './database';
query('SELECT * FROM users');
```

### Factory avec scope

```typescript
class ServiceFactory {
  private instances = new Map<string, unknown>();

  singleton<T>(key: string, factory: () => T): T {
    if (!this.instances.has(key)) {
      this.instances.set(key, factory());
    }
    return this.instances.get(key) as T;
  }

  transient<T>(factory: () => T): T {
    return factory();
  }

  scoped<T>(scope: string, key: string, factory: () => T): T {
    const scopeKey = `${scope}:${key}`;
    if (!this.instances.has(scopeKey)) {
      this.instances.set(scopeKey, factory());
    }
    return this.instances.get(scopeKey) as T;
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest';

// Test du Singleton classique (difficile)
describe('Database Singleton', () => {
  beforeEach(() => {
    // Reset necessaire entre les tests - HACK
    (Database as any).instance = null;
  });

  it('should return same instance', () => {
    const db1 = Database.getInstance();
    const db2 = Database.getInstance();
    expect(db1).toBe(db2);
  });
});

// Test avec DI (facile)
describe('UserService with DI', () => {
  it('should query database', () => {
    // Mock facile a injecter
    const mockDb: IDatabase = {
      query: vi.fn().mockReturnValue({ id: '1', name: 'John' }),
    };

    const service = new UserService(mockDb);
    const user = service.getUser('1');

    expect(mockDb.query).toHaveBeenCalledWith(
      "SELECT * FROM users WHERE id='1'"
    );
    expect(user.name).toBe('John');
  });
});

// Test du module pattern
describe('Database module', () => {
  it('should execute queries', async () => {
    // Le module peut exporter une fonction reset pour les tests
    const result = await query('SELECT 1');
    expect(result).toBeDefined();
  });
});
```

## Quand utiliser (vraiment)

- Ressources partagees couteuses (pool de connexions)
- Configuration globale de l'application
- Cache applicatif
- Logger (mais preferer DI)

## Quand eviter

- Quand la testabilite est importante
- Quand plusieurs configurations sont possibles
- Dans les bibliotheques (imposer un singleton aux utilisateurs)
- Quand l'etat global cree du couplage

## Decision : Singleton vs DI

| Critere | Singleton | DI Container |
|---------|-----------|--------------|
| Simplicite initiale | Oui | Non |
| Testabilite | Difficile | Facile |
| Flexibilite | Faible | Elevee |
| Couplage | Fort | Faible |
| Configuration | Statique | Dynamique |

## Patterns lies

- **Factory** : Controle la creation du Singleton
- **Facade** : Souvent implemente comme Singleton
- **Service Locator** : Alternative au DI (mais anti-pattern similaire)

## Sources

- [Refactoring Guru - Singleton](https://refactoring.guru/design-patterns/singleton)
- [Mark Seemann - Service Locator is an Anti-Pattern](https://blog.ploeh.dk/2010/02/03/ServiceLocatorisanAnti-Pattern/)
