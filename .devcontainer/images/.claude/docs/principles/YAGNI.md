# YAGNI - You Aren't Gonna Need It

> N'implémentez jamais quelque chose avant d'en avoir réellement besoin.

**Origine :** Kent Beck, Extreme Programming (XP)

## Principe

Résister à la tentation d'ajouter des fonctionnalités "au cas où".

**Coût de la fonctionnalité prématurée :**

- Temps de développement
- Temps de test
- Complexité ajoutée
- Maintenance future
- Souvent jamais utilisée

## Exemples

### Code

```typescript
// ❌ YAGNI violation
class UserService {
  getUser(id: string) { /* ... */ }
  getUserWithCache(id: string) { /* ... */ }  // "On aura besoin de cache"
  getUserAsync(id: string) { /* ... */ }       // "Peut-être async un jour"
  getUserBatch(ids: string[]) { /* ... */ }    // "Au cas où"
  getUserWithRetry(id: string) { /* ... */ }   // "Pour la résilience"
}

// ✅ YAGNI
class UserService {
  getUser(id: string) { /* ... */ }
  // Ajouter les autres QUAND on en a besoin
}
```

### Configuration

```typescript
// ❌ YAGNI violation
interface Config {
  database: {
    host: string;
    port: number;
    ssl: boolean;
    poolSize: number;
    maxRetries: number;
    retryDelay: number;
    connectionTimeout: number;
    queryTimeout: number;
    idleTimeout: number;
    // 20 autres options "au cas où"
  };
}

// ✅ YAGNI
interface Config {
  database: {
    host: string;
    port: number;
  };
  // Ajouter ssl QUAND on déploie en prod
  // Ajouter poolSize QUAND on a des problèmes de perf
}
```

### Architecture

```
❌ YAGNI violation (Jour 1 d'un MVP)
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│ Gateway │─▶│ Service │─▶│  Cache  │─▶│   DB    │
└─────────┘  └─────────┘  └─────────┘  └─────────┘
                 │
                 ▼
           ┌─────────┐
           │  Queue  │
           └─────────┘
                 │
                 ▼
           ┌─────────┐
           │ Worker  │
           └─────────┘

✅ YAGNI (Jour 1 d'un MVP)
┌─────────┐
│   App   │───▶ SQLite
└─────────┘

(Évoluer QUAND nécessaire)
```

## Exceptions

YAGNI ne s'applique pas à :

### 1. Sécurité

```typescript
// ✅ Toujours inclure (pas YAGNI)
function hashPassword(password: string) {
  return bcrypt.hash(password, 12);
}
```

### 2. Architecture difficile à changer

```typescript
// ✅ Réfléchir dès le départ
interface Database {
  query(sql: string): Promise<any>;
}
// Car changer l'interface DB après = très coûteux
```

### 3. Contrats d'API publique

```typescript
// ✅ Versionner dès le départ
// /api/v1/users
// Car changer = breaking change pour les clients
```

## YAGNI vs Anticipation

| YAGNI (Bon) | Anticipation (Acceptable) |
|-------------|---------------------------|
| "On aura peut-être besoin de MongoDB" | Abstraction Database interface |
| "Ajoutons un cache Redis" | Pas de cache pour l'instant |
| "Préparons le multi-tenant" | Architecture simple |
| "Supportons 10 langues" | Support i18n basique |

## Workflow

```
1. Besoin identifié
2. Solution minimale
3. Livrer
4. Feedback
5. Itérer si nécessaire
```

## Signaux de violation YAGNI

- "On pourrait avoir besoin de..."
- "Au cas où..."
- "Pour le futur..."
- "Ce serait bien d'avoir..."
- "Un jour on voudra..."

## Relation avec autres principes

| Principe | Relation |
|----------|----------|
| KISS | YAGNI maintient la simplicité |
| DRY | Appliquer DRY aux besoins réels seulement |
| SOLID | Appliquer SOLID progressivement |

## Checklist

- [ ] Ce besoin existe-t-il aujourd'hui ?
- [ ] Un utilisateur l'a-t-il demandé ?
- [ ] Que se passe-t-il si on ne le fait pas ?
- [ ] Peut-on l'ajouter facilement plus tard ?

## Sources

- [Extreme Programming Explained - Kent Beck](https://www.amazon.com/Extreme-Programming-Explained-Embrace-Change/dp/0321278658)
- [Wikipedia - YAGNI](https://en.wikipedia.org/wiki/You_aren%27t_gonna_need_it)
- [Martin Fowler - YAGNI](https://martinfowler.com/bliki/Yagni.html)
