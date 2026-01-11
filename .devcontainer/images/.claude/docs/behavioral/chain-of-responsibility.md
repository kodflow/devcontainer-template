# Chain of Responsibility Pattern

> Passer une requete le long d'une chaine de handlers.

## Intention

Eviter de coupler l'emetteur d'une requete a son recepteur en permettant
a plusieurs objets de traiter la requete. Chainer les objets recepteurs
et passer la requete jusqu'a ce qu'un objet la traite.

## Structure

```typescript
// 1. Interface Handler
interface Handler<T, R> {
  setNext(handler: Handler<T, R>): Handler<T, R>;
  handle(request: T): R | null;
}

// 2. Abstract Handler
abstract class AbstractHandler<T, R> implements Handler<T, R> {
  private nextHandler: Handler<T, R> | null = null;

  setNext(handler: Handler<T, R>): Handler<T, R> {
    this.nextHandler = handler;
    return handler; // Permet le chainage fluent
  }

  handle(request: T): R | null {
    if (this.nextHandler) {
      return this.nextHandler.handle(request);
    }
    return null;
  }
}

// 3. Request type
interface HttpRequest {
  method: string;
  path: string;
  headers: Record<string, string>;
  body?: unknown;
  user?: User;
}

interface HttpResponse {
  status: number;
  body: unknown;
}

// 4. Concrete Handlers (Middleware pattern)
class AuthenticationHandler extends AbstractHandler<HttpRequest, HttpResponse> {
  handle(request: HttpRequest): HttpResponse | null {
    const token = request.headers['authorization']?.replace('Bearer ', '');

    if (!token) {
      return { status: 401, body: { error: 'No token provided' } };
    }

    try {
      request.user = this.verifyToken(token);
      return super.handle(request); // Passe au suivant
    } catch {
      return { status: 401, body: { error: 'Invalid token' } };
    }
  }

  private verifyToken(token: string): User {
    // Verification JWT
    return { id: '1', role: 'user' };
  }
}

class AuthorizationHandler extends AbstractHandler<HttpRequest, HttpResponse> {
  constructor(private allowedRoles: string[]) {
    super();
  }

  handle(request: HttpRequest): HttpResponse | null {
    if (!request.user) {
      return { status: 401, body: { error: 'Not authenticated' } };
    }

    if (!this.allowedRoles.includes(request.user.role)) {
      return { status: 403, body: { error: 'Access denied' } };
    }

    return super.handle(request);
  }
}

class ValidationHandler extends AbstractHandler<HttpRequest, HttpResponse> {
  constructor(private schema: Schema) {
    super();
  }

  handle(request: HttpRequest): HttpResponse | null {
    const errors = this.schema.validate(request.body);

    if (errors.length > 0) {
      return { status: 400, body: { errors } };
    }

    return super.handle(request);
  }
}

class RateLimitHandler extends AbstractHandler<HttpRequest, HttpResponse> {
  private requests = new Map<string, number[]>();

  constructor(
    private limit: number,
    private windowMs: number,
  ) {
    super();
  }

  handle(request: HttpRequest): HttpResponse | null {
    const clientId = request.headers['x-client-id'] || 'anonymous';
    const now = Date.now();
    const windowStart = now - this.windowMs;

    // Nettoyer les anciennes requetes
    const clientRequests = (this.requests.get(clientId) || []).filter(
      time => time > windowStart,
    );

    if (clientRequests.length >= this.limit) {
      return {
        status: 429,
        body: { error: 'Too many requests' },
      };
    }

    clientRequests.push(now);
    this.requests.set(clientId, clientRequests);

    return super.handle(request);
  }
}

class LoggingHandler extends AbstractHandler<HttpRequest, HttpResponse> {
  handle(request: HttpRequest): HttpResponse | null {
    console.log(`[${new Date().toISOString()}] ${request.method} ${request.path}`);

    const response = super.handle(request);

    if (response) {
      console.log(`Response: ${response.status}`);
    }

    return response;
  }
}

// 5. Final Handler (Controller)
class RequestHandler extends AbstractHandler<HttpRequest, HttpResponse> {
  constructor(
    private controller: (req: HttpRequest) => HttpResponse,
  ) {
    super();
  }

  handle(request: HttpRequest): HttpResponse {
    return this.controller(request);
  }
}
```

