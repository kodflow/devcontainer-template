# Feature Toggles / Feature Flags

Techniques pour activer/désactiver des fonctionnalités sans déploiement.

---

## Qu'est-ce qu'un Feature Toggle ?

> Un mécanisme pour modifier le comportement d'un système sans changer son code.

```go
// Principe de base
if featureFlags.IsEnabled("new-checkout") {
	return newCheckoutFlow(cart)
}
return legacyCheckoutFlow(cart)
```

**Pourquoi:**

- Déployer du code inactif (deploy ≠ release)
- Tester en production avec subset d'utilisateurs
- Rollback instantané sans redéploiement
- A/B testing

---

## Types de Feature Toggles

### 1. Release Toggles (Court terme)

> Cacher des features incomplètes en production.

```go
package payment

import (
	"context"
	"fmt"
)

// Order represents a customer order.
type Order struct {
	ID     string
	Amount float64
	Items  []string
}

// Gateway defines payment processing interface.
type Gateway interface {
	Process(ctx context.Context, order *Order) error
}

// FeatureFlags defines feature flag interface.
type FeatureFlags interface {
	IsEnabled(flag string) bool
}

// Service handles payment processing.
type Service struct {
	features      FeatureFlags
	newGateway    Gateway
	legacyGateway Gateway
}

// NewService creates a new payment service.
func NewService(features FeatureFlags, newGateway, legacyGateway Gateway) *Service {
	return &Service{
		features:      features,
		newGateway:    newGateway,
		legacyGateway: legacyGateway,
	}
}

// Process processes a payment order.
func (s *Service) Process(ctx context.Context, order *Order) error {
	if s.features.IsEnabled("new-payment-gateway") {
		return s.newGateway.Process(ctx, order)
	}
	return s.legacyGateway.Process(ctx, order)
}
```

**Durée:** Jours à semaines
**À supprimer:** Dès que feature stable

---

### 2. Experiment Toggles (A/B Testing)

> Tester différentes variantes sur des segments d'utilisateurs.

```go
package experiment

import (
	"hash/fnv"
)

// Variant represents an experiment variant.
type Variant struct {
	Name   string
	Weight int
}

// Config holds experiment configuration.
type Config struct {
	Name       string
	Variants   []Variant
	Allocation int // % of users
}

// Service manages experiments.
type Service struct {
	experiments map[string]Config
}

// NewService creates a new experiment service.
func NewService() *Service {
	return &Service{
		experiments: make(map[string]Config),
	}
}

// GetVariant returns the variant for a user.
func (s *Service) GetVariant(userID, experiment string) string {
	config, exists:= s.experiments[experiment]
	if !exists {
		return "control"
	}

	// Deterministic hash for consistency
	hash:= s.hash(userID + ":" + experiment)
	bucket:= int(hash % 100)

	if bucket >= config.Allocation {
		return "control"
	}

	// Distribution among variants
	return s.selectVariant(hash, config.Variants)
}

// hash generates a deterministic hash.
func (s *Service) hash(key string) uint32 {
	h:= fnv.New32a()
	_, _ = h.Write([]byte(key))
	return h.Sum32()
}

// selectVariant selects a variant based on hash.
func (s *Service) selectVariant(hash uint32, variants []Variant) string {
	if len(variants) == 0 {
		return "control"
	}

	bucket:= int(hash % 100)
	cumulative:= 0

	for _, variant:= range variants {
		cumulative += variant.Weight
		if bucket < cumulative {
			return variant.Name
		}
	}

	return variants[0].Name
}

// Example usage
func ExampleCheckoutVariant(userID string, experiments *Service) string {
	variant:= experiments.GetVariant(userID, "checkout-redesign")
	
	switch variant {
	case "control":
		return "OriginalCheckout"
	case "variant-a":
		return "SimplifiedCheckout"
	case "variant-b":
		return "OneClickCheckout"
	default:
		return "OriginalCheckout"
	}
}
```

**Durée:** Semaines à mois
**Metrics:** Conversion, engagement, revenue

---

### 3. Ops Toggles (Kill Switches)

> Désactiver des features en cas de problème.

