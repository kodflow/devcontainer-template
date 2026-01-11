# Sidecar Pattern

> Deployer des composants auxiliaires dans un conteneur separe pour fournir des fonctionnalites transverses.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                       SIDECAR PATTERN                            │
│                                                                  │
│                        Pod / Host                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                                                           │  │
│  │  ┌─────────────────┐         ┌─────────────────┐         │  │
│  │  │                 │         │                 │         │  │
│  │  │   Application   │◄───────►│    Sidecar      │         │  │
│  │  │   Container     │  IPC    │    Container    │         │  │
│  │  │                 │  Volume │                 │         │  │
│  │  │  - Business     │         │  - Logging      │         │  │
│  │  │    Logic        │         │  - Proxy        │         │  │
│  │  │                 │         │  - Monitoring   │         │  │
│  │  │                 │         │  - Security     │         │  │
│  │  └─────────────────┘         └─────────────────┘         │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Avantages:                                                      │
│  - Separation des responsabilites                                │
│  - Reutilisation cross-language                                  │
│  - Cycle de vie independant                                      │
│  - Isolation des defaillances                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Cas d'usage courants

| Sidecar | Fonction |
|---------|----------|
| **Proxy** | Envoy, nginx - routing, TLS, retry |
| **Logging** | Fluentd, Filebeat - collecte de logs |
| **Monitoring** | Prometheus exporter, Datadog agent |
| **Security** | Vault agent, OAuth proxy |
| **Config** | Consul agent, config reloader |
| **Service Mesh** | Istio-proxy, Linkerd-proxy |

---

## Implementation Kubernetes

