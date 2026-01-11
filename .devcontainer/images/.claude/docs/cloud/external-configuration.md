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

## Exemple Go

```go
package externalconfig

import (
	"context"
	"fmt"
	"sync"
)

// ConfigSource defines a configuration source.
type ConfigSource interface {
	Name() string
	Priority() int
	Load(ctx context.Context) (map[string]interface{}, error)
	Watch(ctx context.Context, callback func(key string, value interface{})) error
}

// WatchCallback is called when configuration changes.
type WatchCallback func(key string, value interface{})

// ConfigurationManager manages configuration from multiple sources.
type ConfigurationManager struct {
	mu       sync.RWMutex
	config   map[string]interface{}
	sources  []ConfigSource
	watchers []WatchCallback
}

// NewConfigurationManager creates a new ConfigurationManager.
func NewConfigurationManager() *ConfigurationManager {
	return &ConfigurationManager{
		config:   make(map[string]interface{}),
		sources:  make([]ConfigSource, 0),
		watchers: make([]WatchCallback, 0),
	}
}

// AddSource adds a configuration source.
func (cm *ConfigurationManager) AddSource(source ConfigSource) *ConfigurationManager {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	
	cm.sources = append(cm.sources, source)
	
	// Sort by priority (highest first)
	for i := 0; i < len(cm.sources); i++ {
		for j := i + 1; j < len(cm.sources); j++ {
			if cm.sources[i].Priority() < cm.sources[j].Priority() {
				cm.sources[i], cm.sources[j] = cm.sources[j], cm.sources[i]
			}
		}
	}
	
	return cm
}

// Load loads configuration from all sources.
func (cm *ConfigurationManager) Load(ctx context.Context) error {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	
	for _, source := range cm.sources {
		values, err := source.Load(ctx)
		if err != nil {
			fmt.Printf("Failed to load config from %s: %v
", source.Name(), err)
			continue
		}
		
		// Only set if not already set (higher priority sources win)
		for key, value := range values {
			if _, exists := cm.config[key]; !exists {
				cm.config[key] = value
			}
		}
		
		// Setup watching if supported
		go func(s ConfigSource) {
			s.Watch(ctx, func(key string, value interface{}) {
				cm.mu.Lock()
				cm.config[key] = value
				cm.mu.Unlock()
				cm.notifyWatchers(key, value)
			})
		}(source)
	}
	
	return nil
}

// Get returns a configuration value with optional default.
func (cm *ConfigurationManager) Get(key string, defaultValue interface{}) interface{} {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	
	if value, exists := cm.config[key]; exists {
		return value
	}
	return defaultValue
}

// GetRequired returns a required configuration value or panics.
func (cm *ConfigurationManager) GetRequired(key string) interface{} {
	cm.mu.RLock()
	defer cm.mu.RUnlock()
	
	value, exists := cm.config[key]
	if !exists {
		panic(fmt.Sprintf("Required config key missing: %s", key))
	}
	return value
}

// Watch registers a callback for configuration changes.
func (cm *ConfigurationManager) Watch(callback WatchCallback) {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	cm.watchers = append(cm.watchers, callback)
}

func (cm *ConfigurationManager) notifyWatchers(key string, value interface{}) {
	cm.mu.RLock()
	watchers := make([]WatchCallback, len(cm.watchers))
	copy(watchers, cm.watchers)
	cm.mu.RUnlock()
	
	for _, watcher := range watchers {
		watcher(key, value)
	}
}
```

## Usage

```go
// Cet exemple suit les mêmes patterns Go idiomatiques
// que l'exemple principal ci-dessus.
// Implémentation spécifique basée sur les interfaces et
// les conventions Go standard.
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
