# Decorator Pattern

> Ajouter des comportements a un objet dynamiquement sans modifier sa classe.

## Intention

Attacher des responsabilites supplementaires a un objet de maniere dynamique.
Les decorateurs offrent une alternative flexible a l'heritage pour etendre
les fonctionnalites.

## Structure

```typescript
// 1. Interface composant
interface HttpClient {
  request(config: RequestConfig): Promise<Response>;
}

interface RequestConfig {
  url: string;
  method: string;
  headers?: Record<string, string>;
  body?: unknown;
}

// 2. Composant concret
class BasicHttpClient implements HttpClient {
  async request(config: RequestConfig): Promise<Response> {
    return fetch(config.url, {
      method: config.method,
      headers: config.headers,
      body: config.body ? JSON.stringify(config.body) : undefined,
    });
  }
}

// 3. Decorateur de base
abstract class HttpClientDecorator implements HttpClient {
  constructor(protected client: HttpClient) {}

  async request(config: RequestConfig): Promise<Response> {
    return this.client.request(config);
  }
}

// 4. Decorateurs concrets
class LoggingDecorator extends HttpClientDecorator {
  async request(config: RequestConfig): Promise<Response> {
    console.log(`[HTTP] ${config.method} ${config.url}`);
    const start = Date.now();

    const response = await super.request(config);

    console.log(`[HTTP] ${response.status} (${Date.now() - start}ms)`);
    return response;
  }
}

class AuthDecorator extends HttpClientDecorator {
  constructor(
    client: HttpClient,
    private tokenProvider: () => string,
  ) {
    super(client);
  }

  async request(config: RequestConfig): Promise<Response> {
    const token = this.tokenProvider();
    const headers = {
      ...config.headers,
      Authorization: `Bearer ${token}`,
    };
    return super.request({ ...config, headers });
  }
}

class RetryDecorator extends HttpClientDecorator {
  constructor(
    client: HttpClient,
    private maxRetries: number = 3,
    private delay: number = 1000,
  ) {
    super(client);
  }

  async request(config: RequestConfig): Promise<Response> {
    let lastError: Error | undefined;

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        const response = await super.request(config);
        if (response.ok || response.status < 500) {
          return response;
        }
        throw new Error(`HTTP ${response.status}`);
      } catch (error) {
        lastError = error as Error;
        if (attempt < this.maxRetries) {
          await this.sleep(this.delay * Math.pow(2, attempt));
        }
      }
    }
    throw lastError;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

class CacheDecorator extends HttpClientDecorator {
  private cache = new Map<string, { response: Response; expires: number }>();

  constructor(
    client: HttpClient,
    private ttl: number = 60000,
  ) {
    super(client);
  }

  async request(config: RequestConfig): Promise<Response> {
    if (config.method !== 'GET') {
      return super.request(config);
    }

    const key = config.url;
    const cached = this.cache.get(key);

    if (cached && cached.expires > Date.now()) {
      console.log('[CACHE] Hit:', key);
      return cached.response.clone();
    }

    const response = await super.request(config);
    this.cache.set(key, {
      response: response.clone(),
      expires: Date.now() + this.ttl,
    });

    return response;
  }
}
```

## Usage

```typescript
// Composition de decorateurs
let client: HttpClient = new BasicHttpClient();
client = new LoggingDecorator(client);
client = new AuthDecorator(client, () => 'my-token');
client = new RetryDecorator(client, 3);
client = new CacheDecorator(client, 30000);

// L'ordre est important!
// Cache -> Retry -> Auth -> Logging -> Basic

// Utilisation transparente
const response = await client.request({
  url: 'https://api.example.com/users',
  method: 'GET',
});
```

## Variantes

### Decorator avec TypeScript decorators

```typescript
function Log(
  target: object,
  propertyKey: string,
  descriptor: PropertyDescriptor,
) {
  const original = descriptor.value;

  descriptor.value = async function (...args: unknown[]) {
    console.log(`Calling ${propertyKey}`, args);
    const result = await original.apply(this, args);
    console.log(`Result of ${propertyKey}:`, result);
    return result;
  };

  return descriptor;
}

function Retry(attempts: number) {
  return function (
    target: object,
    propertyKey: string,
    descriptor: PropertyDescriptor,
  ) {
    const original = descriptor.value;

    descriptor.value = async function (...args: unknown[]) {
      for (let i = 0; i < attempts; i++) {
        try {
          return await original.apply(this, args);
        } catch (error) {
          if (i === attempts - 1) throw error;
        }
      }
    };

    return descriptor;
  };
}

class ApiService {
  @Log
  @Retry(3)
  async fetchUser(id: string): Promise<User> {
    return fetch(`/api/users/${id}`).then(r => r.json());
  }
}
```

### Functional Decorator

```typescript
type Middleware<T, R> = (next: (input: T) => Promise<R>) =>
  (input: T) => Promise<R>;

const logging: Middleware<RequestConfig, Response> = next => async config => {
  console.log('Request:', config);
  const response = await next(config);
  console.log('Response:', response.status);
  return response;
};

const auth =
  (token: string): Middleware<RequestConfig, Response> =>
  next =>
  async config => {
    return next({
      ...config,
      headers: { ...config.headers, Authorization: `Bearer ${token}` },
    });
  };

// Composition
const compose = <T, R>(
  ...middlewares: Middleware<T, R>[]
): Middleware<T, R> =>
  middlewares.reduce((acc, mw) => next => acc(mw(next)));

const enhancedFetch = compose(
  logging,
  auth('token'),
)(config => fetch(config.url, config));
```