## Usage

```typescript
// Configuration de la chaine
const createUserSchema = { validate: (body: unknown) => [] };

const chain = new LoggingHandler();
chain
  .setNext(new RateLimitHandler(100, 60000))
  .setNext(new AuthenticationHandler())
  .setNext(new AuthorizationHandler(['admin']))
  .setNext(new ValidationHandler(createUserSchema))
  .setNext(
    new RequestHandler(req => ({
      status: 201,
      body: { message: 'User created', userId: '123' },
    })),
  );

// Traitement d'une requete
const request: HttpRequest = {
  method: 'POST',
  path: '/api/users',
  headers: {
    authorization: 'Bearer valid-token',
    'x-client-id': 'client-1',
  },
  body: { name: 'John', email: 'john@example.com' },
};

const response = chain.handle(request);
console.log(response);
```

## Variantes

### Chain avec fonction next explicite

```typescript
type Middleware = (
  request: HttpRequest,
  response: HttpResponse,
  next: () => void,
) => void;

class MiddlewareChain {
  private middlewares: Middleware[] = [];

  use(middleware: Middleware): this {
    this.middlewares.push(middleware);
    return this;
  }

  execute(request: HttpRequest): HttpResponse {
    const response: HttpResponse = { status: 200, body: null };
    let index = 0;

    const next = () => {
      if (index < this.middlewares.length) {
        const middleware = this.middlewares[index++];
        middleware(request, response, next);
      }
    };

    next();
    return response;
  }
}

// Usage Express-like
const app = new MiddlewareChain();

app.use((req, res, next) => {
  console.log('Logging...');
  next();
});

app.use((req, res, next) => {
  if (!req.headers['authorization']) {
    res.status = 401;
    return; // Stop chain
  }
  next();
});

app.use((req, res, next) => {
  res.body = { message: 'Success' };
  next();
});
```

### Async Chain

```typescript
type AsyncHandler<T, R> = (request: T) => Promise<R | null>;

class AsyncChain<T, R> {
  private handlers: AsyncHandler<T, R>[] = [];

  use(handler: AsyncHandler<T, R>): this {
    this.handlers.push(handler);
    return this;
  }

  async handle(request: T): Promise<R | null> {
    for (const handler of this.handlers) {
      const result = await handler(request);
      if (result !== null) {
        return result; // Handler a traite la requete
      }
    }
    return null; // Aucun handler n'a traite
  }
}

// Usage
const asyncChain = new AsyncChain<HttpRequest, HttpResponse>();

asyncChain.use(async req => {
  // Check cache
  const cached = await cache.get(req.path);
  return cached ? { status: 200, body: cached } : null;
});

asyncChain.use(async req => {
  // Fetch from database
  const data = await db.query(req.path);
  await cache.set(req.path, data);
  return { status: 200, body: data };
});
```

### Chain avec priorite

```typescript
interface PriorityHandler<T, R> {
  priority: number;
  canHandle(request: T): boolean;
  handle(request: T): R;
}

class PriorityChain<T, R> {
  private handlers: PriorityHandler<T, R>[] = [];

  register(handler: PriorityHandler<T, R>): void {
    this.handlers.push(handler);
    this.handlers.sort((a, b) => b.priority - a.priority);
  }

  handle(request: T): R | null {
    for (const handler of this.handlers) {
      if (handler.canHandle(request)) {
        return handler.handle(request);
      }
    }
    return null;
  }
}
```

## Anti-patterns

