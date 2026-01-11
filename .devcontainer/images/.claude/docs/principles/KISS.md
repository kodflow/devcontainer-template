# KISS - Keep It Simple, Stupid

> La simplicité doit être un objectif clé dans la conception.

**Origine :** Kelly Johnson, ingénieur Lockheed (années 1960)

## Principe

La complexité est l'ennemi de la fiabilité. Le code simple est :

- Plus facile à lire
- Plus facile à maintenir
- Plus facile à tester
- Moins sujet aux bugs

## Exemples

### Logique conditionnelle

```typescript
// ❌ Complexe
function getDiscount(user: User) {
  if (user.isPremium) {
    if (user.years > 5) {
      if (user.orders > 100) {
        return 0.25;
      } else {
        return 0.20;
      }
    } else {
      return 0.15;
    }
  } else {
    if (user.orders > 50) {
      return 0.10;
    } else {
      return 0.05;
    }
  }
}

// ✅ Simple
function getDiscount(user: User) {
  if (user.isPremium && user.years > 5 && user.orders > 100) return 0.25;
  if (user.isPremium && user.years > 5) return 0.20;
  if (user.isPremium) return 0.15;
  if (user.orders > 50) return 0.10;
  return 0.05;
}

// ✅✅ Encore plus simple avec une table
const DISCOUNT_RULES = [
  { condition: (u: User) => u.isPremium && u.years > 5 && u.orders > 100, discount: 0.25 },
  { condition: (u: User) => u.isPremium && u.years > 5, discount: 0.20 },
  { condition: (u: User) => u.isPremium, discount: 0.15 },
  { condition: (u: User) => u.orders > 50, discount: 0.10 },
];

function getDiscount(user: User) {
  return DISCOUNT_RULES.find(r => r.condition(user))?.discount ?? 0.05;
}
```

### Architecture

```
❌ Complexe (prématuré)
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Gateway │───▶│ Service │───▶│   DB    │
└─────────┘    └─────────┘    └─────────┘
      │              │              │
      ▼              ▼              ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│  Cache  │    │  Queue  │    │ Replica │
└─────────┘    └─────────┘    └─────────┘

✅ Simple (pour commencer)
┌─────────┐    ┌─────────┐
│   App   │───▶│   DB    │
└─────────┘    └─────────┘
```

### Fonctions

```typescript
// ❌ Fonction trop "intelligente"
function processData(data: any, options?: {
  validate?: boolean;
  transform?: boolean;
  cache?: boolean;
  log?: boolean;
  retry?: number;
}) {
  // 100 lignes de code avec tous les cas
}

// ✅ Fonctions simples et composables
function validateData(data: any) { /* ... */ }
function transformData(data: any) { /* ... */ }
function cacheData(data: any) { /* ... */ }

// Composition claire
const result = cacheData(transformData(validateData(data)));
```

## Signaux de complexité

| Signal | Action |
|--------|--------|
| Fonction > 20 lignes | Diviser |
| Plus de 3 niveaux d'indentation | Extraire |
| Commentaire "c'est compliqué" | Simplifier |
| Difficile à expliquer | Repenser |
| Beaucoup de paramètres (>3) | Créer un objet config |

## Quand la complexité est nécessaire

KISS ne veut pas dire "pas de complexité". Parfois elle est justifiée :

- Optimisation de performance prouvée par benchmarks
- Exigences métier réellement complexes
- Contraintes techniques inévitables

Dans ces cas, **documenter le pourquoi**.

## Relation avec autres principes

| Principe | Relation |
|----------|----------|
| YAGNI | Ne pas ajouter de complexité inutile |
| DRY | Mais pas au prix de la lisibilité |
| SOLID | Peut ajouter de la complexité structurelle |

## Checklist

- [ ] Quelqu'un peut-il comprendre en 5 minutes ?
- [ ] Peut-on expliquer sans dire "c'est compliqué" ?
- [ ] Y a-t-il une solution plus simple ?
- [ ] Cette abstraction est-elle vraiment nécessaire ?

## Sources

- [Wikipedia - KISS](https://en.wikipedia.org/wiki/KISS_principle)
- [Simple Made Easy - Rich Hickey](https://www.infoq.com/presentations/Simple-Made-Easy/)
