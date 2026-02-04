# DevOps Patterns

Stratégies de déploiement et pratiques d'infrastructure moderne.

---

## Fichiers

### Stratégies de déploiement

| Fichier | Contenu | Usage |
|---------|---------|-------|
| [gitops.md](gitops.md) | Git comme source de vérité | Déploiement déclaratif |
| [iac.md](iac.md) | Infrastructure as Code | Gestion infrastructure |
| [feature-toggles.md](feature-toggles.md) | Feature Flags | Activation dynamique |
| [blue-green.md](blue-green.md) | Blue-Green Deployment | Zero-downtime |
| [canary.md](canary.md) | Canary Deployment | Rollout progressif |
| [rolling-update.md](rolling-update.md) | Rolling Update | Mise à jour progressive |
| [immutable-infrastructure.md](immutable-infrastructure.md) | Infrastructure immuable | Serveurs jetables |
| [ab-testing.md](ab-testing.md) | A/B Testing | Expérimentation |

### Infrastructure & Outils

| Fichier | Contenu | Usage |
|---------|---------|-------|
| [vault-patterns.md](vault-patterns.md) | HashiCorp Vault | PKI, VSO, AppRole |
| [terragrunt-patterns.md](terragrunt-patterns.md) | Terragrunt | Multi-environment IaC |
| [terraform-documentation.md](terraform-documentation.md) | Terraform docs | Structure & terraform-docs |
| [cilium-l2-loadbalancer.md](cilium-l2-loadbalancer.md) | Cilium CNI | L2 LoadBalancer bare-metal |
| [ansible-roles-structure.md](ansible-roles-structure.md) | Ansible roles | Validate-first pattern |

---

## Tableau de décision - Stratégies de déploiement

| Stratégie | Downtime | Risque | Rollback | Coût Infra | Complexité |
|-----------|----------|--------|----------|------------|------------|
| **Recreate** | Oui | Haut | Lent | Bas | Simple |
| **Rolling Update** | Non | Moyen | Moyen | Bas | Simple |
| **Blue-Green** | Non | Bas | Instantané | Double | Moyen |
| **Canary** | Non | Très Bas | Rapide | +10-20% | Élevé |
| **A/B Testing** | Non | Bas | Rapide | +10-20% | Élevé |

---

## Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────┐
│                    STRATÉGIES DE DÉPLOIEMENT                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Recreate     Rolling      Blue-Green    Canary      A/B Test  │
│  ┌───┐        ┌─┬─┬─┐      ┌───┬───┐    ┌───┬─┐    ┌───┬───┐  │
│  │old│        │o│o│n│      │ B │ G │    │99%│1%│   │50%│50%│  │
│  │ ↓ │        │ │n│n│      │   │   │    │old│new   │ A │ B │  │
│  │new│        │n│n│n│      │   │   │    └───┴─┘    └───┴───┘  │
│  └───┘        └─┴─┴─┘      └───┴───┘                           │
│                                                                  │
│  Simple       Progressif   Instantané   Progressif  Expérience │
│  Downtime     Pas de down  Rollback     Métriques   Métriques  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quand utiliser quelle stratégie

| Besoin | Stratégie recommandée |
|--------|----------------------|
| MVP / Dev environment | Recreate |
| Production standard | Rolling Update |
| Zero-downtime critique | Blue-Green |
| Validation métriques avant rollout | Canary |
| Tester UX / Conversion | A/B Testing |
| Changements d'infrastructure | Immutable Infrastructure |
| Gestion déclarative | GitOps + IaC |
| Activation/Désactivation dynamique | Feature Toggles |

---

## Combinaisons recommandées

### Stack moderne (recommandé)

```
GitOps + IaC + Canary + Feature Toggles
         │
         ▼
┌─────────────────────────────────────┐
│  Git Repository (Source of Truth)    │
│  ├── infrastructure/ (Terraform)     │
│  ├── kubernetes/ (manifests)         │
│  └── config/ (feature flags)         │
└─────────────────────────────────────┘
```

### Par taille d'équipe

| Taille équipe | Stratégie |
|---------------|-----------|
| Solo / Startup | Recreate + Feature Toggles |
| Petite (5-10) | Rolling Update + GitOps |
| Moyenne (10-50) | Blue-Green + IaC |
| Grande (50+) | Canary + A/B + Full GitOps |

---

## Flux de décision

```
                    Besoin de déployer
                           │
                           ▼
              ┌─── Tolérance downtime? ───┐
              │                            │
            Oui                          Non
              │                            │
              ▼                            ▼
          Recreate              ┌── Rollback rapide? ──┐
                                │                       │
                              Oui                     Non
                                │                       │
                                ▼                       ▼
                ┌── Validation métriques? ──┐    Rolling Update
                │                            │
              Oui                          Non
                │                            │
                ▼                            ▼
            Canary                      Blue-Green
```

---

## Outils par stratégie

| Stratégie | Outils |
|-----------|--------|
| Blue-Green | AWS CodeDeploy, Kubernetes, Istio |
| Canary | Argo Rollouts, Flagger, Spinnaker |
| Rolling | Kubernetes native, ECS |
| A/B Testing | LaunchDarkly, Split.io, Optimizely |
| GitOps | Argo CD, Flux, Jenkins X |
| IaC | Terraform, Pulumi, CloudFormation |

---

## Patterns liés

| Pattern | Catégorie | Relation |
|---------|-----------|----------|
| Circuit Breaker | cloud/ | Protection services |
| Saga | cloud/ | Transactions distribuées |
| Feature Toggles | devops/ | Activation features |
| Immutable Infrastructure | devops/ | Serveurs jetables |

---

## Sources

- [Martin Fowler - Deployment Strategies](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)
