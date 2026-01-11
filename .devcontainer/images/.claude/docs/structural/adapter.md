# Adapter Pattern

> Convertir l'interface d'une classe en une autre interface attendue par le client.

## Intention

Permettre a des classes avec des interfaces incompatibles de travailler
ensemble en encapsulant une classe existante avec une nouvelle interface.

## Structure

```go
package main

import (
	"context"
	"fmt"
	"strings"
)

// 1. Interface cible (ce que le client attend)
type PaymentProcessor interface {
	Charge(ctx context.Context, amount float64, currency string) (*PaymentResult, error)
	Refund(ctx context.Context, transactionID string, amount float64) (*RefundResult, error)
}

type PaymentResult struct {
	TransactionID string
	Status        string // "success" or "failed"
}

type RefundResult struct {
	RefundID string
	Status   string // "success" or "failed"
}

// 2. Classe existante (interface incompatible)
type StripeCharge struct {
	ID     string
	Amount int64
	Status string
}

type StripeRefund struct {
	ID     string
	Charge string
	Status string
}

type StripeAPI struct{}

func (s *StripeAPI) CreateCharge(ctx context.Context, amount int64, currency, source string) (*StripeCharge, error) {
	// API Stripe reelle
	return &StripeCharge{
		ID:     "ch_123",
		Amount: amount,
		Status: "succeeded",
	}, nil
}

func (s *StripeAPI) CreateRefund(ctx context.Context, chargeID string, amount int64) (*StripeRefund, error) {
	return &StripeRefund{
		ID:     "re_123",
		Charge: chargeID,
		Status: "succeeded",
	}, nil
}

// 3. Adapter
type StripeAdapter struct {
	stripe        *StripeAPI
	defaultSource string
}

func NewStripeAdapter(stripe *StripeAPI, defaultSource string) *StripeAdapter {
	return &StripeAdapter{
		stripe:        stripe,
		defaultSource: defaultSource,
	}
}

func (s *StripeAdapter) Charge(ctx context.Context, amount float64, currency string) (*PaymentResult, error) {
	// Stripe utilise les centimes
	amountCents := int64(amount * 100)

	result, err := s.stripe.CreateCharge(
		ctx,
		amountCents,
		strings.ToLower(currency),
		s.defaultSource,
	)
	if err != nil {
		return nil, fmt.Errorf("stripe charge failed: %w", err)
	}

	status := "failed"
	if result.Status == "succeeded" {
		status = "success"
	}

	return &PaymentResult{
		TransactionID: result.ID,
		Status:        status,
	}, nil
}

func (s *StripeAdapter) Refund(ctx context.Context, transactionID string, amount float64) (*RefundResult, error) {
	amountCents := int64(amount * 100)

	result, err := s.stripe.CreateRefund(ctx, transactionID, amountCents)
	if err != nil {
		return nil, fmt.Errorf("stripe refund failed: %w", err)
	}

	status := "failed"
	if result.Status == "succeeded" {
		status = "success"
	}

	return &RefundResult{
		RefundID: result.ID,
		Status:   status,
	}, nil
}
```

## Usage

```go
package main

import (
	"context"
	"fmt"
)

type Order struct {
	Total         float64
	Currency      string
	TransactionID string
	Status        string
}

// Le client utilise l'interface generique
type PaymentService struct {
	processor PaymentProcessor
}

func NewPaymentService(processor PaymentProcessor) *PaymentService {
	return &PaymentService{processor: processor}
}

func (p *PaymentService) ProcessOrder(ctx context.Context, order *Order) error {
	result, err := p.processor.Charge(ctx, order.Total, order.Currency)
	if err != nil {
		return fmt.Errorf("processing payment: %w", err)
	}

	if result.Status == "success" {
		order.TransactionID = result.TransactionID
		order.Status = "paid"
	}

	return nil
}

// Configuration
func main() {
	stripeAPI := &StripeAPI{}
	adapter := NewStripeAdapter(stripeAPI, "tok_visa")
	paymentService := NewPaymentService(adapter)

	order := &Order{Total: 100.0, Currency: "USD"}
	if err := paymentService.ProcessOrder(context.Background(), order); err != nil {
		fmt.Printf("Error: %v\n", err)
	}
}
```

