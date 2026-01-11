# Memoization

Pattern de cache des resultats de fonctions pour eviter les recalculs.

---

## Qu'est-ce que la Memoization ?

> Stocker le resultat d'un appel de fonction et le retourner directement lors d'appels identiques.

```
+--------------------------------------------------------------+
|                      Memoization                              |
|                                                               |
|  fn(a, b) ----+                                               |
|               |                                               |
|               v                                               |
|         +-----------+                                         |
|         |   Cache   |                                         |
|         |-----------|                                         |
|         | key(a,b)  |--- HIT ---> return cached result        |
|         +-----------+                                         |
|               |                                               |
|             MISS                                              |
|               |                                               |
|               v                                               |
|         compute(a, b)                                         |
|               |                                               |
|               v                                               |
|         store in cache                                        |
|               |                                               |
|               v                                               |
|         return result                                         |
+--------------------------------------------------------------+
```

**Prerequis :** La fonction doit etre **pure** (meme entrees = meme sortie).

---

## Implementation TypeScript

### Memoize simple

```typescript
function memoize<TArgs extends unknown[], TResult>(
  fn: (...args: TArgs) => TResult,
): (...args: TArgs) => TResult {
  const cache = new Map<string, TResult>();

  return (...args: TArgs): TResult => {
    const key = JSON.stringify(args);

    if (cache.has(key)) {
      return cache.get(key)!;
    }

    const result = fn(...args);
    cache.set(key, result);
    return result;
  };
}

// Usage
const factorial = memoize((n: number): number => {
  if (n <= 1) return 1;
  return n * factorial(n - 1);
});

factorial(100); // Calcule
factorial(100); // Cache hit
factorial(99);  // Cache hit (calcule lors de factorial(100))
```

### Memoize avec options

```typescript
interface MemoizeOptions {
  maxSize?: number;
  ttl?: number;
  keyResolver?: (...args: unknown[]) => string;
}

function memoizeAdvanced<TArgs extends unknown[], TResult>(
  fn: (...args: TArgs) => TResult,
  options: MemoizeOptions = {},
): (...args: TArgs) => TResult {
  const {
    maxSize = Infinity,
    ttl,
    keyResolver = (...args) => JSON.stringify(args),
  } = options;

  const cache = new Map<string, { value: TResult; timestamp: number }>();

  return (...args: TArgs): TResult => {
    const key = keyResolver(...args);
    const cached = cache.get(key);

    // Verifier TTL
    if (cached) {
      if (!ttl || Date.now() - cached.timestamp < ttl) {
        return cached.value;
      }
      cache.delete(key);
    }

    const result = fn(...args);

    // Eviction LRU si maxSize atteint
    if (cache.size >= maxSize) {
      const firstKey = cache.keys().next().value;
      cache.delete(firstKey);
    }

    cache.set(key, { value: result, timestamp: Date.now() });
    return result;
  };
}

// Usage avec TTL
const fetchUserCached = memoizeAdvanced(
  async (id: string) => api.getUser(id),
  { ttl: 60_000 }, // Cache 1 minute
);
```

### Memoize async

```typescript
function memoizeAsync<TArgs extends unknown[], TResult>(
  fn: (...args: TArgs) => Promise<TResult>,
): (...args: TArgs) => Promise<TResult> {
  const cache = new Map<string, Promise<TResult>>();

  return (...args: TArgs): Promise<TResult> => {
    const key = JSON.stringify(args);

    if (cache.has(key)) {
      return cache.get(key)!;
    }

    const promise = fn(...args).catch((err) => {
      // Supprimer du cache en cas d'erreur
      cache.delete(key);
      throw err;
    });

    cache.set(key, promise);
    return promise;
  };
}

// Usage
const getUserProfile = memoizeAsync(async (userId: string) => {
  const response = await fetch(`/api/users/${userId}`);
  return response.json();
});

// Deux appels simultanes = une seule requete
const [profile1, profile2] = await Promise.all([
  getUserProfile('123'),
  getUserProfile('123'),
]);
```

---

## Cas d'usage classiques

### Fibonacci

```typescript
const fibonacci = memoize((n: number): number => {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
});

// Sans memoization: O(2^n)
// Avec memoization: O(n)
fibonacci(50); // Instantane
```

### Parsing couteux

```typescript
const parseMarkdown = memoize((content: string): HTMLElement => {
  // Parsing couteux
  return markdownParser.parse(content);
});
```

### Calculs derives

```typescript
class DataProcessor {
  private computeStats = memoize((data: number[]): Stats => {
    return {
      mean: this.mean(data),
      median: this.median(data),
      stdDev: this.standardDeviation(data),
    };
  });

  getStats(data: number[]): Stats {
    return this.computeStats(data);
  }
}
```

---

## Complexite et Trade-offs

| Aspect | Sans memo | Avec memo |
|--------|-----------|-----------|
| Temps (n appels identiques) | O(n * compute) | O(compute + n) |
| Memoire | O(1) | O(unique_calls) |

### Avantages

- Acceleration dramatique pour calculs repetes
- Transparent pour l'appelant
- Simple a implementer

### Inconvenients

- Consommation memoire croissante
- Fonctions pures uniquement
- Cle de cache peut etre couteuse (JSON.stringify)

---

## Quand utiliser

| Situation | Recommande |
|-----------|------------|
| Fonction pure couteuse | Oui |
| Appels repetes avec memes args | Oui |
| Calculs recursifs | Oui |
| Fonctions avec effets de bord | Non |
| Resultats changeants dans le temps | Non (ou avec TTL) |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Cache** | Plus general, pas lie a une fonction |
| **Lazy Loading** | Initialisation differee similaire |
| **Flyweight** | Partage d'objets vs resultats |
| **Decorator** | Enveloppe la fonction originale |

---

## Sources

- [Wikipedia - Memoization](https://en.wikipedia.org/wiki/Memoization)
- [Lodash memoize](https://lodash.com/docs/4.17.15#memoize)
- [React useMemo](https://react.dev/reference/react/useMemo)