## Cas d'usage concrets

### Streams decorators

```typescript
interface OutputStream {
  write(data: string): void;
  close(): void;
}

class FileOutputStream implements OutputStream {
  write(data: string) { /* ecrire dans fichier */ }
  close() { /* fermer fichier */ }
}

class BufferedOutputStream implements OutputStream {
  private buffer: string[] = [];

  constructor(
    private stream: OutputStream,
    private bufferSize: number = 1024,
  ) {}

  write(data: string) {
    this.buffer.push(data);
    if (this.buffer.join('').length >= this.bufferSize) {
      this.flush();
    }
  }

  flush() {
    this.stream.write(this.buffer.join(''));
    this.buffer = [];
  }

  close() {
    this.flush();
    this.stream.close();
  }
}

class CompressedOutputStream implements OutputStream {
  constructor(private stream: OutputStream) {}

  write(data: string) {
    const compressed = this.compress(data);
    this.stream.write(compressed);
  }

  close() { this.stream.close(); }
  private compress(data: string): string { /* ... */ return data; }
}

// Usage
const output = new CompressedOutputStream(
  new BufferedOutputStream(
    new FileOutputStream(),
  ),
);
```

## Anti-patterns

```typescript
// MAUVAIS: Decorateur qui modifie l'interface
class BadDecorator extends HttpClientDecorator {
  async request(config: RequestConfig): Promise<Response> {
    return super.request(config);
  }

  // Methode supplementaire = violation du pattern
  getStats(): Stats {
    return this.stats;
  }
}

// MAUVAIS: Ordre des decorateurs non documente
const client = new CacheDecorator(
  new AuthDecorator( // Cache avant Auth = tokens caches!
    new BasicHttpClient(),
    () => 'token',
  ),
);

// MAUVAIS: Decorateur avec etat partage
class StatefulDecorator extends HttpClientDecorator {
  private static count = 0; // Etat partage = problemes

  async request(config: RequestConfig) {
    StatefulDecorator.count++;
    return super.request(config);
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('LoggingDecorator', () => {
  it('should log requests and responses', async () => {
    const consoleSpy = vi.spyOn(console, 'log');
    const mockClient: HttpClient = {
      request: vi.fn().mockResolvedValue(new Response(null, { status: 200 })),
    };

    const decorator = new LoggingDecorator(mockClient);
    await decorator.request({ url: '/api', method: 'GET' });

    expect(consoleSpy).toHaveBeenCalledWith('[HTTP] GET /api');
    expect(consoleSpy).toHaveBeenCalledWith(expect.stringContaining('[HTTP] 200'));
  });
});

describe('RetryDecorator', () => {
  it('should retry failed requests', async () => {
    const mockClient: HttpClient = {
      request: vi
        .fn()
        .mockRejectedValueOnce(new Error('Network error'))
        .mockRejectedValueOnce(new Error('Network error'))
        .mockResolvedValue(new Response(null, { status: 200 })),
    };

    const decorator = new RetryDecorator(mockClient, 3, 10);
    const response = await decorator.request({ url: '/api', method: 'GET' });

    expect(mockClient.request).toHaveBeenCalledTimes(3);
    expect(response.status).toBe(200);
  });

  it('should throw after max retries', async () => {
    const mockClient: HttpClient = {
      request: vi.fn().mockRejectedValue(new Error('Always fails')),
    };

    const decorator = new RetryDecorator(mockClient, 2, 10);

    await expect(
      decorator.request({ url: '/api', method: 'GET' }),
    ).rejects.toThrow('Always fails');
  });
});

describe('Decorator composition', () => {
  it('should apply decorators in order', async () => {
    const order: string[] = [];

    const client: HttpClient = {
      request: vi.fn().mockImplementation(async () => {
        order.push('base');
        return new Response();
      }),
    };

    class FirstDecorator extends HttpClientDecorator {
      async request(config: RequestConfig) {
        order.push('first-before');
        const res = await super.request(config);
        order.push('first-after');
        return res;
      }
    }

    class SecondDecorator extends HttpClientDecorator {
      async request(config: RequestConfig) {
        order.push('second-before');
        const res = await super.request(config);
        order.push('second-after');
        return res;
      }
    }

    const decorated = new SecondDecorator(new FirstDecorator(client));
    await decorated.request({ url: '/', method: 'GET' });

    expect(order).toEqual([
      'second-before',
      'first-before',
      'base',
      'first-after',
      'second-after',
    ]);
  });
});
```

## Quand utiliser

- Ajouter des responsabilites sans modifier la classe
- Comportements combinables dynamiquement
- Extension impossible par heritage (classe sealed)
- Cross-cutting concerns (logging, caching, auth)

## Patterns lies

- **Adapter** : Change l'interface vs ajoute des comportements
- **Composite** : Structure arborescente vs chaine lineaire
- **Proxy** : Controle d'acces vs extension
- **Chain of Responsibility** : Pattern similaire pour handlers

## Sources

- [Refactoring Guru - Decorator](https://refactoring.guru/design-patterns/decorator)