## Variantes

### Object Adapter (composition - recommande)

```go
type StripeAdapter struct {
	stripe *StripeAPI // Composition
}
```

### Embedding Adapter (similaire au Class Adapter)

```go
type StripeEmbeddingAdapter struct {
	*StripeAPI // Embedding
	defaultSource string
}

func (s *StripeEmbeddingAdapter) Charge(ctx context.Context, amount float64, currency string) (*PaymentResult, error) {
	amountCents := int64(amount * 100)
	result, err := s.CreateCharge(ctx, amountCents, currency, s.defaultSource)
	if err != nil {
		return nil, err
	}
	return &PaymentResult{TransactionID: result.ID, Status: "success"}, nil
}
```

### Two-Way Adapter

```go
package main

import (
	"log/slog"
)

type ModernLogger interface {
	Log(level, message string, meta map[string]interface{})
}

type LegacyLogger interface {
	Info(message string)
	Error(message string)
}

type TwoWayLoggerAdapter struct {
	modern ModernLogger
	legacy LegacyLogger
}

func NewTwoWayLoggerAdapter(modern ModernLogger, legacy LegacyLogger) *TwoWayLoggerAdapter {
	return &TwoWayLoggerAdapter{
		modern: modern,
		legacy: legacy,
	}
}

// Interface moderne
func (t *TwoWayLoggerAdapter) Log(level, message string, meta map[string]interface{}) {
	if t.modern != nil {
		t.modern.Log(level, message, meta)
	} else if t.legacy != nil {
		if level == "error" {
			t.legacy.Error(message)
		} else {
			t.legacy.Info(message)
		}
	}
}

// Interface legacy
func (t *TwoWayLoggerAdapter) Info(message string) {
	t.Log("info", message, nil)
}

func (t *TwoWayLoggerAdapter) Error(message string) {
	t.Log("error", message, nil)
}
```

### Adapter avec cache

```go
package main

import (
	"context"
	"sync"
)

type CachedPaymentAdapter struct {
	adapter PaymentProcessor
	cache   map[string]*PaymentResult
	mu      sync.RWMutex
}

func NewCachedPaymentAdapter(adapter PaymentProcessor) *CachedPaymentAdapter {
	return &CachedPaymentAdapter{
		adapter: adapter,
		cache:   make(map[string]*PaymentResult),
	}
}

func (c *CachedPaymentAdapter) Charge(ctx context.Context, amount float64, currency string) (*PaymentResult, error) {
	// Pas de cache pour les charges (non idempotent)
	return c.adapter.Charge(ctx, amount, currency)
}

func (c *CachedPaymentAdapter) Refund(ctx context.Context, transactionID string, amount float64) (*RefundResult, error) {
	return c.adapter.Refund(ctx, transactionID, amount)
}

// Methode supplementaire pour consulter l'historique
func (c *CachedPaymentAdapter) GetHistory() []*PaymentResult {
	c.mu.RLock()
	defer c.mu.RUnlock()

	history := make([]*PaymentResult, 0, len(c.cache))
	for _, result := range c.cache {
		history = append(history, result)
	}
	return history
}
```

## Cas d'usage concrets

### Adapter pour API tierce

```go
package main

type ExternalWeatherData struct {
	TempC       float64
	HumidityPct int
	WindKph     float64
}

// API externe avec format different
type ExternalWeatherAPI struct{}

func (e *ExternalWeatherAPI) GetWeather(lat, lon float64) *ExternalWeatherData {
	return &ExternalWeatherData{
		TempC:       22.0,
		HumidityPct: 65,
		WindKph:     15.0,
	}
}

// Notre interface interne
type WeatherData struct {
	Temperature float64
	Humidity    int
	WindSpeed   float64
	Unit        string // "celsius" or "fahrenheit"
}

type WeatherAdapter struct {
	api *ExternalWeatherAPI
}

func NewWeatherAdapter(api *ExternalWeatherAPI) *WeatherAdapter {
	return &WeatherAdapter{api: api}
}

func (w *WeatherAdapter) GetWeather(lat, lon float64) *WeatherData {
	data := w.api.GetWeather(lat, lon)
	return &WeatherData{
		Temperature: data.TempC,
		Humidity:    data.HumidityPct,
		WindSpeed:   data.WindKph,
		Unit:        "celsius",
	}
}
```