```go
package ops

import (
	"context"
	"sync"
)

// Config holds operational toggles.
type Config struct {
	mu      sync.RWMutex
	toggles map[string]bool
}

// NewConfig creates a new ops config.
func NewConfig() *Config {
	return &Config{
		toggles: map[string]bool{
			"recommendations-service": true,
			"third-party-analytics":   true,
			"email-notifications":     true,
			"heavy-reports":           true,
		},
	}
}

// IsEnabled checks if a feature is enabled.
func (c *Config) IsEnabled(feature string) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.toggles[feature]
}

// Disable disables a feature.
func (c *Config) Disable(feature string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.toggles[feature] = false
}

// Enable enables a feature.
func (c *Config) Enable(feature string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.toggles[feature] = true
}

// Recommendation represents a product recommendation.
type Recommendation struct {
	ProductID string
	Score     float64
}

// MLService defines machine learning service interface.
type MLService interface {
	Predict(ctx context.Context, userID string) ([]Recommendation, error)
}

// RecommendationService provides product recommendations.
type RecommendationService struct {
	ops       *Config
	mlService MLService
	errorRate float64
	mu        sync.RWMutex
}

// NewRecommendationService creates a new recommendation service.
func NewRecommendationService(ops *Config, mlService MLService) *RecommendationService {
	return &RecommendationService{
		ops:       ops,
		mlService: mlService,
	}
}

// GetRecommendations fetches recommendations with kill switch.
func (s *RecommendationService) GetRecommendations(ctx context.Context, userID string) ([]Recommendation, error) {
	// Kill switch - can be disabled instantly
	if !s.ops.IsEnabled("recommendations-service") {
		return s.getFallbackRecommendations(userID), nil
	}

	recommendations, err:= s.mlService.Predict(ctx, userID)
	if err != nil {
		// Auto-disable if too many errors
		s.mu.Lock()
		s.errorRate += 0.1
		if s.errorRate > 0.5 {
			s.ops.Disable("recommendations-service")
		}
		s.mu.Unlock()
		
		return s.getFallbackRecommendations(userID), nil
	}

	return recommendations, nil
}

// getFallbackRecommendations returns safe fallback recommendations.
func (s *RecommendationService) getFallbackRecommendations(userID string) []Recommendation {
	return []Recommendation{
		{ProductID: "popular-1", Score: 0.9},
		{ProductID: "popular-2", Score: 0.8},
	}
}
```

**Durée:** Permanent
**Activation:** Via dashboard ou API

---

### 4. Permission Toggles

> Features disponibles selon le plan/rôle utilisateur.

```go
package feature

import (
	"context"
)

// Plan represents a user subscription plan.
type Plan string

const (
	PlanFree       Plan = "free"
	PlanPro        Plan = "pro"
	PlanEnterprise Plan = "enterprise"
)

// UserPlan holds user plan information.
type UserPlan struct {
	Name     Plan
	Features []string
}

// GlobalToggles defines global feature toggle interface.
type GlobalToggles interface {
	IsEnabled(feature string) bool
}

// Gate controls access to features.
type Gate struct {
	userPlan      UserPlan
	globalToggles GlobalToggles
}

// NewGate creates a new feature gate.
func NewGate(userPlan UserPlan, globalToggles GlobalToggles) *Gate {
	return &Gate{
		userPlan:      userPlan,
		globalToggles: globalToggles,
	}
}

// CanAccess checks if user can access a feature.
func (g *Gate) CanAccess(ctx context.Context, feature string) bool {
	// Check user plan features
	for _, f:= range g.userPlan.Features {
		if f == feature {
			return true
		}
	}

	// Check global toggles (beta, etc.)
	if g.globalToggles.IsEnabled(feature) {
		return true
	}

	return false
}

// Example usage
func ExampleDashboardAccess(gate *Gate) string {
	if gate.CanAccess(context.Background(), "advanced-analytics") {
		return "AdvancedDashboard"
	}
	return "BasicDashboardWithUpgrade"
}
```

---

## Implémentation

### Architecture

