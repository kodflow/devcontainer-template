# Lazy Loading

Pattern differant l'initialisation d'une ressource jusqu'a son premier usage.

---

## Qu'est-ce que le Lazy Loading ?

> Ne charger/initialiser une ressource que lorsqu'elle est reellement necessaire.

```
+--------------------------------------------------------------+
|                     Lazy Loading                              |
|                                                               |
|  Premier acces:                                               |
|                                                               |
|  get() --> [null?] --> YES --> create() --> cache --> return  |
|                |                                              |
|                NO                                             |
|                |                                              |
|                +-----> return cached                          |
|                                                               |
|  Acces suivants:                                              |
|                                                               |
|  get() --> [cached] --> return (instantane)                   |
|                                                               |
+--------------------------------------------------------------+
```

**Pourquoi :**

- Reduire le temps de demarrage
- Economiser la memoire (ressources non utilisees)
- Eviter les effets de bord au chargement

---

## Implementation TypeScript

### Lazy Value basique

```typescript
class Lazy<T> {
  private value?: T;
  private initialized = false;

  constructor(private factory: () => T) {}

  get(): T {
    if (!this.initialized) {
      this.value = this.factory();
      this.initialized = true;
    }
    return this.value!;
  }

  get isInitialized(): boolean {
    return this.initialized;
  }

  reset(): void {
    this.value = undefined;
    this.initialized = false;
  }
}

// Usage
const expensiveResource = new Lazy(() => {
  console.log('Creating expensive resource...');
  return loadHugeDataset();
});

// Pas de chargement ici
console.log('App started');

// Chargement au premier acces
const data = expensiveResource.get();
```

### Lazy Async

```typescript
class LazyAsync<T> {
  private promise?: Promise<T>;
  private value?: T;
  private resolved = false;

  constructor(private factory: () => Promise<T>) {}

  async get(): Promise<T> {
    if (this.resolved) {
      return this.value!;
    }

    if (!this.promise) {
      this.promise = this.factory().then((v) => {
        this.value = v;
        this.resolved = true;
        return v;
      });
    }

    return this.promise;
  }
}

// Usage
const lazyDb = new LazyAsync(async () => {
  const conn = new DatabaseConnection();
  await conn.connect();
  return conn;
});

// Connexion seulement au premier appel
const db = await lazyDb.get();
```

### Lazy Property Decorator

```typescript
function lazy<T>(_target: object, propertyKey: string) {
  const privateKey = Symbol(propertyKey);

  return {
    get(this: any): T {
      if (!(privateKey in this)) {
        const factory = this[`${propertyKey}Factory`];
        this[privateKey] = factory.call(this);
      }
      return this[privateKey];
    },
  };
}

class Service {
  @lazy
  get config(): Config {
    return this.configFactory();
  }

  private configFactory(): Config {
    console.log('Loading config...');
    return loadConfigFromDisk();
  }
}
```

---

## Variantes du pattern

### 1. Virtual Proxy

```typescript
interface Image {
  display(): void;
  getWidth(): number;
}

class LazyImageProxy implements Image {
  private realImage?: RealImage;

  constructor(private filename: string) {}

  private loadImage(): RealImage {
    if (!this.realImage) {
      console.log(`Loading image: ${this.filename}`);
      this.realImage = new RealImage(this.filename);
    }
    return this.realImage;
  }

  display(): void {
    this.loadImage().display();
  }

  getWidth(): number {
    return this.loadImage().getWidth();
  }
}
```

### 2. Ghost Object

```typescript
class LazyUser {
  private loaded = false;
  private _email?: string;
  private _profile?: UserProfile;

  constructor(public readonly id: string) {}

  private async ensureLoaded(): Promise<void> {
    if (!this.loaded) {
      const data = await fetchUserFromDb(this.id);
      this._email = data.email;
      this._profile = data.profile;
      this.loaded = true;
    }
  }

  async getEmail(): Promise<string> {
    await this.ensureLoaded();
    return this._email!;
  }

  async getProfile(): Promise<UserProfile> {
    await this.ensureLoaded();
    return this._profile!;
  }
}
```

### 3. Lazy Collection

```typescript
class LazyArray<T> {
  private items: Map<number, T> = new Map();

  constructor(
    private length: number,
    private loader: (index: number) => T,
  ) {}

  get(index: number): T {
    if (!this.items.has(index)) {
      this.items.set(index, this.loader(index));
    }
    return this.items.get(index)!;
  }

  *[Symbol.iterator](): Iterator<T> {
    for (let i = 0; i < this.length; i++) {
      yield this.get(i);
    }
  }
}
```

---

## Complexite et Trade-offs

| Aspect | Valeur |
|--------|--------|
| Premier acces | O(init) |
| Acces suivants | O(1) |
| Memoire avant init | O(1) |
| Memoire apres init | O(ressource) |

### Avantages

- Demarrage rapide
- Economie memoire si non utilise
- Chargement a la demande

### Inconvenients

- Latence au premier acces
- Complexite du code
- Gestion des erreurs differee

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Ressource couteuse optionnelle | Oui |
| Optimiser temps demarrage | Oui |
| Dependances circulaires | Oui (rompt le cycle) |
| Ressource toujours utilisee | Non (overhead inutile) |
| Acces temps-reel critique | Non (latence premier acces) |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Proxy** | Encapsule le lazy loading |
| **Singleton** | Souvent combine avec lazy |
| **Factory** | Cree l'objet lors de l'init |
| **Memoization** | Cache de resultats similaire |

---

## Sources

- [Martin Fowler - Lazy Load](https://martinfowler.com/eaaCatalog/lazyLoad.html)
- [Patterns of Enterprise Application Architecture](https://www.martinfowler.com/books/eaa.html)
