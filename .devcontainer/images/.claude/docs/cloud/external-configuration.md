# External Configuration Pattern

> Externaliser la configuration hors du code deploye.

## Principe

```
┌────────────────────────────────────────────────────────────────┐
│                  EXTERNAL CONFIGURATION                         │
│                                                                 │
│    ┌─────────────────────────────────────────────────────┐     │
│    │              Configuration Store                     │     │
│    │                                                      │     │
│    │   ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │     │
│    │   │  Vault   │  │  Consul  │  │ Environment Vars │  │     │
│    │   │ (secrets)│  │ (config) │  │    (runtime)     │  │     │
│    │   └──────────┘  └──────────┘  └──────────────────┘  │     │
│    └─────────────────────────────────────────────────────┘     │
│                              │                                  │
│                              ▼                                  │
│    ┌─────────────────────────────────────────────────────┐     │
│    │               Config Client Library                  │     │
│    └─────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
       ┌─────────┐       ┌─────────┐       ┌─────────┐
       │ Service │       │ Service │       │ Service │
       │    A    │       │    B    │       │    C    │
       └─────────┘       └─────────┘       └─────────┘
```

## Sources de configuration

| Source | Usage | Dynamique | Securise |
|--------|-------|-----------|----------|
| **Environment Vars** | Runtime, secrets | Non | Moyen |
| **Config Files** | Settings statiques | Non | Non |
| **Consul/etcd** | Config distribuee | Oui | Moyen |
| **Vault** | Secrets | Oui | Oui |
| **AWS SSM** | Cloud params | Oui | Oui |
| **Kubernetes ConfigMaps** | K8s config | Oui | Non |
| **Kubernetes Secrets** | K8s secrets | Oui | Oui |

## Exemple TypeScript

```typescript
interface ConfigSource {
  name: string;
  priority: number;
  load(): Promise<Record<string, any>>;
  watch?(callback: (key: string, value: any) => void): void;
}

class ConfigurationManager {
  private config: Map<string, any> = new Map();
  private sources: ConfigSource[] = [];
  private watchers: ((key: string, value: any) => void)[] = [];

  addSource(source: ConfigSource): this {
    this.sources.push(source);
    this.sources.sort((a, b) => b.priority - a.priority);
    return this;
  }

  async load(): Promise<void> {
    for (const source of this.sources) {
      try {
        const values = await source.load();
        for (const [key, value] of Object.entries(values)) {
          if (!this.config.has(key)) {
            this.config.set(key, value);
          }
        }

        // Setup watching si supporte
        source.watch?.((key, value) => {
          this.config.set(key, value);
          this.notifyWatchers(key, value);
        });
      } catch (error) {
        console.error(`Failed to load config from ${source.name}:`, error);
      }
    }
  }

  get<T>(key: string, defaultValue?: T): T {
    return this.config.get(key) ?? defaultValue;
  }

  getRequired<T>(key: string): T {
    if (!this.config.has(key)) {
      throw new Error(`Required config key missing: ${key}`);
    }
    return this.config.get(key);
  }

  watch(callback: (key: string, value: any) => void): void {
    this.watchers.push(callback);
  }

  private notifyWatchers(key: string, value: any): void {
    this.watchers.forEach(w => w(key, value));
  }
}

// Sources implementations
const envSource: ConfigSource = {
  name: 'environment',
  priority: 100,
  async load() {
    return Object.fromEntries(
      Object.entries(process.env)
        .filter(([k]) => k.startsWith('APP_'))
        .map(([k, v]) => [k.replace('APP_', '').toLowerCase(), v])
    );
  },
};

const consulSource: ConfigSource = {
  name: 'consul',
  priority: 50,
  async load() {
    const response = await fetch(`${CONSUL_URL}/v1/kv/app?recurse=true`);
    const data = await response.json();
    return data.reduce((acc: Record<string, any>, item: any) => {
      acc[item.Key.replace('app/', '')] = atob(item.Value);
      return acc;
    }, {});
  },
  watch(callback) {
    // Long polling Consul
    const poll = async (index: number) => {
      const response = await fetch(
        `${CONSUL_URL}/v1/kv/app?recurse=true&index=${index}`
      );
      const newIndex = parseInt(response.headers.get('X-Consul-Index') ?? '0');
      const data = await response.json();

      data.forEach((item: any) => {
        callback(item.Key.replace('app/', ''), atob(item.Value));
      });

      poll(newIndex);
    };
    poll(0);
  },
};

const vaultSource: ConfigSource = {
  name: 'vault',
  priority: 200, // Highest priority for secrets
  async load() {
    const response = await fetch(`${VAULT_URL}/v1/secret/data/app`, {
      headers: { 'X-Vault-Token': VAULT_TOKEN },
    });
    const data = await response.json();
    return data.data.data;
  },
};
```

## Usage

```typescript
// Initialisation
const config = new ConfigurationManager()
  .addSource(vaultSource)    // Priority 200 - secrets
  .addSource(envSource)      // Priority 100 - overrides
  .addSource(consulSource);  // Priority 50  - base config

await config.load();

// Usage
const dbHost = config.get('database_host', 'localhost');
const dbPassword = config.getRequired<string>('database_password');
const maxConnections = config.get<number>('max_connections', 10);

// Reactive config
config.watch((key, value) => {
  if (key === 'log_level') {
    logger.setLevel(value);
  }
});
```

## Configuration Kubernetes

```yaml
# ConfigMap pour config non-sensible
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"
  FEATURE_FLAG_NEW_UI: "true"

---
# Secret pour donnees sensibles
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DATABASE_PASSWORD: cGFzc3dvcmQxMjM=
  API_KEY: c2VjcmV0LWtleQ==
```

## Bonnes pratiques

| Pratique | Description |
|----------|-------------|
| **Hierarchie** | Priorite: secrets > env > files |
| **Validation** | Schema validation au demarrage |
| **Defaults** | Valeurs par defaut raisonnables |
| **Hot Reload** | Rechargement sans redemarrage |
| **Audit** | Log des acces aux secrets |
| **Rotation** | Rotation automatique des credentials |

## Anti-patterns

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Secrets dans le code | Exposition | Vault/SSM |
| Config hardcodee | Redeploy pour changer | External config |
| Sans validation | Erreurs runtime | Schema validation |
| Config trop granulaire | Complexite | Grouper par domaine |

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Secrets Management | Sous-ensemble securise |
| Feature Toggles | Cas d'usage specifique |
| Service Discovery | Config dynamique endpoints |
| 12-Factor App | Principe III |

## Sources

- [Microsoft - External Configuration Store](https://learn.microsoft.com/en-us/azure/architecture/patterns/external-configuration-store)
- [12-Factor App - Config](https://12factor.net/config)
- [HashiCorp Vault](https://www.vaultproject.io/)
