# Feature Toggles / Feature Flags

Techniques pour activer/désactiver des fonctionnalités sans déploiement.

---

## Qu'est-ce qu'un Feature Toggle ?

> Un mécanisme pour modifier le comportement d'un système sans changer son code.

```typescript
// Principe de base
if (featureFlags.isEnabled('new-checkout')) {
  return newCheckoutFlow(cart);
} else {
  return legacyCheckoutFlow(cart);
}
```

**Pourquoi :**
- Déployer du code inactif (deploy ≠ release)
- Tester en production avec subset d'utilisateurs
- Rollback instantané sans redéploiement
- A/B testing

---

## Types de Feature Toggles

### 1. Release Toggles (Court terme)

> Cacher des features incomplètes en production.

```typescript
// ❌ MAUVAIS - Branche longue non mergée
// feature/new-payment reste 3 mois en dev

// ✅ BON - Code mergé mais toggle désactivé
class PaymentService {
  async process(order: Order) {
    if (features.isEnabled('new-payment-gateway')) {
      return this.newGateway.process(order);
    }
    return this.legacyGateway.process(order);
  }
}

// Déploié en prod, activé quand prêt
features.enable('new-payment-gateway');
```

**Durée :** Jours à semaines
**À supprimer :** Dès que feature stable

---

### 2. Experiment Toggles (A/B Testing)

> Tester différentes variantes sur des segments d'utilisateurs.

```typescript
interface ExperimentConfig {
  name: string;
  variants: Variant[];
  allocation: number; // % d'utilisateurs
}

class ExperimentService {
  getVariant(userId: string, experiment: string): string {
    const config = this.experiments.get(experiment);
    if (!config) return 'control';

    // Hash déterministe pour consistance
    const hash = this.hash(`${userId}:${experiment}`);
    const bucket = hash % 100;

    if (bucket >= config.allocation) {
      return 'control';
    }

    // Distribution entre variantes
    return this.selectVariant(hash, config.variants);
  }
}

// Usage
const variant = experiments.getVariant(user.id, 'checkout-redesign');
switch (variant) {
  case 'control':
    return <OriginalCheckout />;
  case 'variant-a':
    return <SimplifiedCheckout />;
  case 'variant-b':
    return <OneClickCheckout />;
}
```

**Durée :** Semaines à mois
**Métriques :** Conversion, engagement, revenue

---

### 3. Ops Toggles (Kill Switches)

> Désactiver des features en cas de problème.

```typescript
class CircuitConfig {
  // Toggles opérationnels
  static readonly toggles = {
    'recommendations-service': true,
    'third-party-analytics': true,
    'email-notifications': true,
    'heavy-reports': true,
  };
}

class RecommendationService {
  async getRecommendations(userId: string) {
    // Kill switch - désactivable instantanément
    if (!ops.isEnabled('recommendations-service')) {
      return this.getFallbackRecommendations();
    }

    try {
      return await this.mlService.predict(userId);
    } catch (error) {
      // Auto-disable si trop d'erreurs
      if (this.errorRate > 0.5) {
        ops.disable('recommendations-service');
      }
      return this.getFallbackRecommendations();
    }
  }
}
```

**Durée :** Permanent
**Activation :** Via dashboard ou API

---

### 4. Permission Toggles

> Features disponibles selon le plan/rôle utilisateur.

```typescript
interface UserPlan {
  name: 'free' | 'pro' | 'enterprise';
  features: string[];
}

class FeatureGate {
  private userPlan: UserPlan;

  canAccess(feature: string): boolean {
    // Vérifier le plan utilisateur
    if (this.userPlan.features.includes(feature)) {
      return true;
    }

    // Vérifier les toggles globaux (beta, etc.)
    if (this.globalToggles.isEnabled(feature)) {
      return true;
    }

    return false;
  }
}

// Usage
if (featureGate.canAccess('advanced-analytics')) {
  return <AdvancedDashboard />;
} else {
  return <BasicDashboard showUpgrade />;
}
```

---

## Implémentation

### Architecture

```typescript
// 1. Interface abstraite
interface FeatureFlags {
  isEnabled(flag: string): boolean;
  isEnabled(flag: string, context: Context): boolean;
  getVariant(flag: string, context: Context): string;
}

// 2. Contexte utilisateur
interface Context {
  userId?: string;
  userPlan?: string;
  country?: string;
  deviceType?: string;
  percentage?: number;
}

// 3. Implémentation simple (config file)
class ConfigFeatureFlags implements FeatureFlags {
  constructor(private config: Record<string, boolean>) {}

  isEnabled(flag: string): boolean {
    return this.config[flag] ?? false;
  }
}

// 4. Implémentation avancée (remote config)
class RemoteFeatureFlags implements FeatureFlags {
  private cache = new Map<string, FlagValue>();
  private refreshInterval = 30_000;

  constructor(private api: FlagService) {
    this.startPolling();
  }

  isEnabled(flag: string, context?: Context): boolean {
    const value = this.cache.get(flag);
    if (!value) return false;

    return this.evaluate(value, context);
  }

  private evaluate(value: FlagValue, context?: Context): boolean {
    // Règles de ciblage
    if (value.rules) {
      for (const rule of value.rules) {
        if (this.matchesRule(rule, context)) {
          return rule.enabled;
        }
      }
    }

    // Pourcentage rollout
    if (value.percentage !== undefined && context?.userId) {
      const hash = this.hash(context.userId + flag);
      return (hash % 100) < value.percentage;
    }

    return value.enabled;
  }
}
```