### Logging Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-logging
spec:
  containers:
    # Application principale
    - name: app
      image: my-app:latest
      ports:
        - containerPort: 8080
      volumeMounts:
        - name: logs
          mountPath: /var/log/app

    # Sidecar de logging
    - name: log-collector
      image: fluent/fluentd:latest
      volumeMounts:
        - name: logs
          mountPath: /var/log/app
          readOnly: true
        - name: fluentd-config
          mountPath: /fluentd/etc
      resources:
        limits:
          memory: 128Mi
          cpu: 100m

  volumes:
    - name: logs
      emptyDir: {}
    - name: fluentd-config
      configMap:
        name: fluentd-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/app/*.log
      pos_file /var/log/app/app.log.pos
      tag app.logs
      <parse>
        @type json
      </parse>
    </source>
    <match app.**>
      @type elasticsearch
      host elasticsearch
      port 9200
      index_name app-logs
    </match>
```

---

### Proxy Sidecar (Envoy)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-proxy
spec:
  containers:
    # Application (ne connait pas le reseau externe)
    - name: app
      image: my-app:latest
      ports:
        - containerPort: 8080
      env:
        - name: UPSTREAM_URL
          value: "http://localhost:9001"  # Parle au sidecar

    # Envoy Sidecar
    - name: envoy
      image: envoyproxy/envoy:v1.28.0
      ports:
        - containerPort: 9001  # Inbound
        - containerPort: 9901  # Admin
      volumeMounts:
        - name: envoy-config
          mountPath: /etc/envoy
      args:
        - -c
        - /etc/envoy/envoy.yaml

  volumes:
    - name: envoy-config
      configMap:
        name: envoy-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: envoy-config
data:
  envoy.yaml: |
    static_resources:
      listeners:
        - name: inbound
          address:
            socket_address:
              address: 0.0.0.0
              port_value: 9001
          filter_chains:
            - filters:
                - name: envoy.filters.network.http_connection_manager
                  typed_config:
                    "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
                    stat_prefix: ingress_http
                    route_config:
                      virtual_hosts:
                        - name: backend
                          domains: ["*"]
                          routes:
                            - match:
                                prefix: "/"
                              route:
                                cluster: upstream
                                timeout: 30s
                                retry_policy:
                                  retry_on: 5xx
                                  num_retries: 3
                    http_filters:
                      - name: envoy.filters.http.router

      clusters:
        - name: upstream
          type: STRICT_DNS
          lb_policy: ROUND_ROBIN
          load_assignment:
            cluster_name: upstream
            endpoints:
              - lb_endpoints:
                  - endpoint:
                      address:
                        socket_address:
                          address: backend-service
                          port_value: 8080
```

---

### Vault Agent Sidecar (Secrets)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-vault
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "my-app"
    vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/my-role"
    vault.hashicorp.com/agent-inject-template-db-creds: |
      {{- with secret "database/creds/my-role" -}}
      export DB_USER="{{ .Data.username }}"
      export DB_PASSWORD="{{ .Data.password }}"
      {{- end -}}
spec:
  serviceAccountName: my-app
  containers:
    - name: app
      image: my-app:latest
      command: ["/bin/sh", "-c"]
      args:
        - source /vault/secrets/db-creds && ./app
```

---

## Implementation TypeScript

### Sidecar local pour dev

```typescript
// sidecar-proxy.ts
import http from 'http';
import httpProxy from 'http-proxy';

interface SidecarConfig {
  listenPort: number;
  upstreamHost: string;
  upstreamPort: number;
  features: {
    logging: boolean;
    metrics: boolean;
    retry: boolean;
    rateLimit: boolean;
  };
}

class LocalSidecar {
  private readonly proxy: httpProxy;
  private readonly metrics = {
    requests: 0,
    errors: 0,
    latencies: [] as number[],
  };

  constructor(private readonly config: SidecarConfig) {
    this.proxy = httpProxy.createProxyServer({
      target: `http://${config.upstreamHost}:${config.upstreamPort}`,
    });
  }

  start(): void {
    const server = http.createServer(async (req, res) => {
      const start = Date.now();
      this.metrics.requests++;

      // Rate limiting
      if (this.config.features.rateLimit && !this.checkRateLimit(req)) {
        res.writeHead(429);
        res.end('Too Many Requests');
        return;
      }

      // Logging
      if (this.config.features.logging) {
        console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
      }

      // Retry logic
      const maxRetries = this.config.features.retry ? 3 : 1;
      let lastError: Error | null = null;

      for (let attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          await this.proxyRequest(req, res);
          this.metrics.latencies.push(Date.now() - start);
          return;
        } catch (error) {
          lastError = error as Error;
          if (attempt < maxRetries) {
            await this.sleep(100 * attempt);
          }
        }
      }

      this.metrics.errors++;
      res.writeHead(502);
      res.end('Bad Gateway');
    });

    // Metrics endpoint
    server.on('request', (req, res) => {
      if (req.url === '/sidecar/metrics') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(this.getMetrics()));
      }
    });

    server.listen(this.config.listenPort, () => {
      console.log(`Sidecar listening on port ${this.config.listenPort}`);
    });
  }

  private proxyRequest(req: http.IncomingMessage, res: http.ServerResponse): Promise<void> {
    return new Promise((resolve, reject) => {
      this.proxy.web(req, res, {}, (error) => {
        if (error) reject(error);
        else resolve();
      });
    });
  }

  private rateLimitBucket = new Map<string, number[]>();

  private checkRateLimit(req: http.IncomingMessage): boolean {
    const key = req.socket.remoteAddress ?? 'unknown';
    const now = Date.now();
    const windowMs = 60000;
    const maxRequests = 100;

    let timestamps = this.rateLimitBucket.get(key) ?? [];
    timestamps = timestamps.filter((t) => t > now - windowMs);

    if (timestamps.length >= maxRequests) {
      return false;
    }

    timestamps.push(now);
    this.rateLimitBucket.set(key, timestamps);
    return true;
  }

  private getMetrics(): object {
    const latencies = this.metrics.latencies;
    return {
      requests_total: this.metrics.requests,
      errors_total: this.metrics.errors,
      latency_avg_ms: latencies.length
        ? latencies.reduce((a, b) => a + b, 0) / latencies.length
        : 0,
      latency_p99_ms: latencies.length
        ? latencies.sort((a, b) => a - b)[Math.floor(latencies.length * 0.99)]
        : 0,
    };
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }
}

// Usage
const sidecar = new LocalSidecar({
  listenPort: 9001,
  upstreamHost: 'localhost',
  upstreamPort: 8080,
  features: {
    logging: true,
    metrics: true,
    retry: true,
    rateLimit: true,
  },
});

sidecar.start();
```

---

### Init Container pour config

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: app-with-init
spec:
  initContainers:
    # Init container: fetch config before app starts
    - name: config-fetcher
      image: curlimages/curl:latest
      command:
        - /bin/sh
        - -c
        - |
          curl -s http://config-service/config/my-app > /config/app.json
          echo "Config fetched successfully"
      volumeMounts:
        - name: config
          mountPath: /config

  containers:
    - name: app
      image: my-app:latest
      volumeMounts:
        - name: config
          mountPath: /app/config
          readOnly: true

    # Sidecar: refresh config periodically
    - name: config-refresher
      image: curlimages/curl:latest
      command:
        - /bin/sh
        - -c
        - |
          while true; do
            sleep 60
            curl -s http://config-service/config/my-app > /config/app.json
            # Signal app to reload (optional)
            curl -X POST http://localhost:8080/reload
          done
      volumeMounts:
        - name: config
          mountPath: /config

  volumes:
    - name: config
      emptyDir: {}
```

---

## Comparaison avec alternatives

| Approche | Avantages | Inconvenients |
|----------|-----------|---------------|
| **Sidecar** | Isolation, polyglotte | Overhead ressources |
| **Library** | Performance, simplicite | Couplage, single-language |
| **DaemonSet** | Moins de ressources | Moins isole |
| **Service Mesh** | Full-featured | Complexite |

---

## Quand utiliser

- Fonctionnalites cross-cutting (logging, security)
- Equipe polyglotte (Java, Node, Go, Python)
- Besoin d'isolation (failure domains)
- Configuration dynamique
- Proxy et networking

---

## Quand NE PAS utiliser

- Application monolithique simple
- Contraintes ressources strictes
- Latence critique (<1ms)
- Complexite non justifiee

---

## Lie a

| Pattern | Relation |
|---------|----------|
| [Service Mesh](service-mesh.md) | Utilise des sidecars |
| Ambassador | Variante du sidecar |
| Adapter | Sidecar de translation |
| Init Container | Initialisation avant app |

---

## Sources

- [Microsoft - Sidecar Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/sidecar)
- [Kubernetes - Multi-container Pods](https://kubernetes.io/docs/concepts/workloads/pods/#how-pods-manage-multiple-containers)
- [Envoy Proxy](https://www.envoyproxy.io/docs/envoy/latest/)
