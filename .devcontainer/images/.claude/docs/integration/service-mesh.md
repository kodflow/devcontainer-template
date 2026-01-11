# Service Mesh Pattern

> Infrastructure dediee a la communication inter-services avec observabilite, securite et resilience.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                      SERVICE MESH                                │
│                                                                  │
│  Sans Service Mesh:           Avec Service Mesh:                │
│                                                                  │
│  ┌─────┐    ┌─────┐           ┌─────┐    ┌─────┐               │
│  │Svc A│───►│Svc B│           │Svc A│    │Svc B│               │
│  └─────┘    └─────┘           └──┬──┘    └──┬──┘               │
│                                  │          │                    │
│  Chaque service gere:           ┌▼──────────▼┐                  │
│  - Retry                        │  Sidecar   │                  │
│  - Timeout                      │  Proxies   │                  │
│  - TLS                          └──────┬─────┘                  │
│  - Logging                             │                         │
│  - Tracing                      ┌──────▼─────┐                  │
│                                 │Control Plane│                  │
│                                 └────────────┘                  │
│                                                                  │
│                                 Infrastructure gere tout         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Composants

| Composant | Role |
|-----------|------|
| **Data Plane** | Sidecars qui interceptent le trafic |
| **Control Plane** | Configuration et politiques centralisees |
| **Sidecar Proxy** | Envoy, Linkerd-proxy |
| **Service Discovery** | Localisation des services |
| **Load Balancer** | Distribution du trafic |

---

## Fonctionnalites

| Categorie | Fonctionnalites |
|-----------|-----------------|
| **Traffic** | Load balancing, routing, retries, timeouts |
| **Security** | mTLS, authorization, encryption |
| **Observability** | Metrics, tracing, logging |
| **Resilience** | Circuit breaker, rate limiting, fault injection |

---

## Implementation avec Istio (Kubernetes)

### Installation

```yaml
# istio-operator.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
spec:
  profile: default
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
  meshConfig:
    accessLogFile: /dev/stdout
    enableTracing: true
```

---

### Configuration du namespace

```yaml
# Activer l'injection automatique de sidecar
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    istio-injection: enabled
```

---

### Virtual Service (Routing)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: product-service
spec:
  hosts:
    - product-service
  http:
    # Canary deployment: 90% v1, 10% v2
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: product-service
            subset: v2
    - route:
        - destination:
            host: product-service
            subset: v1
          weight: 90
        - destination:
            host: product-service
            subset: v2
          weight: 10
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: connect-failure,refused-stream,5xx
      timeout: 10s
```

---

### Destination Rule (Load Balancing & TLS)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: product-service
spec:
  host: product-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    loadBalancer:
      simple: LEAST_CONN
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    tls:
      mode: ISTIO_MUTUAL
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

---

### Authorization Policy (Security)

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: product-service-policy
  namespace: my-app
spec:
  selector:
    matchLabels:
      app: product-service
  rules:
    # Autoriser uniquement les appels depuis order-service
    - from:
        - source:
            principals:
              - cluster.local/ns/my-app/sa/order-service
      to:
        - operation:
            methods:
              - GET
              - POST
            paths:
              - /api/products/*
    # Autoriser les health checks
    - to:
        - operation:
            methods:
              - GET
            paths:
              - /health/*
```

---

### Peer Authentication (mTLS)

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: my-app
spec:
  mtls:
    mode: STRICT  # Enforce mTLS for all services
```

---

## Implementation TypeScript (Dapr)

```typescript
// Dapr comme alternative plus simple a Istio
import { DaprClient, DaprServer } from '@dapr/dapr';

const daprHost = process.env.DAPR_HOST ?? '127.0.0.1';
const daprPort = process.env.DAPR_HTTP_PORT ?? '3500';

class OrderService {
  private readonly dapr = new DaprClient({ daprHost, daprPort });

  async createOrder(order: Order): Promise<Order> {
    // Appel a product-service via Dapr sidecar
    // Beneficie automatiquement de:
    // - Service discovery
    // - mTLS
    // - Retries
    // - Tracing
    const product = await this.dapr.invoker.invoke(
      'product-service',      // App ID
      'products/' + order.productId,
      { method: 'GET' },
    );

    // Publish event via Dapr pub/sub
    await this.dapr.pubsub.publish(
      'order-pubsub',        // Pub/sub component
      'order-created',       // Topic
      { orderId: order.id, product },
    );

    // Store state via Dapr state store
    await this.dapr.state.save('order-store', [
      { key: `order-${order.id}`, value: order },
    ]);

    return order;
  }
}

// Configuration Dapr (components)
/*
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: order-store
spec:
  type: state.redis
  version: v1
  metadata:
    - name: redisHost
      value: redis:6379
---
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: order-pubsub
spec:
  type: pubsub.rabbitmq
  version: v1
  metadata:
    - name: host
      value: amqp://rabbitmq:5672
*/
```

---

## Observabilite avec Service Mesh

```typescript
// Les metriques sont collectees automatiquement par le mesh
// Mais on peut ajouter des metriques custom

import { trace, context, SpanKind } from '@opentelemetry/api';

const tracer = trace.getTracer('order-service');

async function processOrder(order: Order): Promise<void> {
  // Creer un span custom (le mesh ajoute deja les spans HTTP)
  const span = tracer.startSpan('process-order', {
    kind: SpanKind.INTERNAL,
    attributes: {
      'order.id': order.id,
      'order.total': order.total.amount,
    },
  });

  try {
    await context.with(trace.setSpan(context.active(), span), async () => {
      await validateOrder(order);
      await chargePayment(order);
      await updateInventory(order);
    });
    span.setStatus({ code: SpanStatusCode.OK });
  } catch (error) {
    span.setStatus({ code: SpanStatusCode.ERROR, message: error.message });
    throw error;
  } finally {
    span.end();
  }
}
```

---

## Comparaison des solutions

| Feature | Istio | Linkerd | Consul Connect | Dapr |
|---------|-------|---------|----------------|------|
| Complexity | Haute | Moyenne | Moyenne | Basse |
| Performance | Bonne | Excellente | Bonne | Bonne |
| mTLS | Oui | Oui | Oui | Oui |
| Traffic Management | Avance | Basique | Moyen | Basique |
| Multi-cluster | Oui | Oui | Oui | Limite |
| Non-Kubernetes | Limite | Non | Oui | Oui |

---

## Quand utiliser

- Microservices avec communication complexe
- Besoin de mTLS zero-trust
- Observabilite distribuee (tracing)
- Canary deployments, A/B testing
- Equipe DevOps mature

---

## Quand NE PAS utiliser

- Quelques services seulement
- Equipe petite sans expertise K8s
- Latence critique (overhead du proxy)
- Environnement non-Kubernetes (limite)

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Sidecar](sidecar.md) | Implementation du data plane |
| [Circuit Breaker](../resilience/circuit-breaker.md) | Gere par le mesh |
| [Rate Limiting](../resilience/rate-limiting.md) | Gere par le mesh |
| [API Gateway](api-gateway.md) | Ingress du mesh |

---

## Sources

- [Istio Documentation](https://istio.io/latest/docs/)
- [Linkerd Documentation](https://linkerd.io/docs/)
- [Dapr Documentation](https://docs.dapr.io/)
- [CNCF Service Mesh](https://www.cncf.io/projects/)
