# Connection Pool

Pattern de gestion des connexions reseau reutilisables (DB, HTTP, etc.).

---

## Qu'est-ce que le Connection Pool ?

> Maintenir un ensemble de connexions pre-etablies pour eviter l'overhead de connexion.

```
+--------------------------------------------------------------+
|                    Connection Pool                            |
|                                                               |
|  Application                Pool                   Database   |
|      |                        |                        |      |
|      |-- acquire() --------->|                        |      |
|      |<-- connection --------|                        |      |
|      |                        |                        |      |
|      |== query() ============|== SQL ================>|      |
|      |<= result =============|<= data ================|      |
|      |                        |                        |      |
|      |-- release() --------->|                        |      |
|      |                   [kept alive]                  |      |
|                                                               |
|  +--------+  +--------+  +--------+  +--------+               |
|  | conn 1 |  | conn 2 |  | conn 3 |  | conn 4 |               |
|  | (busy) |  | (idle) |  | (idle) |  | (busy) |               |
|  +--------+  +--------+  +--------+  +--------+               |
+--------------------------------------------------------------+
```

**Pourquoi :**
- Eviter le handshake TCP/TLS a chaque requete
- Limiter le nombre de connexions au serveur
- Reduire la latence des requetes

---

## Implementation TypeScript

```typescript
interface PooledConnection {
  query<T>(sql: string, params?: unknown[]): Promise<T>;
  isAlive(): Promise<boolean>;
  close(): Promise<void>;
}

interface PoolConfig {
  minConnections: number;
  maxConnections: number;
  acquireTimeout: number;
  idleTimeout: number;
  connectionFactory: () => Promise<PooledConnection>;
}

class ConnectionPool {
  private idle: PooledConnection[] = [];
  private active = new Set<PooledConnection>();
  private waiting: Array<{
    resolve: (conn: PooledConnection) => void;
    reject: (err: Error) => void;
    timer: ReturnType<typeof setTimeout>;
  }> = [];

  constructor(private config: PoolConfig) {
    this.initPool();
    this.startIdleCheck();
  }

  private async initPool(): Promise<void> {
    const promises = Array(this.config.minConnections)
      .fill(null)
      .map(() => this.createConnection());

    const connections = await Promise.all(promises);
    this.idle.push(...connections);
  }

  private async createConnection(): Promise<PooledConnection> {
    return this.config.connectionFactory();
  }

  async acquire(): Promise<PooledConnection> {
    // 1. Connexion idle disponible
    while (this.idle.length > 0) {
      const conn = this.idle.pop()!;
      if (await conn.isAlive()) {
        this.active.add(conn);
        return conn;
      }
      // Connexion morte, on l'ignore
    }

    // 2. Creer nouvelle si possible
    if (this.totalConnections < this.config.maxConnections) {
      const conn = await this.createConnection();
      this.active.add(conn);
      return conn;
    }

    // 3. Attendre une liberation
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        const idx = this.waiting.findIndex((w) => w.resolve === resolve);
        if (idx >= 0) this.waiting.splice(idx, 1);
        reject(new Error('Acquire timeout'));
      }, this.config.acquireTimeout);

      this.waiting.push({ resolve, reject, timer });
    });
  }

  release(conn: PooledConnection): void {
    if (!this.active.delete(conn)) return;

    // Donner a un waiter si present
    const waiter = this.waiting.shift();
    if (waiter) {
      clearTimeout(waiter.timer);
      this.active.add(conn);
      waiter.resolve(conn);
      return;
    }

    // Sinon remettre en idle
    this.idle.push(conn);
  }

  async withConnection<T>(
    fn: (conn: PooledConnection) => Promise<T>,
  ): Promise<T> {
    const conn = await this.acquire();
    try {
      return await fn(conn);
    } finally {
      this.release(conn);
    }
  }

  private get totalConnections(): number {
    return this.idle.length + this.active.size;
  }

  private startIdleCheck(): void {
    setInterval(async () => {
      const now = Date.now();
      const toRemove: PooledConnection[] = [];

      for (const conn of this.idle) {
        if (!(await conn.isAlive())) {
          toRemove.push(conn);
        }
      }

      for (const conn of toRemove) {
        const idx = this.idle.indexOf(conn);
        if (idx >= 0) this.idle.splice(idx, 1);
        await conn.close();
      }
    }, this.config.idleTimeout);
  }

  async close(): Promise<void> {
    const all = [...this.idle, ...this.active];
    await Promise.all(all.map((c) => c.close()));
    this.idle = [];
    this.active.clear();
  }
}
```

---

## Configuration recommandee

```typescript
const poolConfig: PoolConfig = {
  minConnections: 5,        // Connexions maintenues au minimum
  maxConnections: 20,       // Limite absolue
  acquireTimeout: 30_000,   // 30s max d'attente
  idleTimeout: 60_000,      // Nettoyer idle apres 1min
  connectionFactory: async () => {
    const conn = new PostgresConnection(dbUrl);
    await conn.connect();
    return conn;
  },
};

const pool = new ConnectionPool(poolConfig);

// Usage
const users = await pool.withConnection(async (conn) => {
  return conn.query('SELECT * FROM users WHERE active = $1', [true]);
});
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Acquisition (idle dispo) | O(1) |
| Acquisition (creation) | O(handshake) |
| Liberation | O(1) |
| Memoire | O(maxConnections) |

### Avantages

- Latence reduite (pas de handshake)
- Limite la charge sur le serveur DB
- Gestion automatique des connexions mortes

### Inconvenients

- Connexions inutilisees consomment des ressources
- Complexite de configuration (sizing)
- Deadlock possible si pool trop petit

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Object Pool** | Generalisation |
| **Circuit Breaker** | Protection si serveur down |
| **Retry** | Resilience a l'acquisition |
| **Semaphore** | Limitation similaire |

---

## Sources

- [HikariCP](https://github.com/brettwooldridge/HikariCP) - Pool Java haute perf
- [node-postgres Pool](https://node-postgres.com/features/pooling)
- [Database Connection Pooling Best Practices](https://vladmihalcea.com/connection-pooling/)