### Adapter pour legacy code

```go
package main

import (
	"context"
	"fmt"
)

// Ancien systeme callback-based
type LegacyFileReader struct{}

func (l *LegacyFileReader) Read(path string, callback func(error, string)) {
	// Simule lecture asynchrone
	callback(nil, "file contents")
}

// Interface moderne Promise-based
type FileReader interface {
	Read(ctx context.Context, path string) (string, error)
}

type FileReaderAdapter struct {
	legacy *LegacyFileReader
}

func NewFileReaderAdapter(legacy *LegacyFileReader) *FileReaderAdapter {
	return &FileReaderAdapter{legacy: legacy}
}

func (f *FileReaderAdapter) Read(ctx context.Context, path string) (string, error) {
	resultChan := make(chan string, 1)
	errChan := make(chan error, 1)

	f.legacy.Read(path, func(err error, data string) {
		if err != nil {
			errChan <- err
		} else {
			resultChan <- data
		}
	})

	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case err := <-errChan:
		return "", err
	case data := <-resultChan:
		return data, nil
	}
}
```

## Anti-patterns

```go
// MAUVAIS: Adapter qui fait trop
type OverloadedAdapter struct {
	stripe *StripeAPI
}

func (o *OverloadedAdapter) Charge(ctx context.Context, amount float64, currency string) (*PaymentResult, error) {
	// Validation - devrait etre ailleurs
	if amount <= 0 {
		return nil, fmt.Errorf("invalid amount")
	}

	// Logging - cross-cutting concern
	fmt.Println("Processing payment...")

	// Business logic - ne devrait pas etre ici
	fee := amount * 0.03
	total := amount + fee

	// Finalement l'adaptation
	result, _ := o.stripe.CreateCharge(ctx, int64(total*100), currency, "")
	return &PaymentResult{TransactionID: result.ID, Status: "success"}, nil
}

// MAUVAIS: Adapter qui expose l'implementation
type LeakyAdapter struct {
	stripe *StripeAPI
}

func (l *LeakyAdapter) GetStripeInstance() *StripeAPI {
	return l.stripe // Fuite d'abstraction!
}
```

## Tests unitaires

```go
package main

import (
	"context"
	"testing"
)

func TestStripeAdapter_Charge(t *testing.T) {
	mockStripe := &StripeAPI{}
	adapter := NewStripeAdapter(mockStripe, "tok_test")

	result, err := adapter.Charge(context.Background(), 100.0, "USD")
	if err != nil {
		t.Fatalf("Charge failed: %v", err)
	}

	if result.TransactionID != "ch_123" {
		t.Errorf("Expected ch_123, got %s", result.TransactionID)
	}

	if result.Status != "success" {
		t.Errorf("Expected success, got %s", result.Status)
	}
}

func TestStripeAdapter_ConvertsCurrency(t *testing.T) {
	mockStripe := &StripeAPI{}
	adapter := NewStripeAdapter(mockStripe, "tok_test")

	// Verifie conversion dollars -> centimes
	_, err := adapter.Charge(context.Background(), 100.0, "USD")
	if err != nil {
		t.Fatalf("Charge failed: %v", err)
	}

	// Verifier que l'API Stripe a recu 10000 centimes
}
```

## Quand utiliser

- Integrer du code legacy ou bibliotheques tierces
- Uniformiser des interfaces incompatibles
- Isoler le code client des changements d'API
- Reutiliser des classes existantes sans les modifier

## Patterns lies

- **Bridge** : Separe abstraction/implementation (conception)
- **Decorator** : Ajoute des comportements (meme interface)
- **Facade** : Simplifie une interface complexe
- **Proxy** : Meme interface, controle d'acces

## Sources

- [Refactoring Guru - Adapter](https://refactoring.guru/design-patterns/adapter)