```go
package flags

import (
	"context"
	"hash/fnv"
	"sync"
	"time"
)

// FeatureFlags defines the main interface for feature flags.
type FeatureFlags interface {
	IsEnabled(flag string) bool
	IsEnabledWithContext(flag string, ctx Context) bool
	GetVariant(flag string, ctx Context) string
}

// Context holds user and environment context.
type Context struct {
	UserID     string
	UserPlan   string
	Country    string
	DeviceType string
	Percentage int
}

// Rule defines a targeting rule.
type Rule struct {
	Country    string
	UserPlan   string
	DeviceType string
	Enabled    bool
}

// FlagValue holds the complete flag configuration.
type FlagValue struct {
	Enabled    bool
	Percentage int
	Rules      []Rule
}

// ConfigFeatureFlags implements simple config-based flags.
type ConfigFeatureFlags struct {
	config map[string]bool
}

// NewConfigFeatureFlags creates a config-based feature flags service.
func NewConfigFeatureFlags(config map[string]bool) *ConfigFeatureFlags {
	return &ConfigFeatureFlags{
		config: config,
	}
}

// IsEnabled checks if a flag is enabled.
func (f *ConfigFeatureFlags) IsEnabled(flag string) bool {
	enabled, ok:= f.config[flag]
	return ok && enabled
}

// RemoteFeatureFlags implements remote config with caching.
type RemoteFeatureFlags struct {
	mu              sync.RWMutex
	cache           map[string]FlagValue
	api             FlagService
	refreshInterval time.Duration
}

// FlagService defines the interface for fetching remote flags.
type FlagService interface {
	FetchFlags(ctx context.Context) (map[string]FlagValue, error)
}

// NewRemoteFeatureFlags creates a remote feature flags service.
func NewRemoteFeatureFlags(api FlagService) *RemoteFeatureFlags {
	f:= &RemoteFeatureFlags{
		cache:           make(map[string]FlagValue),
		api:             api,
		refreshInterval: 30 * time.Second,
	}
	f.startPolling()
	return f
}

// IsEnabledWithContext checks if a flag is enabled with context.
func (f *RemoteFeatureFlags) IsEnabledWithContext(flag string, ctx Context) bool {
	f.mu.RLock()
	value, ok:= f.cache[flag]
	f.mu.RUnlock()

	if !ok {
		return false
	}

	return f.evaluate(value, ctx)
}

// evaluate applies targeting rules.
func (f *RemoteFeatureFlags) evaluate(value FlagValue, ctx Context) bool {
	// Apply targeting rules
	if value.Rules != nil {
		for _, rule:= range value.Rules {
			if f.matchesRule(rule, ctx) {
				return rule.Enabled
			}
		}
	}

	// Percentage rollout
	if value.Percentage > 0 && ctx.UserID != "" {
		hash:= f.hash(ctx.UserID)
		if int(hash%100) < value.Percentage {
			return true
		}
	}

	return value.Enabled
}

// matchesRule checks if context matches a rule.
func (f *RemoteFeatureFlags) matchesRule(rule Rule, ctx Context) bool {
	if rule.Country != "" && rule.Country != ctx.Country {
		return false
	}
	if rule.UserPlan != "" && rule.UserPlan != ctx.UserPlan {
		return false
	}
	if rule.DeviceType != "" && rule.DeviceType != ctx.DeviceType {
		return false
	}
	return true
}

// hash generates a deterministic hash.
func (f *RemoteFeatureFlags) hash(key string) uint32 {
	h:= fnv.New32a()
	_, _ = h.Write([]byte(key))
	return h.Sum32()
}

// startPolling starts background polling for flag updates.
func (f *RemoteFeatureFlags) startPolling() {
	go func() {
		ticker:= time.NewTicker(f.refreshInterval)
		defer ticker.Stop()

		for range ticker.C {
			ctx:= context.Background()
			flags, err:= f.api.FetchFlags(ctx)
			if err != nil {
				continue
			}

			f.mu.Lock()
			f.cache = flags
			f.mu.Unlock()
		}
	}()
}
```

### Configuration déclarative

```yaml
# feature-flags.yaml
flags:
  new-checkout:
    enabled: true
    percentage: 50  # 50% des utilisateurs
    rules:
      - if:
          plan: enterprise
        then: true   # 100% pour enterprise
      - if:
          country: FR
        then: false  # Pas encore en France

  dark-mode:
    enabled: true
    # Pas de règles = tout le monde

  beta-features:
    enabled: false
    rules:
      - if:
          email_ends_with: "@company.com"
        then: true  # Employés seulement
```

---

## Stratégies de Rollout

### 1. Canary Release

```go
package rollout

import (
	"context"
	"time"
)

// Stage represents a rollout stage.
type Stage struct {
	Percentage int
	Duration   time.Duration
}

// CanaryConfig holds canary deployment configuration.
type CanaryConfig struct {
	Flag   string
	Stages []Stage
}

// Metrics holds deployment metrics.
type Metrics struct {
	ErrorRate  float64
	LatencyP99 float64
}

// Deployment manages canary deployments.
type Deployment struct {
	config  CanaryConfig
	current int
}

// NewDeployment creates a new canary deployment.
func NewDeployment(config CanaryConfig) *Deployment {
	return &Deployment{
		config:  config,
		current: 0,
	}
}

// ProgressStage advances to the next rollout stage.
func (d *Deployment) ProgressStage(ctx context.Context) error {
	metrics, err:= d.getMetrics(ctx)
	if err != nil {
		return err
	}

	// Automatic rollback if error rate too high
	if metrics.ErrorRate > 0.01 {
		return d.rollback(ctx)
	}

	// Pause if latency degraded
	if metrics.LatencyP99 > 500 {
		return d.pause(ctx)
	}

	// Progress to next stage
	return d.nextStage(ctx)
}

// getMetrics fetches current metrics.
func (d *Deployment) getMetrics(ctx context.Context) (*Metrics, error) {
	// Placeholder - integrate with monitoring system
	return &Metrics{
		ErrorRate:  0.005,
		LatencyP99: 450,
	}, nil
}

// rollback rolls back the deployment.
func (d *Deployment) rollback(ctx context.Context) error {
	d.current = 0
	return nil
}

// pause pauses the deployment.
func (d *Deployment) pause(ctx context.Context) error {
	return nil
}

// nextStage progresses to next stage.
func (d *Deployment) nextStage(ctx context.Context) error {
	if d.current < len(d.config.Stages)-1 {
		d.current++
	}
	return nil
}
```

