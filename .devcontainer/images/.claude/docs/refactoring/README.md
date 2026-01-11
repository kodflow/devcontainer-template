# Refactoring Patterns

Patterns pour améliorer et migrer du code existant de manière sûre.

---

## Patterns documentés

| Pattern | Fichier | Usage |
|---------|---------|-------|
| Branch by Abstraction | [branch-by-abstraction.md](branch-by-abstraction.md) | Migration progressive sur trunk |
| Strangler Fig | (cloud/strangler.md) | Remplacement système legacy |
| Parallel Run | [branch-by-abstraction.md](branch-by-abstraction.md#parallel-run) | Tester deux implémentations |
| Dark Launch | [branch-by-abstraction.md](branch-by-abstraction.md#dark-launch) | Feature invisible en prod |

---

## 1. Branch by Abstraction

> Migrer une implémentation vers une autre sans branches Git longues.

```go
package payment

import (
	"context"
	"fmt"
)

// Money represents a monetary amount.
type Money struct {
	Amount   int64
	Currency string
}

// Result represents a payment processing result.
type Result struct {
	ID          string
	Status      string
	Amount      Money
	Error       error
}

// Étape 1: Créer abstraction
type PaymentProcessor interface {
	Charge(ctx context.Context, amount Money) (*Result, error)
}

// Étape 2: Ancienne implémentation
type StripeProcessor struct {
	apiKey string
}

func NewStripeProcessor(apiKey string) *StripeProcessor {
	return &StripeProcessor{apiKey: apiKey}
}

func (s *StripeProcessor) Charge(ctx context.Context, amount Money) (*Result, error) {
	// Ancienne logique Stripe
	return &Result{
		ID:     "stripe_123",
		Status: "success",
		Amount: amount,
	}, nil
}

// Étape 3: Nouvelle implémentation
type AdyenProcessor struct {
	apiKey string
}

func NewAdyenProcessor(apiKey string) *AdyenProcessor {
	return &AdyenProcessor{apiKey: apiKey}
}

func (a *AdyenProcessor) Charge(ctx context.Context, amount Money) (*Result, error) {
	// Nouvelle logique Adyen
	return &Result{
		ID:     "adyen_456",
		Status: "success",
		Amount: amount,
	}, nil
}

// FeatureToggle represents feature flag configuration.
type FeatureToggle interface {
	IsEnabled(ctx context.Context, feature string) bool
	RolloutPercentage(ctx context.Context, feature string) int
}

// Étape 4: Factory pour router
type PaymentFactory struct {
	stripeKey string
	adyenKey  string
	features  FeatureToggle
}

func NewPaymentFactory(stripeKey, adyenKey string, features FeatureToggle) *PaymentFactory {
	return &PaymentFactory{
		stripeKey: stripeKey,
		adyenKey:  adyenKey,
		features:  features,
	}
}

func (f *PaymentFactory) Create(ctx context.Context) PaymentProcessor {
	if f.features.IsEnabled(ctx, "adyen") {
		return NewAdyenProcessor(f.adyenKey)
	}
	return NewStripeProcessor(f.stripeKey)
}

// Étape 5: Rollout progressif
// 1% → 10% → 50% → 100%
// Configuration dans FeatureToggle

// Étape 6: Supprimer l'ancienne implémentation
// Une fois le rollout à 100%, supprimer StripeProcessor
```

**Quand :** Remplacer une dépendance, refactorer un module, migrer une API.

**Lié à :** Feature Toggle, Adapter, Strategy

---

## 2. Strangler Fig

> Remplacer progressivement un système legacy par un nouveau.

```go
package order

import (
	"context"
	"fmt"
)

// OrderData represents order creation data.
type OrderData struct {
	Region string
	Total  int64
	Items  []string
}

// Order represents an order entity.
type Order struct {
	ID     string
	Data   OrderData
	Status string
}

// LegacyOrderSystem represents the old order system.
type LegacyOrderSystem interface {
	CreateOrder(ctx context.Context, data OrderData) (*Order, error)
}

// NewOrderService represents the new order system.
type NewOrderService interface {
	Create(ctx context.Context, data OrderData) (*Order, error)
}

// FeatureFlags provides feature toggle configuration.
type FeatureFlags interface {
	IsEnabled(ctx context.Context, feature string) bool
}

// Façade qui route vers legacy ou nouveau
type OrderFacade struct {
	legacySystem LegacyOrderSystem
	newService   NewOrderService
	features     FeatureFlags
}

func NewOrderFacade(
	legacy LegacyOrderSystem,
	newSvc NewOrderService,
	features FeatureFlags,
) *OrderFacade {
	return &OrderFacade{
		legacySystem: legacy,
		newService:   newSvc,
		features:     features,
	}
}

func (o *OrderFacade) CreateOrder(ctx context.Context, data OrderData) (*Order, error) {
	if o.canUseNewSystem(ctx, data) {
		order, err := o.newService.Create(ctx, data)
		if err != nil {
			return nil, fmt.Errorf("new order service: %w", err)
		}
		return order, nil
	}
	
	order, err := o.legacySystem.CreateOrder(ctx, data)
	if err != nil {
		return nil, fmt.Errorf("legacy order system: %w", err)
	}
	return order, nil
}

func (o *OrderFacade) canUseNewSystem(ctx context.Context, data OrderData) bool {
	// Critères de migration progressifs
	return data.Region == "EU" &&
		data.Total < 10000 &&
		o.features.IsEnabled(ctx, "new-order-system")
}
```

**Quand :** Migrer un monolithe, remplacer un système legacy.

**Lié à :** Branch by Abstraction, Anti-Corruption Layer

---

## 3. Parallel Run

> Exécuter deux implémentations en parallèle et comparer les résultats.

```go
package processor

import (
	"context"
	"fmt"
	"log/slog"

	"golang.org/x/sync/errgroup"
)

// Data represents input data for processing.
type Data struct {
	ID      string
	Payload []byte
}

// ProcessResult represents processing result.
type ProcessResult struct {
	ID     string
	Output []byte
	Error  error
}

// Processor defines the processing interface.
type Processor interface {
	Process(ctx context.Context, data Data) (*ProcessResult, error)
}

// Comparator compares two results.
type Comparator interface {
	Compare(ctx context.Context, legacy, modern *ProcessResult)
}

type ParallelProcessor struct {
	legacy  Processor
	modern  Processor
	compare Comparator
	logger  *slog.Logger
}

func NewParallelProcessor(
	legacy, modern Processor,
	comparator Comparator,
	logger *slog.Logger,
) *ParallelProcessor {
	return &ParallelProcessor{
		legacy:  legacy,
		modern:  modern,
		compare: comparator,
		logger:  logger,
	}
}

func (p *ParallelProcessor) Process(ctx context.Context, data Data) (*ProcessResult, error) {
	var legacyResult, modernResult *ProcessResult
	var legacyErr, modernErr error

	g, gctx := errgroup.WithContext(ctx)

	// Exécuter legacy
	g.Go(func() error {
		legacyResult, legacyErr = p.legacy.Process(gctx, data)
		return legacyErr
	})

	// Exécuter modern (ne pas propager l'erreur)
	g.Go(func() error {
		modernResult, modernErr = p.modern.Process(gctx, data)
		if modernErr != nil {
			p.logger.Error("modern processor failed",
				"error", modernErr,
				"data_id", data.ID)
		}
		return nil // Ne pas bloquer le legacy
	})

	// Attendre les deux
	if err := g.Wait(); err != nil {
		return nil, fmt.Errorf("legacy processor: %w", err)
	}

	// Comparer en arrière-plan
	go p.compare.Compare(context.Background(), legacyResult, modernResult)

	// Retourner le résultat de confiance (legacy)
	return legacyResult, nil
}
```

**Quand :** Valider une nouvelle implémentation en production.

---

## 4. Dark Launch

> Activer du code en production sans exposer le résultat.

```go
package feature

import (
	"context"
	"log/slog"
)

// Data represents input data.
type Data struct {
	ID      string
	Payload map[string]interface{}
}

// Result represents processing result.
type Result struct {
	Data   Data
	Output interface{}
}

// Processor processes data.
type Processor interface {
	Process(ctx context.Context, data Data) (*Result, error)
}

// MetricsRecorder records metrics.
type MetricsRecorder interface {
	Record(ctx context.Context, result *Result)
}

type DarkLaunchFeature struct {
	legacy  Processor
	modern  Processor
	metrics MetricsRecorder
	logger  *slog.Logger
}

func NewDarkLaunchFeature(
	legacy, modern Processor,
	metrics MetricsRecorder,
	logger *slog.Logger,
) *DarkLaunchFeature {
	return &DarkLaunchFeature{
		legacy:  legacy,
		modern:  modern,
		metrics: metrics,
		logger:  logger,
	}
}

func (d *DarkLaunchFeature) Process(ctx context.Context, data Data) (*Result, error) {
	// Exécuter le code legacy (celui de confiance)
	result, err := d.legacy.Process(ctx, data)
	if err != nil {
		return nil, err
	}

	// Exécuter le nouveau code sans utiliser le résultat
	// Ne pas bloquer la réponse, ne pas propager les erreurs
	go func() {
		// Créer un nouveau contexte pour éviter l'annulation
		bgCtx := context.Background()
		
		modernResult, modernErr := d.modern.Process(bgCtx, data)
		if modernErr != nil {
			d.logger.Error("dark launch error",
				"error", modernErr,
				"data_id", data.ID)
			return
		}

		// Enregistrer les métriques
		d.metrics.Record(bgCtx, modernResult)
	}()

	return result, nil
}
```

**Quand :** Tester la charge et les performances avant activation.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Remplacer une dépendance | Branch by Abstraction |
| Migrer un système legacy | Strangler Fig |
| Valider en production | Parallel Run |
| Tester la charge | Dark Launch |
| Rollback instantané | Feature Toggle |
| Migration base de données | Double-Write + Switch |

---

## Workflow de migration type

```
1. Créer l'abstraction (interface)
       │
2. Implémenter le nouveau code
       │
3. Double-write (si données)
       │
4. Parallel Run (validation)
       │
5. Feature Toggle (rollout)
       │  0% → 1% → 10% → 50% → 100%
       │
6. Supprimer l'ancien code
       │
7. Supprimer le toggle
```

---

## Sources

- [Martin Fowler - Branch by Abstraction](https://martinfowler.com/bliki/BranchByAbstraction.html)
- [Martin Fowler - Strangler Fig](https://martinfowler.com/bliki/StranglerFigApplication.html)
- [Trunk Based Development](https://trunkbaseddevelopment.com/)
