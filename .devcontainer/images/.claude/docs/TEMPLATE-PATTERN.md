# [Nom du Pattern]

> [Description courte en une ligne - ce que fait le pattern]

---

## Principe

[Explication du concept en 2-3 paragraphes]

```
[Diagramme ASCII si applicable]

┌─────────┐         ┌─────────┐
│ Client  │ ──────► │ Pattern │
└─────────┘         └─────────┘
```

---

## Problème résolu

[Quel problème ce pattern résout-il ?]

- Problème 1
- Problème 2
- Problème 3

---

## Solution

[Comment le pattern résout-il ce problème ?]

```typescript
// Interface ou abstraction principale
interface [PatternInterface] {
  [method](): [ReturnType];
}

// Implémentation concrète
class [ConcreteImplementation] implements [PatternInterface] {
  [method](): [ReturnType] {
    // Logique du pattern
  }
}

// Usage
const instance = new [ConcreteImplementation]();
instance.[method]();
```

---

## Exemple complet

```typescript
// Exemple réaliste et fonctionnel

// 1. Définition
[code complet]

// 2. Usage
[exemple d'utilisation]

// 3. Output attendu
// > [résultat]
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| [Variante1] | [Description] | [Quand l'utiliser] |
| [Variante2] | [Description] | [Quand l'utiliser] |

---

## Quand utiliser

- ✅ [Cas d'usage 1]
- ✅ [Cas d'usage 2]
- ✅ [Cas d'usage 3]

## Quand NE PAS utiliser

- ❌ [Anti-cas 1]
- ❌ [Anti-cas 2]
- ❌ [Anti-cas 3]

---

## Avantages / Inconvénients

| Avantages | Inconvénients |
|-----------|---------------|
| [Avantage 1] | [Inconvénient 1] |
| [Avantage 2] | [Inconvénient 2] |
| [Avantage 3] | [Inconvénient 3] |

---

## Patterns liés

| Pattern | Relation |
|---------|----------|
| [Pattern1] | [Complémentaire / Alternative / Composable avec] |
| [Pattern2] | [Souvent utilisé ensemble] |
| [Pattern3] | [Similaire mais pour X] |

---

## Implémentation dans les frameworks

| Framework/Lib | Implémentation |
|---------------|----------------|
| [Framework1] | [Comment c'est implémenté] |
| [Framework2] | [Comment c'est implémenté] |

---

## Anti-patterns à éviter

| Anti-pattern | Problème | Solution |
|--------------|----------|----------|
| [Anti1] | [Ce qui ne va pas] | [Comment corriger] |
| [Anti2] | [Ce qui ne va pas] | [Comment corriger] |

---

## Tests

```typescript
describe('[PatternName]', () => {
  it('should [behavior]', () => {
    // Arrange
    const sut = new [Implementation]();

    // Act
    const result = sut.[method]();

    // Assert
    expect(result).toBe([expected]);
  });
});
```

---

## Sources

- [Titre Source 1](https://url1)
- [Titre Source 2](https://url2)
- [Livre/Article de référence]