```typescript
// MAUVAIS: Chaine trop longue
const chain = new Handler1();
chain
  .setNext(new Handler2())
  .setNext(new Handler3())
  // ... 20 handlers ...
  .setNext(new Handler20()); // Difficile a debugger

// MAUVAIS: Handler qui ne passe jamais au suivant
class GreedyHandler extends AbstractHandler<Request, Response> {
  handle(request: Request): Response {
    // Traite TOUJOURS, ne passe jamais au suivant
    return { status: 200, body: 'Always me' };
  }
}

// MAUVAIS: Dependance a l'ordre non documentee
class OrderDependentHandler extends AbstractHandler<Request, Response> {
  handle(request: Request): Response | null {
    // Suppose que AuthHandler a deja ete execute
    // Sans documentation, c'est fragile
    const user = request.user!;
    return super.handle(request);
  }
}

// MAUVAIS: Modification de la chaine pendant l'execution
class DynamicHandler extends AbstractHandler<Request, Response> {
  handle(request: Request): Response | null {
    if (someCondition) {
      this.setNext(new AnotherHandler()); // Dangereux!
    }
    return super.handle(request);
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('Chain of Responsibility', () => {
  describe('AuthenticationHandler', () => {
    it('should reject requests without token', () => {
      const handler = new AuthenticationHandler();
      const request: HttpRequest = {
        method: 'GET',
        path: '/api/data',
        headers: {},
      };

      const response = handler.handle(request);

      expect(response?.status).toBe(401);
    });

    it('should pass authenticated requests to next', () => {
      const nextHandler = {
        handle: vi.fn().mockReturnValue({ status: 200, body: 'ok' }),
        setNext: vi.fn(),
      };

      const handler = new AuthenticationHandler();
      handler.setNext(nextHandler);

      const request: HttpRequest = {
        method: 'GET',
        path: '/api/data',
        headers: { authorization: 'Bearer valid-token' },
      };

      handler.handle(request);

      expect(nextHandler.handle).toHaveBeenCalled();
      expect(request.user).toBeDefined();
    });
  });

  describe('RateLimitHandler', () => {
    it('should allow requests within limit', () => {
      const handler = new RateLimitHandler(3, 1000);
      handler.setNext(new RequestHandler(() => ({ status: 200, body: 'ok' })));

      const request: HttpRequest = {
        method: 'GET',
        path: '/api',
        headers: { 'x-client-id': 'test' },
      };

      const r1 = handler.handle(request);
      const r2 = handler.handle(request);
      const r3 = handler.handle(request);

      expect(r1?.status).toBe(200);
      expect(r2?.status).toBe(200);
      expect(r3?.status).toBe(200);
    });

    it('should reject requests over limit', () => {
      const handler = new RateLimitHandler(2, 10000);
      handler.setNext(new RequestHandler(() => ({ status: 200, body: 'ok' })));

      const request: HttpRequest = {
        method: 'GET',
        path: '/api',
        headers: { 'x-client-id': 'test' },
      };

      handler.handle(request);
      handler.handle(request);
      const response = handler.handle(request);

      expect(response?.status).toBe(429);
    });
  });

  describe('Full Chain', () => {
    it('should process request through all handlers', () => {
      const chain = new LoggingHandler();
      const finalHandler = vi.fn().mockReturnValue({ status: 200, body: 'done' });

      chain
        .setNext(new AuthenticationHandler())
        .setNext(new RequestHandler(finalHandler));

      const request: HttpRequest = {
        method: 'GET',
        path: '/api/data',
        headers: { authorization: 'Bearer token' },
      };

      const response = chain.handle(request);

      expect(response?.status).toBe(200);
      expect(finalHandler).toHaveBeenCalled();
    });

    it('should stop at first error', () => {
      const chain = new AuthenticationHandler();
      const shouldNotBeCalled = vi.fn();

      chain.setNext(new RequestHandler(shouldNotBeCalled));

      const request: HttpRequest = {
        method: 'GET',
        path: '/api/data',
        headers: {}, // No auth
      };

      const response = chain.handle(request);

      expect(response?.status).toBe(401);
      expect(shouldNotBeCalled).not.toHaveBeenCalled();
    });
  });
});
```

## Quand utiliser

- Plusieurs handlers peuvent traiter une requete
- L'ensemble des handlers n'est pas connu a l'avance
- L'ordre de traitement importe
- Middleware pattern (HTTP, message queues)

## Patterns lies

- **Decorator** : Structure similaire, mais enrichit vs traite
- **Composite** : Peut combiner des chaines
- **Command** : Peut etre combine pour queuer des handlers

## Sources

- [Refactoring Guru - Chain of Responsibility](https://refactoring.guru/design-patterns/chain-of-responsibility)
