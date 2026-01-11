# Debounce et Throttle

Patterns pour limiter la frequence d'execution de fonctions.

---

## Vue d'ensemble

```
+--------------------------------------------------------------+
|  Evenements:  X X X X X    X X X X X         X X              |
|               |-wait-|    |-wait-|                            |
|                                                               |
|  Debounce:              X              X              X       |
|                         ^              ^              ^       |
|                 (apres silence)  (apres silence)              |
|                                                               |
|  Throttle:    X         X         X         X         X       |
|               ^---------^---------^---------^---------^       |
|               (intervalle regulier, max 1 par periode)        |
+--------------------------------------------------------------+
```

| Pattern | Comportement | Cas d'usage |
|---------|--------------|-------------|
| **Debounce** | Execute apres un delai d'inactivite | Recherche, resize |
| **Throttle** | Execute max 1 fois par intervalle | Scroll, animations |

---

## Debounce

> Attendre que l'utilisateur arrete d'agir avant d'executer.

```typescript
function debounce<TArgs extends unknown[]>(
  fn: (...args: TArgs) => void,
  delay: number,
): (...args: TArgs) => void {
  let timeoutId: ReturnType<typeof setTimeout> | null = null;

  return (...args: TArgs): void => {
    if (timeoutId) {
      clearTimeout(timeoutId);
    }

    timeoutId = setTimeout(() => {
      fn(...args);
      timeoutId = null;
    }, delay);
  };
}

// Usage - Recherche
const searchInput = document.querySelector<HTMLInputElement>('#search');
const debouncedSearch = debounce((query: string) => {
  console.log(`Searching: ${query}`);
  api.search(query);
}, 300);

searchInput?.addEventListener('input', (e) => {
  debouncedSearch((e.target as HTMLInputElement).value);
});
```

### Debounce avec options

```typescript
interface DebounceOptions {
  leading?: boolean;  // Executer au debut
  trailing?: boolean; // Executer a la fin
  maxWait?: number;   // Delai max avant execution forcee
}

function debounceAdvanced<TArgs extends unknown[]>(
  fn: (...args: TArgs) => void,
  delay: number,
  options: DebounceOptions = {},
): (...args: TArgs) => void {
  const { leading = false, trailing = true, maxWait } = options;

  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  let maxWaitId: ReturnType<typeof setTimeout> | null = null;
  let lastArgs: TArgs | null = null;
  let lastCallTime = 0;

  const invoke = () => {
    if (lastArgs) {
      fn(...lastArgs);
      lastArgs = null;
    }
  };

  const clearTimers = () => {
    if (timeoutId) clearTimeout(timeoutId);
    if (maxWaitId) clearTimeout(maxWaitId);
    timeoutId = null;
    maxWaitId = null;
  };

  return (...args: TArgs): void => {
    const now = Date.now();
    const isFirstCall = lastCallTime === 0;
    lastCallTime = now;
    lastArgs = args;

    // Leading edge
    if (leading && isFirstCall) {
      invoke();
    }

    clearTimers();

    // Trailing edge
    if (trailing) {
      timeoutId = setTimeout(() => {
        invoke();
        lastCallTime = 0;
        clearTimers();
      }, delay);
    }

    // Max wait
    if (maxWait && !maxWaitId) {
      maxWaitId = setTimeout(() => {
        invoke();
        clearTimers();
      }, maxWait);
    }
  };
}
```

---

## Throttle

> Limiter a une execution par intervalle de temps.

```typescript
function throttle<TArgs extends unknown[]>(
  fn: (...args: TArgs) => void,
  limit: number,
): (...args: TArgs) => void {
  let lastRun = 0;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  let lastArgs: TArgs | null = null;

  return (...args: TArgs): void => {
    const now = Date.now();

    if (now - lastRun >= limit) {
      // Executer immediatement
      fn(...args);
      lastRun = now;
    } else {
      // Programmer pour plus tard
      lastArgs = args;

      if (!timeoutId) {
        timeoutId = setTimeout(() => {
          if (lastArgs) {
            fn(...lastArgs);
            lastRun = Date.now();
            lastArgs = null;
          }
          timeoutId = null;
        }, limit - (now - lastRun));
      }
    }
  };
}

// Usage - Scroll
const throttledScroll = throttle(() => {
  const scrollY = window.scrollY;
  updateNavbar(scrollY);
  loadMoreIfNeeded(scrollY);
}, 100);

window.addEventListener('scroll', throttledScroll);
```

### Throttle avec options

```typescript
interface ThrottleOptions {
  leading?: boolean;
  trailing?: boolean;
}

function throttleAdvanced<TArgs extends unknown[]>(
  fn: (...args: TArgs) => void,
  limit: number,
  options: ThrottleOptions = {},
): (...args: TArgs) => void {
  const { leading = true, trailing = true } = options;

  let lastRun = 0;
  let timeoutId: ReturnType<typeof setTimeout> | null = null;
  let lastArgs: TArgs | null = null;

  const invoke = (args: TArgs) => {
    fn(...args);
    lastRun = Date.now();
  };

  return (...args: TArgs): void => {
    const now = Date.now();
    const remaining = limit - (now - lastRun);

    lastArgs = args;

    if (remaining <= 0 || remaining > limit) {
      if (timeoutId) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
      if (leading) {
        invoke(args);
      }
    } else if (!timeoutId && trailing) {
      timeoutId = setTimeout(() => {
        invoke(lastArgs!);
        timeoutId = null;
      }, remaining);
    }
  };
}
```

---

## Comparaison visuelle

```
Evenements: | | | | |     | | | |       | |

Debounce (300ms):
                    X           X         X
                    ^-- 300ms apres dernier evenement

Throttle (300ms):
            X       X     X     X       X
            ^-------^-----^-----^-------^-- max 1 par 300ms
```

---

## Cas d'usage

### Cas d'usage Debounce

```typescript
// Validation de formulaire
const validateEmail = debounce((email: string) => {
  api.checkEmailAvailable(email).then(setIsAvailable);
}, 500);

// Resize window
const handleResize = debounce(() => {
  recalculateLayout();
}, 250);

// Auto-save
const autoSave = debounce((content: string) => {
  api.saveDraft(content);
}, 1000);
```

### Cas d'usage Throttle

```typescript
// Scroll infini
const loadMore = throttle(() => {
  if (isNearBottom()) {
    fetchNextPage();
  }
}, 200);

// Mouse move pour tooltip
const updateTooltip = throttle((x: number, y: number) => {
  tooltip.setPosition(x, y);
}, 16); // ~60fps

// Analytics
const trackScroll = throttle((depth: number) => {
  analytics.track('scroll', { depth });
}, 1000);
```

---

## Complexite et Trade-offs

| Aspect | Debounce | Throttle |
|--------|----------|----------|
| Latence | Delai garanti | Execution immediate possible |
| Frequence | Variable | Bornee |
| Memoire | O(1) | O(1) |

### Quand utiliser quoi

| Situation | Pattern |
|-----------|---------|
| Attendre fin de saisie | Debounce |
| Limiter requetes API | Debounce |
| Animation fluide | Throttle |
| Events haute frequence | Throttle |
| Auto-save | Debounce + maxWait |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Rate Limiter** | Throttle cote serveur |
| **Circuit Breaker** | Protection contre surcharge |
| **Batch Processing** | Grouper au lieu de limiter |

---

## Sources

- [Lodash debounce/throttle](https://lodash.com/docs/4.17.15#debounce)
- [CSS-Tricks - Debouncing and Throttling](https://css-tricks.com/debouncing-throttling-explained-examples/)
