# A/B Testing

> Expérimentation contrôlée pour valider des hypothèses avec des métriques.

**Lié à :** [Feature Toggles](feature-toggles.md) (implémentation technique)

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                        A/B TESTING                               │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   TRAFFIC SPLITTER                        │   │
│  │                         │                                 │   │
│  │         ┌───────────────┴───────────────┐                │   │
│  │         │                               │                │   │
│  │        50%                             50%               │   │
│  │         │                               │                │   │
│  │         ▼                               ▼                │   │
│  │  ┌─────────────┐                 ┌─────────────┐        │   │
│  │  │  CONTROL    │                 │  VARIANT    │        │   │
│  │  │    (A)      │                 │    (B)      │        │   │
│  │  │             │                 │             │        │   │
│  │  │ ┌─────────┐ │                 │ ┌─────────┐ │        │   │
│  │  │ │ Button  │ │                 │ │ Button  │ │        │   │
│  │  │ │  Blue   │ │                 │ │  Green  │ │        │   │
│  │  │ └─────────┘ │                 │ └─────────┘ │        │   │
│  │  └─────────────┘                 └─────────────┘        │   │
│  │         │                               │                │   │
│  │         ▼                               ▼                │   │
│  │  ┌─────────────┐                 ┌─────────────┐        │   │
│  │  │ Conversion  │                 │ Conversion  │        │   │
│  │  │    2.1%     │                 │    2.8%     │        │   │
│  │  └─────────────┘                 └─────────────┘        │   │
│  │                                                          │   │
│  │              Winner: Variant B (+33%)                    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      EXPERIMENTATION PLATFORM                    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    EXPERIMENT CONFIG                      │   │
│  │  {                                                        │   │
│  │    name: "checkout-redesign",                             │   │
│  │    hypothesis: "Green CTA increases conversion",          │   │
│  │    metric: "purchase_completed",                          │   │
│  │    variants: [                                            │   │
│  │      { name: "control", weight: 50 },                     │   │
│  │      { name: "green_button", weight: 50 }                 │   │
│  │    ],                                                     │   │
│  │    audience: { country: ["US", "CA"], device: "mobile" }  │   │
│  │  }                                                        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────┐    ┌──────────────┐    ┌──────────┐              │
│  │ User     │───▶│ Assignment   │───▶│ Variant  │              │
│  │ Request  │    │ Service      │    │ Response │              │
│  └──────────┘    └──────────────┘    └──────────┘              │
│                         │                    │                   │
│                         ▼                    ▼                   │
│                  ┌──────────────┐    ┌──────────────┐           │
│                  │ Tracking     │    │ Analytics    │           │
│                  │ Events       │───▶│ Dashboard    │           │
│                  └──────────────┘    └──────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

## Implémentation

### Service d'expérimentation

```typescript
interface Experiment {
  id: string;
  name: string;
  hypothesis: string;
  variants: Variant[];
  metrics: Metric[];
  audience?: AudienceRule[];
  startDate: Date;
  endDate?: Date;
  status: 'draft' | 'running' | 'paused' | 'completed';
}

interface Variant {
  name: string;
  weight: number;  // 0-100
  config?: Record<string, unknown>;
}

interface Metric {
  name: string;
  type: 'conversion' | 'revenue' | 'engagement' | 'retention';
  goal: 'increase' | 'decrease';
}

class ExperimentService {
  private experiments: Map<string, Experiment> = new Map();
  private assignments: Map<string, Map<string, string>> = new Map();

  getVariant(userId: string, experimentId: string): string | null {
    const experiment = this.experiments.get(experimentId);
    if (!experiment || experiment.status !== 'running') {
      return null;
    }

    // Vérifier audience
    if (!this.matchesAudience(userId, experiment.audience)) {
      return null;
    }

    // Assignation consistante (sticky)
    const cached = this.getAssignment(userId, experimentId);
    if (cached) return cached;

    // Hash déterministe pour répartition
    const hash = this.hashUserId(userId, experimentId);
    const variant = this.selectVariant(hash, experiment.variants);

    this.saveAssignment(userId, experimentId, variant);
    this.trackExposure(userId, experimentId, variant);

    return variant;
  }

  private hashUserId(userId: string, experimentId: string): number {
    const combined = `${userId}:${experimentId}`;
    let hash = 0;
    for (let i = 0; i < combined.length; i++) {
      const char = combined.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash;
    }
    return Math.abs(hash) % 100;
  }

  private selectVariant(hash: number, variants: Variant[]): string {
    let cumulative = 0;
    for (const variant of variants) {
      cumulative += variant.weight;
      if (hash < cumulative) {
        return variant.name;
      }
    }
    return variants[0].name;
  }
}
```

### Tracking des métriques

