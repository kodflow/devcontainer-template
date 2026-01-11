# Refactoring Patterns

Patterns pour améliorer et migrer du code existant de manière sûre.

---

## Patterns documentés

| Pattern | Fichier | Usage |
|---------|---------|-------|
| Branch by Abstraction | [branch-by-abstraction.md](branch-by-abstraction.md) | Migration progressive sur trunk |
| Strangler Fig | (cloud/strangler.md) | Remplacement système legacy |
| Parallel Run | [branch-by-abstraction.md](branch-by-abstraction.md#parallel-run) | Tester deux implémentations |
| Dark Launch | [branch-by-abstraction.md](branch-by-abstraction.md#dark-launch) | Feature invisible en prod |

---

## 1. Branch by Abstraction

> Migrer une implémentation vers une autre sans branches Git longues.

```typescript
// Étape 1: Créer abstraction
interface PaymentProcessor {
  charge(amount: Money): Promise<Result>;
}

// Étape 2: Ancienne implémentation
class StripeProcessor implements PaymentProcessor { }

// Étape 3: Nouvelle implémentation
class AdyenProcessor implements PaymentProcessor { }

// Étape 4: Feature toggle pour router
class PaymentFactory {
  create(): PaymentProcessor {
    if (features.isEnabled('adyen')) {
      return new AdyenProcessor();
    }
    return new StripeProcessor();
  }
}

// Étape 5: Rollout progressif
// 1% → 10% → 50% → 100%

// Étape 6: Supprimer l'ancienne implémentation
```

**Quand :** Remplacer une dépendance, refactorer un module, migrer une API.

**Lié à :** Feature Toggle, Adapter, Strategy

---

## 2. Strangler Fig

> Remplacer progressivement un système legacy par un nouveau.

```typescript
// Façade qui route vers legacy ou nouveau
class OrderFacade {
  async createOrder(data: OrderData) {
    if (this.canUseNewSystem(data)) {
      return this.newOrderService.create(data);
    }
    return this.legacySystem.createOrder(data);
  }

  private canUseNewSystem(data: OrderData): boolean {
    // Critères de migration progressifs
    return (
      data.region === 'EU' &&
      data.total < 10000 &&
      features.isEnabled('new-order-system')
    );
  }
}
```

**Quand :** Migrer un monolithe, remplacer un système legacy.

**Lié à :** Branch by Abstraction, Anti-Corruption Layer

---

## 3. Parallel Run

> Exécuter deux implémentations en parallèle et comparer les résultats.

```typescript
class ParallelProcessor {
  async process(data: Data) {
    const [legacyResult, newResult] = await Promise.allSettled([
      this.legacy.process(data),
      this.modern.process(data),
    ]);

    // Comparer en arrière-plan
    this.compare(legacyResult, newResult);

    // Retourner le résultat de confiance (legacy)
    return legacyResult;
  }
}
```

**Quand :** Valider une nouvelle implémentation en production.

---

## 4. Dark Launch

> Activer du code en production sans exposer le résultat.

```typescript
class DarkLaunchFeature {
  async process(data: Data) {
    const result = await this.legacy.process(data);

    // Exécuter le nouveau code sans utiliser le résultat
    this.modern.process(data)
      .then(newResult => this.metrics.record(newResult))
      .catch(err => this.logger.error('Dark launch error', err));

    return result;
  }
}
```

**Quand :** Tester la charge et les performances avant activation.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Remplacer une dépendance | Branch by Abstraction |
| Migrer un système legacy | Strangler Fig |
| Valider en production | Parallel Run |
| Tester la charge | Dark Launch |
| Rollback instantané | Feature Toggle |
| Migration base de données | Double-Write + Switch |

---

## Workflow de migration type

```
1. Créer l'abstraction (interface)
       │
2. Implémenter le nouveau code
       │
3. Double-write (si données)
       │
4. Parallel Run (validation)
       │
5. Feature Toggle (rollout)
       │  0% → 1% → 10% → 50% → 100%
       │
6. Supprimer l'ancien code
       │
7. Supprimer le toggle
```

---

## Sources

- [Martin Fowler - Branch by Abstraction](https://martinfowler.com/bliki/BranchByAbstraction.html)
- [Martin Fowler - Strangler Fig](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Trunk Based Development](https://trunkbaseddevelopment.com/)
