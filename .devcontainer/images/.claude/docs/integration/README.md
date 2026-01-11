# Integration Patterns

Patterns pour integrer des systemes heterogenes et gerer les frontieres applicatives.

---

## Patterns documentes

| Pattern | Fichier | Usage |
|---------|---------|-------|
| API Gateway | [api-gateway.md](api-gateway.md) | Point d'entree unique pour APIs |
| Backend for Frontend | [bff.md](bff.md) | API dediee par type de client |
| Anti-Corruption Layer | [anti-corruption-layer.md](anti-corruption-layer.md) | Isoler les systemes legacy |
| Service Mesh | [service-mesh.md](service-mesh.md) | Communication inter-services |
| Sidecar | [sidecar.md](sidecar.md) | Fonctionnalites transverses |

---

## Tableau de decision

| Probleme | Pattern | Quand l'utiliser |
|----------|---------|------------------|
| Multiples microservices exposes | API Gateway | Facade unifiee pour clients |
| Clients heterogenes (web, mobile) | BFF | Besoins specifiques par plateforme |
| Integration systeme legacy | Anti-Corruption Layer | Proteger le nouveau domaine |
| Observabilite, securite, retry | Service Mesh | Infrastructure as code |
| Fonctionnalite transverse | Sidecar | Logging, proxy, monitoring |

---

## Relation entre patterns

```
┌─────────────────────────────────────────────────────────────────┐
│                   INTEGRATION ARCHITECTURE                       │
│                                                                  │
│  Clients                                                         │
│  ┌─────┐  ┌─────┐  ┌─────┐                                      │
│  │ Web │  │ iOS │  │ IoT │                                      │
│  └──┬──┘  └──┬──┘  └──┬──┘                                      │
│     │        │        │                                          │
│     ▼        ▼        ▼                                          │
│  ┌─────┐  ┌─────┐  ┌─────┐         Backend for Frontend         │
│  │BFF-W│  │BFF-M│  │BFF-I│                                      │
│  └──┬──┘  └──┬──┘  └──┬──┘                                      │
│     │        │        │                                          │
│     └────────┼────────┘                                          │
│              │                                                   │
│              ▼                                                   │
│       ┌─────────────┐                  API Gateway               │
│       │ API Gateway │                                            │
│       └──────┬──────┘                                            │
│              │                                                   │
│     ┌────────┼────────┐                                          │
│     ▼        ▼        ▼                                          │
│  ┌─────┐  ┌─────┐  ┌─────┐         Service Mesh (Sidecar)       │
│  │ Svc │  │ Svc │  │ ACL │─────► Legacy System                  │
│  │  A  │  │  B  │  │     │       Anti-Corruption Layer          │
│  └─────┘  └─────┘  └─────┘                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Combinaisons courantes

| Scenario | Patterns | Justification |
|----------|----------|---------------|
| SaaS multi-tenant | API Gateway + BFF | Unification + personnalisation |
| Migration legacy | ACL + Strangler Fig | Isolation + remplacement progressif |
| Microservices | Service Mesh + Sidecar | Observabilite + resilience |
| Mobile-first | BFF + API Gateway | Optimisation reseau |

---

## Technologies

| Pattern | Technologies |
|---------|-------------|
| API Gateway | Kong, AWS API Gateway, Apigee, Traefik |
| BFF | Express, NestJS, GraphQL Federation |
| ACL | Adapter pattern, Facade, Translation |
| Service Mesh | Istio, Linkerd, Consul Connect |
| Sidecar | Envoy, Dapr, Ambassador |

---

## Metriques cles

| Pattern | Metriques |
|---------|-----------|
| API Gateway | Latency, error rate, requests/sec, auth failures |
| BFF | Response size, cache hit rate, aggregation time |
| ACL | Translation errors, legacy calls, sync lag |
| Service Mesh | mTLS coverage, retry rate, circuit state |
| Sidecar | Resource usage, proxy latency |

---

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Gateway monolithique | SPOF, bottleneck | Plusieurs gateways specialises |
| BFF generique | Perd l'interet du BFF | Un BFF par type de client |
| ACL trop fin | Complexite excessive | Grouper par bounded context |
| Mesh overhead | Latence ajoutee | Evaluer le besoin reel |
| Sidecar trop lourd | Consommation ressources | Optimiser ou consolider |

---

## Sources

- [Microsoft - API Gateway Pattern](https://learn.microsoft.com/en-us/azure/architecture/microservices/design/gateway)
- [Sam Newman - Building Microservices](https://samnewman.io/books/building_microservices_2nd_edition/)
- [Martin Fowler - BFF](https://samnewman.io/patterns/architectural/bff/)
- [DDD - Anti-Corruption Layer](https://docs.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)