### Configuration déclarative

```yaml
# feature-flags.yaml
flags:
  new-checkout:
    enabled: true
    percentage: 50  # 50% des utilisateurs
    rules:
      - if:
          plan: enterprise
        then: true   # 100% pour enterprise
      - if:
          country: FR
        then: false  # Pas encore en France

  dark-mode:
    enabled: true
    # Pas de règles = tout le monde

  beta-features:
    enabled: false
    rules:
      - if:
          email_ends_with: "@company.com"
        then: true  # Employés seulement
```

---

## Stratégies de Rollout

### 1. Canary Release

```typescript
const canaryConfig = {
  flag: 'new-api-v2',
  stages: [
    { percentage: 1, duration: '1h' },   // 1% pendant 1h
    { percentage: 5, duration: '4h' },   // 5% pendant 4h
    { percentage: 25, duration: '1d' },  // 25% pendant 1 jour
    { percentage: 100 },                  // Full rollout
  ],
};

class CanaryDeployment {
  async progressStage() {
    const metrics = await this.getMetrics();

    if (metrics.errorRate > 0.01) {
      // Rollback automatique
      await this.rollback();
      return;
    }

    if (metrics.latencyP99 > 500) {
      // Pause et alerte
      await this.pause();
      return;
    }

    // Passer au stage suivant
    await this.nextStage();
  }
}
```

### 2. Ring Deployment

```typescript
const rings = {
  ring0: ['internal-users'],           // Employés
  ring1: ['beta-testers'],              // Beta users
  ring2: ['region:europe'],             // Europe d'abord
  ring3: ['all'],                       // Tout le monde
};

function getUserRing(user: User): number {
  if (user.email.endsWith('@company.com')) return 0;
  if (user.isBetaTester) return 1;
  if (user.region === 'europe') return 2;
  return 3;
}

function isEnabled(flag: string, user: User): boolean {
  const flagConfig = flags.get(flag);
  const userRing = getUserRing(user);
  return userRing <= flagConfig.enabledRing;
}
```

---

## Toggle Cleanup

### Le problème du toggle debt

```typescript
// ❌ MAUVAIS - Toggles jamais nettoyés
if (flags.isEnabled('new-feature')) {
  if (flags.isEnabled('new-feature-v2')) {
    if (flags.isEnabled('new-feature-v2-hotfix')) {
      // Code illisible, toggles obsolètes
    }
  }
}
```

### Solution : Toggle avec expiration

```typescript
interface FeatureFlagConfig {
  name: string;
  enabled: boolean;
  owner: string;           // Qui est responsable
  createdAt: Date;
  expiresAt: Date;         // Date de cleanup obligatoire
  ticket: string;          // Ticket de tracking
}

class ManagedFeatureFlags {
  isEnabled(flag: string): boolean {
    const config = this.flags.get(flag);

    // Alerter si expiré
    if (config.expiresAt < new Date()) {
      this.alert(`Toggle ${flag} expired! Owner: ${config.owner}`);
    }

    return config.enabled;
  }

  // Script de cleanup
  async cleanupExpired() {
    const expired = this.flags.filter(f => f.expiresAt < new Date());

    for (const flag of expired) {
      console.log(`Expired: ${flag.name}`);
      console.log(`  Owner: ${flag.owner}`);
      console.log(`  Ticket: ${flag.ticket}`);
      console.log(`  Created: ${flag.createdAt}`);
    }
  }
}
```

### Linting pour toggles

```typescript
// ESLint rule custom
const rule = {
  meta: { type: 'suggestion' },
  create(context) {
    return {
      CallExpression(node) {
        if (isFeatureToggleCall(node)) {
          const toggleName = getToggleName(node);
          const toggleConfig = loadToggleConfig(toggleName);

          if (toggleConfig.expiresAt < new Date()) {
            context.report({
              node,
              message: `Toggle '${toggleName}' has expired. Remove it.`,
            });
          }
        }
      },
    };
  },
};
```

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Strategy** | Toggle sélectionne la stratégie |
| **Circuit Breaker** | Ops toggle automatique |
| **Branch by Abstraction** | Migration progressive |
| **Canary Release** | Rollout progressif |

---

## Outils populaires

| Outil | Type | Features |
|-------|------|----------|
| LaunchDarkly | SaaS | Full-featured, SDKs |
| Split.io | SaaS | A/B testing focus |
| Unleash | Open-source | Self-hosted |
| ConfigCat | SaaS | Simple, abordable |
| Flagsmith | Open-source | Self-hosted/Cloud |

---

## Anti-patterns

| Anti-pattern | Problème | Solution |
|--------------|----------|----------|
| Toggle permanent | Code mort | Expiration dates |
| Nested toggles | Complexité | Refactor, un toggle par feature |
| Toggle dans toggle | Illisible | Combiner en un seul |
| Pas de default | Crash si absent | Toujours un fallback |
| Pas de monitoring | Aveugle | Dashboard de toggles |

---

## Sources

- [Martin Fowler - Feature Toggles](https://martinfowler.com/articles/feature-toggles.html)
- [Pete Hodgson - Feature Toggles (Feature Flags)](https://www.martinfowler.com/articles/feature-toggles.html)
- [LaunchDarkly Blog](https://launchdarkly.com/blog/)
