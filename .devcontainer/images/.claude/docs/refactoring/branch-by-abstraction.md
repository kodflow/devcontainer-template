# Branch by Abstraction

Pattern pour remplacer progressivement une implémentation par une autre sans branches Git longues.

---

## Qu'est-ce que Branch by Abstraction ?

> Technique de refactoring permettant de faire des changements majeurs sur trunk/main de manière incrémentale et sûre.

```
┌─────────────────────────────────────────────────────────────┐
│                    Branch by Abstraction                     │
│                                                              │
│  1. Créer abstraction    2. Migrer clients    3. Supprimer  │
│                                                              │
│  ┌─────┐                 ┌─────┐              ┌─────┐       │
│  │Old  │ ──abstract──►   │Old  │    ──►       │     │       │
│  │Impl │                 │Impl │              │New  │       │
│  └─────┘                 └──┬──┘              │Impl │       │
│                             │                 └─────┘       │
│                          ┌──┴──┐                            │
│                          │New  │                            │
│                          │Impl │                            │
│                          └─────┘                            │
└─────────────────────────────────────────────────────────────┘
```

**Pourquoi :**
- Éviter les branches Git longues (merge hell)
- Déployer continuellement sur main
- Rollback facile à tout moment
- Travail en parallèle possible

---

## Le Problème : Feature Branches Longues

```
❌ MAUVAIS - Feature branch pendant des mois

main:     A──B──C──D──E──F──G──H──I──J──K──L──M──N──O
               \                                  /
feature:        X──Y──Z──W──V──U──T──S──R──Q──P──┘

Problèmes:
- Merge conflicts énormes
- Intégration retardée
- Tests d'intégration tardifs
- Code review massive
```

```
✅ BON - Branch by Abstraction

main:     A──B──C──D──E──F──G──H──I──J──K──L──M
              │  │  │  │  │  │  │  │  │  │  │
              │  └──┴──┴──┴──┴──┴──┴──┴──┴──┘
              │     Petits commits progressifs
              │
              └── Abstraction créée
```

---

## Étapes du Pattern

### Étape 1 : Créer l'abstraction

```typescript
// AVANT - Couplage direct
class OrderService {
  private paymentProcessor = new StripeProcessor();

  async processPayment(order: Order) {
    return this.paymentProcessor.charge(order.total);
  }
}

// APRÈS Étape 1 - Interface créée
interface PaymentProcessor {
  charge(amount: Money): Promise<PaymentResult>;
  refund(transactionId: string): Promise<void>;
}

// L'ancienne implémentation implémente l'interface
class StripeProcessor implements PaymentProcessor {
  async charge(amount: Money) { /* existing code */ }
  async refund(transactionId: string) { /* existing code */ }
}

class OrderService {
  constructor(private paymentProcessor: PaymentProcessor) {}

  async processPayment(order: Order) {
    return this.paymentProcessor.charge(order.total);
  }
}
```

**Commit 1 :** "Add PaymentProcessor interface" (pas de changement fonctionnel)

---

### Étape 2 : Créer la nouvelle implémentation

```typescript
// Nouvelle implémentation (peut être incomplète)
class AdyenProcessor implements PaymentProcessor {
  async charge(amount: Money) {
    // Nouvelle implémentation
    return this.adyenClient.authorizePayment({
      amount: amount.cents,
      currency: amount.currency,
    });
  }

  async refund(transactionId: string) {
    // TODO: implement
    throw new Error('Not implemented yet');
  }
}
```

**Commit 2 :** "Add AdyenProcessor implementation (WIP)"

---

### Étape 3 : Router vers la nouvelle implémentation

```typescript
// Feature toggle pour router
class PaymentProcessorFactory {
  static create(context: PaymentContext): PaymentProcessor {
    // Toggle progressif
    if (features.isEnabled('adyen-payments', context)) {
      return new AdyenProcessor();
    }
    return new StripeProcessor();
  }
}

// Ou migration par méthode
class HybridProcessor implements PaymentProcessor {
  constructor(
    private legacy: StripeProcessor,
    private modern: AdyenProcessor,
  ) {}

  async charge(amount: Money) {
    // Nouvelle implémentation pour charge
    if (features.isEnabled('adyen-charge')) {
      return this.modern.charge(amount);
    }
    return this.legacy.charge(amount);
  }

  async refund(transactionId: string) {
    // Encore l'ancienne pour refund
    return this.legacy.refund(transactionId);
  }
}
```

**Commit 3 :** "Add feature toggle for AdyenProcessor"
**Commit 4 :** "Enable Adyen for 1% of traffic"
**Commit 5 :** "Enable Adyen for 10% of traffic"
...
**Commit N :** "Enable Adyen for 100% of traffic"

---

### Étape 4 : Supprimer l'ancienne implémentation

```typescript
// Une fois la migration complète et stable

// Supprimer:
// - StripeProcessor class
// - Feature toggles
// - Code de routing

// Garder:
// - Interface PaymentProcessor (pour futures migrations)
// - AdyenProcessor (maintenant la seule implémentation)
```

**Commit final :** "Remove StripeProcessor (migration complete)"

---

## Variantes

### Strangler Fig Pattern

> Étrangler progressivement l'ancien système.