```typescript
interface TrackingEvent {
  userId: string;
  experimentId: string;
  variant: string;
  eventType: 'exposure' | 'conversion' | 'custom';
  eventName?: string;
  value?: number;
  timestamp: Date;
  metadata?: Record<string, unknown>;
}

class AnalyticsService {
  async trackEvent(event: TrackingEvent): Promise<void> {
    await this.eventStore.insert({
      ...event,
      timestamp: new Date(),
      sessionId: this.getSessionId(event.userId),
    });
  }

  async getExperimentResults(experimentId: string): Promise<ExperimentResults> {
    const events = await this.eventStore.query({
      experimentId,
      eventType: { $in: ['exposure', 'conversion'] },
    });

    const byVariant = this.groupByVariant(events);

    return {
      variants: Object.entries(byVariant).map(([variant, data]) => ({
        name: variant,
        exposures: data.exposures,
        conversions: data.conversions,
        conversionRate: data.conversions / data.exposures,
        confidence: this.calculateConfidence(data, byVariant.control),
      })),
      winner: this.determineWinner(byVariant),
      statisticalSignificance: this.isSignificant(byVariant),
    };
  }

  private calculateConfidence(
    variant: VariantData,
    control: VariantData
  ): number {
    // Z-test pour proportions
    const p1 = variant.conversions / variant.exposures;
    const p2 = control.conversions / control.exposures;
    const n1 = variant.exposures;
    const n2 = control.exposures;

    const pooledP = (variant.conversions + control.conversions) / (n1 + n2);
    const se = Math.sqrt(pooledP * (1 - pooledP) * (1/n1 + 1/n2));
    const z = (p1 - p2) / se;

    // Convertir z-score en confiance
    return this.zToConfidence(z);
  }
}
```

### Usage côté client

```typescript
// React Hook
function useExperiment(experimentId: string) {
  const [variant, setVariant] = useState<string | null>(null);
  const { userId } = useAuth();

  useEffect(() => {
    async function fetchVariant() {
      const result = await experimentService.getVariant(userId, experimentId);
      setVariant(result);
    }
    fetchVariant();
  }, [userId, experimentId]);

  return {
    variant,
    isLoading: variant === null,
    isControl: variant === 'control',
  };
}

// Usage
function CheckoutButton() {
  const { variant, isLoading } = useExperiment('checkout-button-color');

  if (isLoading) return <ButtonSkeleton />;

  return (
    <Button
      color={variant === 'green_button' ? 'green' : 'blue'}
      onClick={() => {
        trackConversion('checkout-button-color', 'click');
        handleCheckout();
      }}
    >
      Checkout
    </Button>
  );
}
```

## Calcul de taille d'échantillon

```typescript
function calculateSampleSize(
  baselineConversion: number,
  minimumDetectableEffect: number,  // ex: 0.05 = 5% lift
  power: number = 0.8,
  significance: number = 0.05
): number {
  const p1 = baselineConversion;
  const p2 = baselineConversion * (1 + minimumDetectableEffect);

  const zAlpha = 1.96;  // 95% significance
  const zBeta = 0.84;   // 80% power

  const pooledP = (p1 + p2) / 2;
  const effect = Math.abs(p2 - p1);

  const n = 2 * pooledP * (1 - pooledP) *
    Math.pow((zAlpha + zBeta) / effect, 2);

  return Math.ceil(n);
}

// Exemple: 2% conversion, détect 10% lift
// calculateSampleSize(0.02, 0.10) ≈ 15,000 users per variant
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Trafic suffisant (>1000/variante) | Faible trafic |
| Hypothèse claire | Exploration vague |
| Métriques définies | Pas de tracking |
| Durée suffisante (1-4 semaines) | Besoin résultat immédiat |
| Changements UI/UX | Changements techniques |

## Avantages

- **Données réelles** : Décisions basées sur faits
- **Réduction risque** : Valider avant déploiement complet
- **Apprentissage continu** : Culture data-driven
- **ROI mesurable** : Impact quantifiable
- **Évite opinions** : Données vs intuition

## Inconvénients

- **Temps** : Semaines pour résultats significatifs
- **Volume** : Besoin de trafic important
- **Complexité** : Infrastructure dédiée
- **Faux positifs** : Risque statistique
- **Pollution** : Interactions entre tests

## Exemples réels

| Entreprise | Exemple célèbre |
|------------|-----------------|
| **Google** | 41 nuances de bleu (liens) |
| **Netflix** | Thumbnails personnalisées |
| **Amazon** | One-click checkout |
| **Booking** | FOMO messages |
| **Airbnb** | Design du search |

## Outils

| Outil | Type | Caractéristiques |
|-------|------|------------------|
| **Optimizely** | SaaS | Full-stack, enterprise |
| **LaunchDarkly** | SaaS | Feature flags + A/B |
| **Split.io** | SaaS | Focus experimentation |
| **Google Optimize** | Free | GA integration |
| **Growthbook** | Open-source | Self-hosted |
| **Statsig** | SaaS | Stats avancées |

## Best Practices

1. **Une hypothèse par test** : Pas de changements multiples
2. **Taille échantillon** : Calculer avant de lancer
3. **Durée fixe** : Ne pas arrêter prématurément
4. **Segmentation** : Analyser par segment
5. **Documentation** : Hypothèse, résultats, learnings

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Feature Toggles | Implémentation technique |
| Canary | A/B sur infrastructure |
| Multivariate Testing | Extension avec combinaisons |
| Personalization | A/B + ML |

## Sources

- [Ronny Kohavi - Trustworthy Online Experiments](https://www.exp-platform.com/)
- [Evan Miller - Sample Size Calculator](https://www.evanmiller.org/ab-testing/)
- [Netflix Tech Blog - Experimentation](https://netflixtechblog.com/experimentation-is-a-major-focus-of-data-science-across-netflix-f67f29d0e0bb)
- [Booking.com - Experimentation Culture](https://blog.booking.com/)
