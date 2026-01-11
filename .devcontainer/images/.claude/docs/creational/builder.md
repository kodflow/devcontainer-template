# Builder Pattern

> Construire des objets complexes etape par etape avec une interface fluide.

## Intention

Separer la construction d'un objet complexe de sa representation, permettant
au meme processus de construction de creer differentes representations.

## Structure

```typescript
// 1. Produit complexe
interface HttpRequest {
  method: string;
  url: string;
  headers: Map<string, string>;
  body?: string;
  timeout?: number;
  retries?: number;
}

// 2. Interface Builder
interface RequestBuilder {
  setMethod(method: string): this;
  setUrl(url: string): this;
  addHeader(key: string, value: string): this;
  setBody(body: string): this;
  setTimeout(ms: number): this;
  setRetries(count: number): this;
  build(): HttpRequest;
}

// 3. Concrete Builder
class HttpRequestBuilder implements RequestBuilder {
  private request: Partial<HttpRequest> = {
    headers: new Map(),
  };

  setMethod(method: string): this {
    this.request.method = method;
    return this;
  }

  setUrl(url: string): this {
    this.request.url = url;
    return this;
  }

  addHeader(key: string, value: string): this {
    this.request.headers!.set(key, value);
    return this;
  }

  setBody(body: string): this {
    this.request.body = body;
    return this;
  }

  setTimeout(ms: number): this {
    this.request.timeout = ms;
    return this;
  }

  setRetries(count: number): this {
    this.request.retries = count;
    return this;
  }

  build(): HttpRequest {
    if (!this.request.method || !this.request.url) {
      throw new Error('Method and URL are required');
    }
    return { ...this.request } as HttpRequest;
  }
}

// 4. Director (optionnel)
class RequestDirector {
  constructor(private builder: RequestBuilder) {}

  buildGetRequest(url: string): HttpRequest {
    return this.builder
      .setMethod('GET')
      .setUrl(url)
      .setTimeout(5000)
      .build();
  }

  buildJsonPostRequest(url: string, data: object): HttpRequest {
    return this.builder
      .setMethod('POST')
      .setUrl(url)
      .addHeader('Content-Type', 'application/json')
      .setBody(JSON.stringify(data))
      .setTimeout(10000)
      .setRetries(3)
      .build();
  }
}
```

## Usage

```typescript
// Sans Director (fluent interface)
const request = new HttpRequestBuilder()
  .setMethod('POST')
  .setUrl('https://api.example.com/users')
  .addHeader('Authorization', 'Bearer token')
  .addHeader('Content-Type', 'application/json')
  .setBody(JSON.stringify({ name: 'John' }))
  .setTimeout(5000)
  .build();

// Avec Director
const director = new RequestDirector(new HttpRequestBuilder());
const getRequest = director.buildGetRequest('https://api.example.com/users');
const postRequest = director.buildJsonPostRequest(
  'https://api.example.com/users',
  { name: 'John' }
);
```

## Variantes

### Step Builder (validation a chaque etape)

```typescript
interface MethodStep {
  get(url: string): HeadersStep;
  post(url: string): BodyStep;
}

interface HeadersStep {
  withHeader(key: string, value: string): HeadersStep;
  build(): HttpRequest;
}

interface BodyStep {
  withBody(body: string): HeadersStep;
}

class StepBuilder implements MethodStep {
  get(url: string): HeadersStep {
    return new HeadersBuilder('GET', url);
  }
  post(url: string): BodyStep {
    return new BodyBuilder('POST', url);
  }
}
```

### Immutable Builder

```typescript
class ImmutableRequestBuilder {
  private constructor(private readonly config: Partial<HttpRequest>) {}

  static create(): ImmutableRequestBuilder {
    return new ImmutableRequestBuilder({});
  }

  withMethod(method: string): ImmutableRequestBuilder {
    return new ImmutableRequestBuilder({ ...this.config, method });
  }

  withUrl(url: string): ImmutableRequestBuilder {
    return new ImmutableRequestBuilder({ ...this.config, url });
  }

  build(): HttpRequest {
    return { ...this.config } as HttpRequest;
  }
}
```

## Anti-patterns

```typescript
// MAUVAIS: Constructeur telescopique
class Request {
  constructor(
    method: string,
    url: string,
    headers?: Map<string, string>,
    body?: string,
    timeout?: number,
    retries?: number,
    // ... 10 autres parametres
  ) {}
}

// MAUVAIS: Builder sans validation
class BadBuilder {
  build(): Request {
    // Retourne un objet potentiellement invalide
    return this.request as Request;
  }
}

// MAUVAIS: Builder mutable reutilise
const builder = new RequestBuilder();
const req1 = builder.setUrl('/a').build();
const req2 = builder.setUrl('/b').build(); // req1 aussi modifie!
```

## Alternative moderne : Object literals + defaults

```typescript
interface RequestOptions {
  method?: string;
  url: string;
  headers?: Record<string, string>;
  timeout?: number;
}

const defaultOptions: Partial<RequestOptions> = {
  method: 'GET',
  timeout: 5000,
};

function createRequest(options: RequestOptions): HttpRequest {
  return { ...defaultOptions, ...options } as HttpRequest;
}

// Usage simple pour cas simples
const req = createRequest({ url: '/api/users' });
```

## Tests unitaires

```typescript
import { describe, it, expect, beforeEach } from 'vitest';

describe('HttpRequestBuilder', () => {
  let builder: HttpRequestBuilder;

  beforeEach(() => {
    builder = new HttpRequestBuilder();
  });

  it('should build a valid GET request', () => {
    const request = builder
      .setMethod('GET')
      .setUrl('https://api.example.com')
      .build();

    expect(request.method).toBe('GET');
    expect(request.url).toBe('https://api.example.com');
  });

  it('should throw if method is missing', () => {
    expect(() => builder.setUrl('/api').build()).toThrow();
  });

  it('should accumulate headers', () => {
    const request = builder
      .setMethod('GET')
      .setUrl('/api')
      .addHeader('Accept', 'application/json')
      .addHeader('Authorization', 'Bearer token')
      .build();

    expect(request.headers.size).toBe(2);
    expect(request.headers.get('Accept')).toBe('application/json');
  });

  it('should support fluent chaining', () => {
    const result = builder.setMethod('GET');
    expect(result).toBe(builder);
  });
});

describe('RequestDirector', () => {
  it('should build preconfigured GET requests', () => {
    const director = new RequestDirector(new HttpRequestBuilder());
    const request = director.buildGetRequest('/api/users');

    expect(request.method).toBe('GET');
    expect(request.timeout).toBe(5000);
  });
});
```

## Quand utiliser

- Objets avec de nombreux parametres optionnels
- Construction complexe en plusieurs etapes
- Meme processus pour differentes representations
- Immutabilite souhaitee pendant la construction

## Patterns lies

- **Abstract Factory** : Peut utiliser Builder pour creer des produits
- **Prototype** : Alternative quand le clonage est plus simple
- **Fluent Interface** : Technique utilisee par Builder

## Sources

- [Refactoring Guru - Builder](https://refactoring.guru/design-patterns/builder)
- [Effective Java - Item 2](https://www.oreilly.com/library/view/effective-java/9780134686097/)