```typescript
// Pour migrer un monolithe vers microservices

class OrderFacade {
  constructor(
    private legacyOrderService: LegacyOrderService,
    private newOrderService: OrderMicroservice,
  ) {}

  async createOrder(data: OrderData) {
    // Route vers le nouveau service progressivement
    if (this.shouldUseNewService(data)) {
      return this.newOrderService.create(data);
    }
    return this.legacyOrderService.create(data);
  }

  private shouldUseNewService(data: OrderData): boolean {
    // Critères de migration
    return (
      data.region === 'EU' && // Europe d'abord
      data.total.amount < 10000 && // Petites commandes
      features.isEnabled('new-order-service')
    );
  }
}
```

### Parallel Run

> Exécuter les deux implémentations et comparer.

```typescript
class ParallelPaymentProcessor implements PaymentProcessor {
  constructor(
    private primary: PaymentProcessor,
    private shadow: PaymentProcessor,
    private comparator: ResultComparator,
  ) {}

  async charge(amount: Money) {
    // Exécuter en parallèle
    const [primaryResult, shadowResult] = await Promise.allSettled([
      this.primary.charge(amount),
      this.shadow.charge(amount),
    ]);

    // Comparer (async, non-bloquant)
    this.comparator.compare(primaryResult, shadowResult).catch(err => {
      this.logger.warn('Shadow comparison failed', err);
    });

    // Retourner seulement le résultat primary
    if (primaryResult.status === 'fulfilled') {
      return primaryResult.value;
    }
    throw primaryResult.reason;
  }
}
```

### Dark Launch

> Nouvelle implémentation activée mais résultat ignoré.

```typescript
class DarkLaunchProcessor implements PaymentProcessor {
  async charge(amount: Money) {
    // Toujours utiliser legacy pour le résultat réel
    const result = await this.legacy.charge(amount);

    // Tester le nouveau en arrière-plan
    this.modern.charge(amount)
      .then(modernResult => {
        this.metrics.record('dark-launch-success');
        if (!this.resultsMatch(result, modernResult)) {
          this.logger.warn('Dark launch mismatch', { result, modernResult });
        }
      })
      .catch(err => {
        this.metrics.record('dark-launch-failure');
        this.logger.error('Dark launch error', err);
      });

    return result;
  }
}
```

---

## Exemple complet : Migration de base de données

```typescript
// Migration de MySQL vers PostgreSQL

// Étape 1: Abstraction
interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<void>;
  findByEmail(email: string): Promise<User | null>;
}

// Étape 2: Implémentations
class MySQLUserRepository implements UserRepository {
  // Implémentation existante MySQL
}

class PostgresUserRepository implements UserRepository {
  // Nouvelle implémentation Postgres
}

// Étape 3: Double-write pour migration
class MigratingUserRepository implements UserRepository {
  constructor(
    private mysql: MySQLUserRepository,
    private postgres: PostgresUserRepository,
    private migrationState: MigrationState,
  ) {}

  async save(user: User): Promise<void> {
    // Écrire dans les deux
    await Promise.all([
      this.mysql.save(user),
      this.postgres.save(user),
    ]);
  }

  async findById(id: string): Promise<User | null> {
    // Lire du primary selon l'état de migration
    if (this.migrationState.isComplete()) {
      return this.postgres.findById(id);
    }

    // Pendant migration: lire de MySQL, vérifier Postgres
    const mysqlUser = await this.mysql.findById(id);
    const postgresUser = await this.postgres.findById(id);

    if (!this.usersMatch(mysqlUser, postgresUser)) {
      this.logger.warn('Data mismatch during migration', { id });
      // Self-heal: copier de MySQL vers Postgres
      if (mysqlUser) {
        await this.postgres.save(mysqlUser);
      }
    }

    return mysqlUser; // MySQL reste primary pendant migration
  }
}

// Étape 4: Cutover progressif
class MigrationState {
  private readFromPostgres = 0; // 0-100%

  isComplete(): boolean {
    return this.readFromPostgres === 100;
  }

  shouldReadFromPostgres(userId: string): boolean {
    // Canary basé sur hash du userId
    const hash = this.hashCode(userId);
    return (hash % 100) < this.readFromPostgres;
  }

  async incrementPercentage(increment: number) {
    this.readFromPostgres = Math.min(100, this.readFromPostgres + increment);
    await this.persist();
  }
}
```

---

## Tableau de décision

| Situation | Approche |
|-----------|----------|
| Refactoring interne simple | Git branch + PR |
| Migration API/Service | Branch by Abstraction |
| Migration base de données | Double-write + Parallel Run |
| Remplacement dépendance | Strangler Fig |
| Test nouvelle implémentation | Dark Launch |
| Rollout progressif | Feature Toggle + Canary |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Feature Toggles** | Mécanisme de routing |
| **Adapter** | Interface commune |
| **Strategy** | Interchangeabilité |
| **Strangler Fig** | Variante pour legacy |
| **Parallel Run** | Validation de migration |

---

## Avantages vs Inconvénients

### Avantages

- Intégration continue (pas de merge hell)
- Rollback instantané (toggle off)
- Code review incrémentales
- Tests d'intégration continus
- Déploiement à tout moment

### Inconvénients

- Code temporairement plus complexe
- Toggle debt si pas nettoyé
- Besoin de discipline d'équipe
- Monitoring plus complexe

---

## Sources

- [Martin Fowler - Branch by Abstraction](https://martinfowler.com/bliki/BranchByAbstraction.html)
- [Paul Hammant - Trunk Based Development](https://trunkbaseddevelopment.com/branch-by-abstraction/)
- [Strangler Fig Application](https://martinfowler.com/bliki/StranglerFigApplication.html)