### 2. Ring Deployment

```go
package ring

// Ring represents a deployment ring.
type Ring int

const (
	RingInternal Ring = iota
	RingBeta
	RingRegional
	RingAll
)

// User represents a user.
type User struct {
	Email      string
	IsBetaTester bool
	Region     string
}

// GetUserRing determines the user's ring.
func GetUserRing(user User) Ring {
	if len(user.Email) > 12 && user.Email[len(user.Email)-12:] == "@company.com" {
		return RingInternal
	}
	if user.IsBetaTester {
		return RingBeta
	}
	if user.Region == "europe" {
		return RingRegional
	}
	return RingAll
}

// FlagConfig holds ring-based flag configuration.
type FlagConfig struct {
	Name        string
	EnabledRing Ring
}

// IsEnabled checks if flag is enabled for user.
func IsEnabled(flag string, user User, configs map[string]FlagConfig) bool {
	config, exists:= configs[flag]
	if !exists {
		return false
	}

	userRing:= GetUserRing(user)
	return userRing <= config.EnabledRing
}
```

---

## Toggle Cleanup

### Le problème du toggle debt

```go
// Bad example - nested toggles create complexity
// Do not implement this pattern
```

### Solution: Toggle avec expiration

```go
package managed

import (
	"context"
	"fmt"
	"time"
)

// FlagConfig holds complete flag metadata.
type FlagConfig struct {
	Name      string
	Enabled   bool
	Owner     string
	CreatedAt time.Time
	ExpiresAt time.Time
	Ticket    string
}

// ManagedFeatureFlags manages flags with expiration.
type ManagedFeatureFlags struct {
	flags map[string]FlagConfig
}

// NewManagedFeatureFlags creates a managed feature flags service.
func NewManagedFeatureFlags() *ManagedFeatureFlags {
	return &ManagedFeatureFlags{
		flags: make(map[string]FlagConfig),
	}
}

// IsEnabled checks if flag is enabled and alerts if expired.
func (m *ManagedFeatureFlags) IsEnabled(ctx context.Context, flag string) bool {
	config, exists:= m.flags[flag]
	if !exists {
		return false
	}

	// Alert if expired
	if config.ExpiresAt.Before(time.Now()) {
		m.alert(ctx, fmt.Sprintf("Toggle %s expired! Owner: %s", flag, config.Owner))
	}

	return config.Enabled
}

// CleanupExpired identifies expired flags.
func (m *ManagedFeatureFlags) CleanupExpired(ctx context.Context) []FlagConfig {
	expired:= make([]FlagConfig, 0)

	for _, flag:= range m.flags {
		if flag.ExpiresAt.Before(time.Now()) {
			expired = append(expired, flag)
			fmt.Printf("Expired: %s\n", flag.Name)
			fmt.Printf("  Owner: %s\n", flag.Owner)
			fmt.Printf("  Ticket: %s\n", flag.Ticket)
			fmt.Printf("  Created: %s\n", flag.CreatedAt)
		}
	}

	return expired
}

// alert sends an alert for expired flags.
func (m *ManagedFeatureFlags) alert(ctx context.Context, message string) {
	// Integrate with alerting system
	fmt.Printf("ALERT: %s\n", message)
}
```

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Strategy** | Toggle sélectionne la stratégie |
| **Circuit Breaker** | Ops toggle automatique |
| **Branch by Abstraction** | Migration progressive |
| **Canary Release** | Progressive rollout |

---

## Outils populaires

| Outil | Type | Features |
|-------|------|----------|
| LaunchDarkly | SaaS | Full-featured, SDKs |
| Split.io | SaaS | A/B testing focus |
| Unleash | Open-source | Self-hosted |
| ConfigCat | SaaS | Simple, abordable |
| Flagsmith | Open-source | Self-hosted/Cloud |

---

## Anti-patterns

| Anti-pattern | Problème | Solution |
|--------------|----------|----------|
| Toggle permanent | Code mort | Expiration dates |
| Nested toggles | Complexité | Refactor, un toggle par feature |
| Toggle dans toggle | Illisible | Combiner en un seul |
| Pas de default | Crash si absent | Toujours un fallback |
| Pas de monitoring | Aveugle | Dashboard de toggles |

---

## Sources

- [Martin Fowler - Feature Toggles](https://martinfowler.com/articles/feature-toggles.html)
- [Pete Hodgson - Feature Toggles (Feature Flags)](https://www.martinfowler.com/articles/feature-toggles.html)
- [LaunchDarkly Blog](https://launchdarkly.com/blog/)
