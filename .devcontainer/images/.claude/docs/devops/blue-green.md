# Blue-Green Deployment

> Deux environnements identiques permettant un basculement instantané.

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOAD BALANCER                            │
│                              │                                   │
│                    ┌─────────┴─────────┐                        │
│                    │   Router/Switch   │                        │
│                    └─────────┬─────────┘                        │
│                              │                                   │
│              ┌───────────────┼───────────────┐                  │
│              │               │               │                  │
│              ▼               │               ▼                  │
│     ┌─────────────┐          │      ┌─────────────┐            │
│     │    BLUE     │          │      │    GREEN    │            │
│     │   (v1.0)    │ ◀────────┘      │   (v1.1)    │            │
│     │   ACTIVE    │                 │   STANDBY   │            │
│     └─────────────┘                 └─────────────┘            │
│            │                               │                    │
│            ▼                               ▼                    │
│     ┌─────────────┐                 ┌─────────────┐            │
│     │   Blue DB   │                 │  Green DB   │            │
│     └─────────────┘                 └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

## Workflow de déploiement

```
Phase 1: État initial                Phase 2: Déployer sur Green
┌──────┐        ┌──────┐            ┌──────┐        ┌──────┐
│ Blue │ ◀─100%─│Router│            │ Blue │ ◀─100%─│Router│
│ v1.0 │        └──────┘            │ v1.0 │        └──────┘
├──────┤                            ├──────┤
│Green │ (idle)                     │Green │ ← Deploy v1.1
│ v1.0 │                            │ v1.1 │
└──────┘                            └──────┘

Phase 3: Tests Green                 Phase 4: Switch traffic
┌──────┐        ┌──────┐            ┌──────┐        ┌──────┐
│ Blue │ ◀─100%─│Router│            │ Blue │        │Router│─100%─▶ │Green│
│ v1.0 │        └──────┘            │ v1.0 │        └──────┘         │ v1.1│
├──────┤            │               ├──────┤                         └──────┘
│Green │ ◀─ Test ──┘                │Green │ ◀─ ACTIVE
│ v1.1 │   (internal)               │ v1.1 │
└──────┘                            └──────┘
```

## Implémentation Kubernetes

```yaml
# blue-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: app
        image: myapp:1.0.0
        ports:
        - containerPort: 8080
---
# green-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: app
        image: myapp:1.1.0
        ports:
        - containerPort: 8080
---
# service.yaml - Switch via selector
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  selector:
    app: myapp
    version: blue  # ← Changer en "green" pour switch
  ports:
  - port: 80
    targetPort: 8080
```

## Script de bascule

```bash
#!/bin/bash
# blue-green-switch.sh

CURRENT=$(kubectl get svc myapp -o jsonpath='{.spec.selector.version}')

if [ "$CURRENT" == "blue" ]; then
  NEW="green"
else
  NEW="blue"
fi

echo "Switching from $CURRENT to $NEW..."

# Switch traffic
kubectl patch svc myapp -p "{\"spec\":{\"selector\":{\"version\":\"$NEW\"}}}"

echo "Traffic now routing to $NEW"

# Verify
kubectl get svc myapp -o wide
```

## Gestion de la base de données

### Option 1: Base partagée (simple)

```
┌──────┐     ┌──────┐
│ Blue │────▶│  DB  │◀────│Green │
└──────┘     └──────┘     └──────┘

Contrainte: Migrations backward-compatible
```

### Option 2: Bases séparées avec sync

```
┌──────┐     ┌────────┐     ┌──────┐
│ Blue │────▶│Blue DB │     │Green │
└──────┘     └────────┘     └──────┘
                  │              │
                  │ sync         │
                  ▼              ▼
             ┌────────┐     ┌────────┐
             │Replica │────▶│Green DB│
             └────────┘     └────────┘
```

## Quand utiliser

| Utiliser | Eviter |
|----------|--------|
| Zero-downtime critique | Budget limité (double infra) |
| Rollback instantané requis | Données temps réel (sync DB) |
| Équipes matures | Schémas DB incompatibles |
| Applications stateless | Systèmes hautement stateful |
| Compliance/Audit | Petits projets/MVPs |

## Avantages

- **Rollback instantané** : Switch retour en secondes
- **Zero-downtime** : Aucune interruption de service
- **Tests en production** : Valider sur Green avant switch
- **Confiance** : Environnement identique testé
- **Simplicité conceptuelle** : Facile à comprendre

## Inconvénients

- **Coût** : Double infrastructure permanente
- **Synchronisation DB** : Complexe avec données
- **Sessions utilisateur** : Perdues au switch
- **Cold start** : Green peut être "froid"
- **Schémas DB** : Migrations délicates

## Exemples réels

| Entreprise | Usage |
|------------|-------|
| **Netflix** | Déploiements régionaux |
| **Amazon** | Services critiques |
| **Etsy** | Deploy continu |
| **Facebook** | Infrastructure massive |

## Migration path

### Depuis Rolling Update

```
1. Créer second environnement
2. Configurer load balancer avec routing
3. Automatiser switch dans CI/CD
4. Implémenter health checks pré-switch
```

### Vers Canary

```
1. Ajouter routage progressif (1%, 10%, 50%, 100%)
2. Intégrer métriques pour décision automatique
3. Conserver Blue-Green comme fallback
```

## Patterns liés

| Pattern | Relation |
|---------|----------|
| Canary | Évolution avec routage progressif |
| Immutable Infrastructure | Blue/Green sont immuables |
| Feature Toggles | Alternative pour petits changements |
| GitOps | Gestion déclarative des environnements |

## Checklist pré-déploiement

- [ ] Green deployment créé et healthy
- [ ] Tests automatisés passés sur Green
- [ ] Base de données migrée (si applicable)
- [ ] Health checks configurés
- [ ] Rollback plan documenté
- [ ] Monitoring en place
- [ ] Équipe alerte pendant switch

## Sources

- [Martin Fowler - Blue Green Deployment](https://martinfowler.com/bliki/BlueGreenDeployment.html)
- [Kubernetes Blue-Green](https://kubernetes.io/blog/2018/04/30/zero-downtime-deployment-kubernetes-jenkins/)
- [AWS Blue-Green](https://docs.aws.amazon.com/whitepapers/latest/blue-green-deployments/welcome.html)
