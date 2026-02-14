# GitOps

> Git as source of truth pour l'infrastructure et les applications.

## Principle

```
┌─────────────────────────────────────────────────────────────────┐
│                        GIT REPOSITORY                            │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  infrastructure/                                         │    │
│  │  ├── kubernetes/                                        │    │
│  │  │   ├── deployment.yaml                                │    │
│  │  │   └── service.yaml                                   │    │
│  │  └── terraform/                                         │    │
│  │      └── main.tf                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  │ sync
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GITOPS OPERATOR                             │
│              (Argo CD, Flux, Jenkins X)                          │
└─────────────────────────────────┬───────────────────────────────┘
                                  │
                                  │ apply
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES CLUSTER                            │
│              (État réel = État désiré dans Git)                  │
└─────────────────────────────────────────────────────────────────┘
```

## Principes fondamentaux

1. **Déclaratif** : Décrire l'état désiré, pas les actions
2. **Versionné** : Tout dans Git (historique, rollback)
3. **Automatisé** : Réconciliation continue
4. **Pull-based** : L'opérateur tire les changements

## Workflow

```
Developer                    Git                     Cluster
    │                         │                         │
    │  1. Push manifest       │                         │
    │ ───────────────────────▶│                         │
    │                         │                         │
    │                         │  2. Detect change       │
    │                         │ ◀───────────────────────│
    │                         │                         │
    │                         │  3. Apply               │
    │                         │ ───────────────────────▶│
    │                         │                         │
    │                         │  4. Report status       │
    │                         │ ◀───────────────────────│
    │                         │                         │
```

## Structure de repo

### Mono-repo

```
gitops-repo/
├── apps/
│   ├── frontend/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   └── service.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── prod/
│   └── backend/
│       └── ...
├── infrastructure/
│   ├── monitoring/
│   └── ingress/
└── clusters/
    ├── dev/
    ├── staging/
    └── prod/
```

### Multi-repo

```
app-frontend/        # Code + Dockerfile
app-backend/         # Code + Dockerfile
gitops-config/       # Manifests Kubernetes
infrastructure/      # Terraform
```

## Outils

| Outil | Type | Description |
|-------|------|-------------|
| **Argo CD** | Kubernetes GitOps | UI riche, sync status |
| **Flux** | Kubernetes GitOps | Modulaire, léger |
| **Jenkins X** | CI/CD GitOps | Full pipeline |
| **Terraform** | IaC | Infrastructure cloud |

## Exemple Argo CD

```yaml
# Application Argo CD
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/gitops-repo
    targetRevision: main
    path: apps/my-app/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Exemple Flux

```yaml
# GitRepository
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/gitops-repo
  ref:
    branch: main
---
# Kustomization
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: my-repo
  path: ./apps/my-app
  prune: true
```

## Avantages

- **Audit** : Historique Git complet
- **Rollback** : `git revert`
- **Review** : Pull Request pour les changements
- **Sécurité** : Pas d'accès kubectl direct
- **DR** : Reconstruire cluster depuis Git

## Challenges

| Challenge | Solution |
|-----------|----------|
| Secrets | Sealed Secrets, SOPS, Vault |
| Ordre de déploiement | Sync waves, dependencies |
| Environnements | Kustomize overlays |
| Drift detection | Reconciliation loop |

## Related Patterns

| Pattern | Relation |
|---------|----------|
| Infrastructure as Code | GitOps pour IaC |
| Immutable Infrastructure | Declarative deployment |
| Blue-Green | Via Git branches |

## Sources

- [GitOps - Weaveworks](https://www.weave.works/technologies/gitops/)
- [Argo CD](https://argo-cd.readthedocs.io/)
- [Flux](https://fluxcd.io/)
