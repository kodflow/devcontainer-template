# Canary Deployment

> Déploiement progressif vers un sous-ensemble d'utilisateurs pour validation.

**Origine :** Canaris dans les mines de charbon (alerte précoce)

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOAD BALANCER                            │
│                              │                                   │
│                    ┌─────────┴─────────┐                        │
│                    │   Traffic Split   │                        │
│                    └─────────┬─────────┘                        │
│                              │                                   │
│              ┌───────────────┴───────────────┐                  │
│              │ 95%                       5%  │                  │
│              ▼                               ▼                  │
│     ┌─────────────┐                 ┌─────────────┐            │
│     │   STABLE    │                 │   CANARY    │            │
│     │   (v1.0)    │                 │   (v1.1)    │            │
│     │  3 replicas │                 │  1 replica  │            │
│     └─────────────┘                 └─────────────┘            │
│                                            │                    │
│                                     ┌──────┴──────┐            │
│                                     │  Métriques  │            │
│                                     │  Monitoring │            │
│                                     └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Phases de rollout

```
Phase 1: Canary 1%          Phase 2: Canary 10%
┌──────────────────┐        ┌──────────────────┐
│ Stable   │Canary │        │ Stable  │ Canary │
│  99%     │  1%   │        │  90%    │  10%   │
│  v1.0    │ v1.1  │        │  v1.0   │  v1.1  │
└──────────────────┘        └──────────────────┘
     │                           │
     │ Metrics OK?               │ Metrics OK?
     ▼                           ▼

Phase 3: Canary 50%          Phase 4: Full rollout
┌──────────────────┐        ┌──────────────────┐
│ Stable  │ Canary │        │      Canary      │
│  50%    │  50%   │        │      100%        │
│  v1.0   │  v1.1  │        │      v1.1        │
└──────────────────┘        └──────────────────┘
```

## Implémentation avec Argo Rollouts

```yaml
# rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      # Phase 1: 5% traffic
      - setWeight: 5
      - pause: {duration: 10m}

      # Phase 2: 25% traffic
      - setWeight: 25
      - pause: {duration: 10m}

      # Phase 3: 50% traffic
      - setWeight: 50
      - pause: {duration: 10m}

      # Phase 4: 100% (automatic)

      # Analyse automatique
      analysis:
        templates:
        - templateName: success-rate
        startingStep: 1

      # Anti-affinity pour résilience
      canaryMetadata:
        labels:
          role: canary
      stableMetadata:
        labels:
          role: stable

  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: app
        image: myapp:1.1.0
        ports:
        - containerPort: 8080
---
# analysis-template.yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  metrics:
  - name: success-rate
    interval: 1m
    successCondition: result[0] >= 0.95
    failureLimit: 3
    provider:
      prometheus:
        address: http://prometheus:9090
        query: |
          sum(rate(http_requests_total{status=~"2.*",app="myapp",role="canary"}[5m]))
          /
          sum(rate(http_requests_total{app="myapp",role="canary"}[5m]))
```

## Métriques de décision

```typescript
interface CanaryMetrics {
  // Métriques de base
  errorRate: number;        // < 1%
  latencyP99: number;       // < 500ms
  successRate: number;      // > 99%

  // Métriques business
  conversionRate?: number;  // Stable ou mieux
  revenuePerUser?: number;  // Stable ou mieux
}

interface CanaryDecision {
  action: 'promote' | 'pause' | 'rollback';
  reason: string;
}

function evaluateCanary(
  canaryMetrics: CanaryMetrics,
  baselineMetrics: CanaryMetrics
): CanaryDecision {
  // Échec si error rate > 1%
  if (canaryMetrics.errorRate > 0.01) {
    return { action: 'rollback', reason: 'Error rate too high' };
  }

  // Pause si latence dégradée
  if (canaryMetrics.latencyP99 > baselineMetrics.latencyP99 * 1.2) {
    return { action: 'pause', reason: 'Latency degraded 20%' };
  }

  // Promote si tout OK
  return { action: 'promote', reason: 'All metrics healthy' };
}
```

## Stratégies de routage

### Par pourcentage (standard)

```yaml
# Istio VirtualService
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - route:
    - destination:
        host: myapp
        subset: stable
      weight: 95
    - destination:
        host: myapp
        subset: canary
      weight: 5
```

### Par header (testing interne)

```yaml
http:
- match:
  - headers:
      x-canary:
        exact: "true"
  route:
  - destination:
      host: myapp
      subset: canary
- route:
  - destination:
      host: myapp
      subset: stable
```

### Par région géographique

```yaml
http:
- match:
  - headers:
      x-region:
        exact: "eu-west-1"
  route:
  - destination:
      host: myapp
      subset: canary
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Applications à fort trafic | Faible volume (pas assez de data) |
| Changements risqués | Changements triviaux |
| Validation métriques nécessaire | Pas de monitoring |
| Équipes DevOps matures | Équipes sans observabilité |
| Services critiques | Prototypes/MVPs |

## Avantages

- **Risque minimisé** : Impact limité si problème
- **Validation réelle** : Métriques en production
- **Rollback automatique** : Basé sur métriques
- **Confiance graduelle** : Augmentation progressive
- **A/B testing implicite** : Comparaison versions

## Inconvénients

- **Complexité** : Infrastructure de routage
- **Observabilité requise** : Métriques essentielles
- **Temps de déploiement** : Plus long que Blue-Green
- **Volume minimum** : Besoin de trafic significatif
- **État partagé** : Complexe avec données

## Exemples réels

| Entreprise | Implémentation |
|------------|----------------|
| **Google** | Rollout progressif GKE |
| **Netflix** | Spinnaker + Kayenta |
| **LinkedIn** | LiX (A/B + Canary) |
| **Facebook** | Gatekeeper system |
| **Spotify** | Backstage + Argo |

## Migration path

### Depuis Blue-Green

```
1. Implémenter split traffic (Istio, NGINX, etc.)
2. Ajouter métriques Prometheus/Datadog
3. Configurer seuils de décision
4. Automatiser promote/rollback
```

### Vers Progressive Delivery

```
1. Intégrer feature flags
2. Ajouter A/B testing
3. Automatiser analyse métriques
4. GitOps pour configuration
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Blue-Green | Prédécesseur, switch binaire |
| A/B Testing | Canary + expérimentation |
| Feature Toggles | Alternative granulaire |
| Circuit Breaker | Protection automatique |

## Checklist

- [ ] Métriques définies (SLI/SLO)
- [ ] Seuils de rollback configurés
- [ ] Alerting en place
- [ ] Runbook rollback documenté
- [ ] Traffic splitting configuré
- [ ] Dashboard canary vs stable

## Sources

- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
- [Flagger](https://flagger.app/)
- [Netflix Kayenta](https://netflixtechblog.com/automated-canary-analysis-at-netflix-with-kayenta-3260bc7acc69)
- [Google SRE Book](https://sre.google/sre-book/release-engineering/)
