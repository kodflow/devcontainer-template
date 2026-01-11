# DRY - Don't Repeat Yourself

> Chaque élément de connaissance doit avoir une représentation unique et non ambiguë dans un système.

**Auteurs :** Andrew Hunt & David Thomas (The Pragmatic Programmer, 1999)

## Principe

**DRY ne concerne pas seulement le code dupliqué, mais toute forme de duplication de connaissance :**
- Code
- Documentation
- Configuration
- Schémas de données
- Processus

## Exemples

### Code

```typescript
// ❌ WET (Write Everything Twice)
function validateEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function validateUserEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email); // Dupliqué
}

// ✅ DRY
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateEmail(email: string) {
  return EMAIL_REGEX.test(email);
}
```

### Configuration

```yaml
# ❌ WET
development:
  database_host: localhost
  database_port: 5432
  database_name: myapp_dev

staging:
  database_host: staging.example.com
  database_port: 5432  # Dupliqué
  database_name: myapp_staging

# ✅ DRY
defaults:
  database_port: 5432

development:
  database_host: localhost
  database_name: myapp_dev

staging:
  database_host: staging.example.com
  database_name: myapp_staging
```

### Documentation

```typescript
// ❌ WET - Doc et code désynchronisés
/**
 * Calculates the total price with 20% tax
 */
function calculateTotal(price: number) {
  return price * 1.15; // Bug: doc dit 20%, code fait 15%
}

// ✅ DRY - Single source of truth
const TAX_RATE = 0.20;

/**
 * Calculates the total price with tax
 */
function calculateTotal(price: number) {
  return price * (1 + TAX_RATE);
}
```

## Quand NE PAS appliquer DRY

### Couplage accidentel

```typescript
// ❌ Mauvaise abstraction DRY
function processEntity(entity: User | Product | Order) {
  // Logic très différente selon le type
  // → Mieux vaut 3 fonctions séparées
}

// ✅ Duplication acceptable
function processUser(user: User) { /* ... */ }
function processProduct(product: Product) { /* ... */ }
function processOrder(order: Order) { /* ... */ }
```

### Règle des 3

> Dupliquer 2 fois est acceptable. À la 3ème, refactoriser.

Raison : Éviter les abstractions prématurées.

## Anti-pattern : WET

**WET = Write Everything Twice** (ou "Waste Everyone's Time")

Symptômes :
- Même bug à corriger à plusieurs endroits
- Changement de règle métier = modifications multiples
- "J'ai oublié de modifier l'autre endroit"

## Patterns liés

| Pattern | Relation avec DRY |
|---------|-------------------|
| Template Method | Factoriser le squelette d'algorithme |
| Strategy | Factoriser les variations d'algorithme |
| Decorator | Éviter la duplication dans les sous-classes |
| Factory | Centraliser la logique de création |

## Checklist

- [ ] Ce code existe-t-il ailleurs ?
- [ ] Cette config est-elle dupliquée ?
- [ ] La doc et le code sont-ils synchronisés ?
- [ ] Les constantes sont-elles centralisées ?

## Sources

- [The Pragmatic Programmer](https://pragprog.com/titles/tpp20/)
- [Wikipedia - DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
