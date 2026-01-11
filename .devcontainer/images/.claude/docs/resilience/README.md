# Resilience Patterns

Patterns pour construire des systemes robustes et tolerants aux pannes.

---

## Patterns documentes

| Pattern | Fichier | Usage |
|---------|---------|-------|
| Circuit Breaker | [circuit-breaker.md](circuit-breaker.md) | Prevenir les pannes en cascade |
| Retry | [retry.md](retry.md) | Reessayer les operations echouees |
| Timeout | [timeout.md](timeout.md) | Limiter le temps d'attente |
| Bulkhead | [bulkhead.md](bulkhead.md) | Isoler les ressources |
| Rate Limiting | [rate-limiting.md](rate-limiting.md) | Controler le debit |
| Health Check | [health-check.md](health-check.md) | Verifier l'etat des services |

---

## Tableau de decision

| Probleme | Pattern | Quand l'utiliser |
|----------|---------|------------------|
| Service externe instable | Circuit Breaker | Appels HTTP, DB, APIs tierces |
| Erreurs transitoires | Retry | Timeouts reseau, 503, locks |
| Attente infinie | Timeout | Tout appel externe |
| Surcharge d'un composant | Bulkhead | Isolation thread pools |
| Trop de requetes | Rate Limiting | APIs publiques, protection DoS |
| Etat du service inconnu | Health Check | Kubernetes, load balancers |

---

## Combinaison recommandee

```
Request → Rate Limiter → Timeout → Circuit Breaker → Retry → Service
           (1)            (2)          (3)            (4)
```

### Ordre d'application

1. **Rate Limiter** : Rejeter le surplus avant tout traitement
2. **Timeout** : Limiter le temps total de l'operation
3. **Circuit Breaker** : Fail-fast si service defaillant
4. **Retry** : Reessayer les erreurs transitoires

---

## Stack technologique

| Langage | Librairie recommandee |
|---------|----------------------|
| Node.js | `cockatiel`, `opossum` |
| Java | Resilience4j |
| Go | `sony/gobreaker`, `avast/retry-go` |
| Python | `tenacity`, `pybreaker` |
| .NET | Polly |

---

## Metriques cles

| Pattern | Metriques a surveiller |
|---------|------------------------|
| Circuit Breaker | open_count, state_changes, rejection_rate |
| Retry | retry_count, final_success_rate, avg_attempts |
| Timeout | timeout_count, p99_latency |
| Bulkhead | queue_size, rejection_count, active_threads |
| Rate Limiting | accepted_rate, rejected_rate, current_tokens |
| Health Check | probe_latency, failure_count, uptime |

---

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Retry sans backoff | Surcharge le service | Exponential backoff + jitter |
| Timeout trop long | Epuisement des ressources | Adapter au SLA |
| Circuit jamais ouvert | Threshold trop haut | Calibrer sur metriques reelles |
| Pas de fallback | Erreur propagee | Graceful degradation |
| Health check superficiel | Faux positifs | Deep health check |

---

## Sources

- [Microsoft - Resiliency patterns](https://learn.microsoft.com/en-us/azure/architecture/patterns/category/resiliency)
- [Netflix - Fault Tolerance](https://netflixtechblog.com/fault-tolerance-in-a-high-volume-distributed-system-91ab4faae74a)
- [Release It! - Michael Nygard](https://pragprog.com/titles/mnee2/release-it-second-edition/)
