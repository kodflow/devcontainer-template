# Facade Pattern

> Fournir une interface simplifiee a un ensemble de classes complexes.

## Intention

Fournir une interface unifiee a un ensemble d'interfaces d'un sous-systeme.
La facade definit une interface de plus haut niveau qui rend le sous-systeme
plus facile a utiliser.

## Structure

```go
package main

import (
	"bytes"
	"fmt"
	"strings"
)

// 1. Sous-systeme complexe
type VideoFile struct {
	Filename string
}

func NewVideoFile(filename string) *VideoFile {
	return &VideoFile{Filename: filename}
}

type VideoCodec struct{}

func (v *VideoCodec) Decode(file *VideoFile) *bytes.Buffer {
	fmt.Println("Decoding video...")
	return bytes.NewBuffer(nil)
}

type AudioCodec struct{}

func (a *AudioCodec) Decode(file *VideoFile) *bytes.Buffer {
	fmt.Println("Decoding audio...")
	return bytes.NewBuffer(nil)
}

type VideoMixer struct{}

func (v *VideoMixer) Mix(video, audio *bytes.Buffer) *bytes.Buffer {
	fmt.Println("Mixing video and audio...")
	return bytes.NewBuffer(append(video.Bytes(), audio.Bytes()...))
}

type Encoder struct{}

func (e *Encoder) Encode(data *bytes.Buffer, format string) *bytes.Buffer {
	fmt.Printf("Encoding to %s...\n", format)
	return data
}

type FileWriter struct{}

func (f *FileWriter) Write(data *bytes.Buffer, filename string) {
	fmt.Printf("Writing to %s...\n", filename)
}

// 2. Facade
type VideoConverter struct {
	videoCodec *VideoCodec
	audioCodec *AudioCodec
	mixer      *VideoMixer
	encoder    *Encoder
	writer     *FileWriter
}

func NewVideoConverter() *VideoConverter {
	return &VideoConverter{
		videoCodec: &VideoCodec{},
		audioCodec: &AudioCodec{},
		mixer:      &VideoMixer{},
		encoder:    &Encoder{},
		writer:     &FileWriter{},
	}
}

func (v *VideoConverter) Convert(filename, format string) {
	fmt.Printf("Converting %s to %s\n", filename, format)

	file := NewVideoFile(filename)
	video := v.videoCodec.Decode(file)
	audio := v.audioCodec.Decode(file)
	mixed := v.mixer.Mix(video, audio)
	encoded := v.encoder.Encode(mixed, format)

	outputName := strings.TrimSuffix(filename, ".avi") + "." + format
	v.writer.Write(encoded, outputName)

	fmt.Println("Conversion complete!")
}

// Usage simplifie
func main() {
	converter := NewVideoConverter()
	converter.Convert("movie.avi", "mp4")
}
```

## Cas d'usage concrets

### Facade pour E-commerce

```go
package main

import (
	"context"
	"fmt"
)

// Types de donnees
type Card struct {
	Number string
	CVV    string
}

type Address struct {
	Street  string
	City    string
	Country string
}

type OrderItem struct {
	ProductID string
	Quantity  int
}

type Customer struct {
	Email string
	Phone string
}

type Order struct {
	ID            string
	Items         []OrderItem
	Total         float64
	Card          Card
	Address       Address
	Customer      Customer
	TransactionID string
	Status        string
}

type OrderResult struct {
	Success    bool
	OrderID    string
	TrackingID string
}

type OrderStatus struct {
	Status string
}

// Sous-systemes
type InventoryService struct{}

func (i *InventoryService) CheckStock(productID string) bool { return true }
func (i *InventoryService) ReserveStock(productID string, qty int) {
	fmt.Printf("Reserved %d of %s\n", qty, productID)
}
func (i *InventoryService) ReleaseStock(productID string, qty int) {
	fmt.Printf("Released %d of %s\n", qty, productID)
}

type PaymentService struct{}

func (p *PaymentService) Authorize(amount float64, card Card) string {
	return "auth_123"
}
func (p *PaymentService) Capture(authID string) {
	fmt.Printf("Captured payment %s\n", authID)
}
func (p *PaymentService) Refund(authID string) {
	fmt.Printf("Refunded %s\n", authID)
}

type ShippingService struct{}

func (s *ShippingService) CalculateCost(address Address) float64 { return 10.0 }
func (s *ShippingService) CreateLabel(order *Order) string       { return "SHIP_123" }
func (s *ShippingService) SchedulePickup(labelID string) {
	fmt.Printf("Scheduled pickup for %s\n", labelID)
}

type NotificationService struct{}

func (n *NotificationService) SendEmail(to, template string, data map[string]string) {
	fmt.Printf("Email sent to %s\n", to)
}
func (n *NotificationService) SendSMS(phone, message string) {
	fmt.Printf("SMS sent to %s\n", phone)
}

// Facade
type OrderFacade struct {
	inventory    *InventoryService
	payment      *PaymentService
	shipping     *ShippingService
	notification *NotificationService
}

func NewOrderFacade(
	inventory *InventoryService,
	payment *PaymentService,
	shipping *ShippingService,
	notification *NotificationService,
) *OrderFacade {
	return &OrderFacade{
		inventory:    inventory,
		payment:      payment,
		shipping:     shipping,
		notification: notification,
	}
}

func (o *OrderFacade) PlaceOrder(ctx context.Context, order *Order) (*OrderResult, error) {
	// 1. Verifier stock
	for _, item := range order.Items {
		if !o.inventory.CheckStock(item.ProductID) {
			return nil, fmt.Errorf("out of stock: %s", item.ProductID)
		}
	}

	// 2. Reserver stock
	for _, item := range order.Items {
		o.inventory.ReserveStock(item.ProductID, item.Quantity)
	}

	// 3. Paiement
	authID := o.payment.Authorize(order.Total, order.Card)
	if authID == "" {
		// Rollback
		for _, item := range order.Items {
			o.inventory.ReleaseStock(item.ProductID, item.Quantity)
		}
		return nil, fmt.Errorf("payment authorization failed")
	}
	o.payment.Capture(authID)

	// 4. Livraison
	shippingCost := o.shipping.CalculateCost(order.Address)
	_ = shippingCost // Utilise si necessaire
	labelID := o.shipping.CreateLabel(order)
	o.shipping.SchedulePickup(labelID)

	// 5. Notifications
	o.notification.SendEmail(
		order.Customer.Email,
		"order_confirmation",
		map[string]string{
			"orderId":    order.ID,
			"trackingId": labelID,
		},
	)

	return &OrderResult{
		Success:    true,
		OrderID:    order.ID,
		TrackingID: labelID,
	}, nil
}

func (o *OrderFacade) CancelOrder(ctx context.Context, orderID string) error {
	// Logique complexe simplifiee
	return nil
}

func (o *OrderFacade) GetOrderStatus(ctx context.Context, orderID string) (*OrderStatus, error) {
	// Agregation de plusieurs services
	return &OrderStatus{Status: "processing"}, nil
}
```

### Facade pour API Client

```go
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// Sous-systemes
type AuthClient struct {
	token string
}

func (a *AuthClient) GetToken(ctx context.Context) (string, error) {
	return a.token, nil
}

func (a *AuthClient) RefreshToken(ctx context.Context) (string, error) {
	return "new_token", nil
}

type RequestConfig struct {
	Method  string
	URL     string
	Headers map[string]string
	Body    io.Reader
}

type HTTPClient struct {
	client *http.Client
}

func (h *HTTPClient) Request(ctx context.Context, config RequestConfig) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, config.Method, config.URL, config.Body)
	if err != nil {
		return nil, fmt.Errorf("creating request: %w", err)
	}

	for k, v := range config.Headers {
		req.Header.Set(k, v)
	}

	return h.client.Do(req)
}

type RetryPolicy struct{}

func (r *RetryPolicy) Execute(ctx context.Context, fn func() error) error {
	// Logique de retry
	return fn()
}

type CircuitBreaker struct{}

func (c *CircuitBreaker) Execute(ctx context.Context, fn func() error) error {
	// Logique circuit breaker
	return fn()
}

// Facade
type APIClient struct {
	auth    *AuthClient
	http    *HTTPClient
	retry   *RetryPolicy
	circuit *CircuitBreaker
}

func NewAPIClient() *APIClient {
	return &APIClient{
		auth:    &AuthClient{token: "initial_token"},
		http:    &HTTPClient{client: http.DefaultClient},
		retry:   &RetryPolicy{},
		circuit: &CircuitBreaker{},
	}
}

func (a *APIClient) Get(ctx context.Context, path string, result interface{}) error {
	return a.request(ctx, "GET", path, nil, result)
}

func (a *APIClient) Post(ctx context.Context, path string, body, result interface{}) error {
	bodyBytes, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("marshaling body: %w", err)
	}
	return a.request(ctx, "POST", path, strings.NewReader(string(bodyBytes)), result)
}

func (a *APIClient) request(ctx context.Context, method, path string, body io.Reader, result interface{}) error {
	return a.circuit.Execute(ctx, func() error {
		return a.retry.Execute(ctx, func() error {
			token, err := a.auth.GetToken(ctx)
			if err != nil {
				return fmt.Errorf("getting token: %w", err)
			}

			response, err := a.http.Request(ctx, RequestConfig{
				Method: method,
				URL:    "https://api.example.com" + path,
				Headers: map[string]string{
					"Authorization": "Bearer " + token,
					"Content-Type":  "application/json",
				},
				Body: body,
			})
			if err != nil {
				return fmt.Errorf("making request: %w", err)
			}
			defer response.Body.Close()

			if response.StatusCode >= 400 {
				return fmt.Errorf("API error: %d", response.StatusCode)
			}

			if result != nil {
				if err := json.NewDecoder(response.Body).Decode(result); err != nil {
					return fmt.Errorf("decoding response: %w", err)
				}
			}

			return nil
		})
	})
}

// Usage simple
type User struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

func main() {
	api := NewAPIClient()
	var users []User
	if err := api.Get(context.Background(), "/users", &users); err != nil {
		fmt.Printf("Error: %v\n", err)
	}
}
```

## Variantes

### Facade avec options

```go
package main

type ConverterQuality string

const (
	QualityLow    ConverterQuality = "low"
	QualityMedium ConverterQuality = "medium"
	QualityHigh   ConverterQuality = "high"
)

type ConverterOptions struct {
	Quality   ConverterQuality
	Watermark string
	OutputDir string
}

type ConfigurableVideoConverter struct {
	options ConverterOptions
}

func NewConfigurableVideoConverter(opts ConverterOptions) *ConfigurableVideoConverter {
	// Valeurs par defaut
	if opts.Quality == "" {
		opts.Quality = QualityMedium
	}
	if opts.OutputDir == "" {
		opts.OutputDir = "./output"
	}

	return &ConfigurableVideoConverter{
		options: opts,
	}
}

func (c *ConfigurableVideoConverter) Convert(filename, format string) {
	// Utilise c.options
}
```

### Facade avec acces aux sous-systemes

```go
package main

type VideoConverter2 struct {
	// Sous-systemes exposes pour cas avances
	Encoder *Encoder
	Mixer   *VideoMixer

	// Prives
	videoCodec *VideoCodec
	audioCodec *AudioCodec
	writer     *FileWriter
}

func NewVideoConverter2() *VideoConverter2 {
	return &VideoConverter2{
		Encoder:    &Encoder{},
		Mixer:      &VideoMixer{},
		videoCodec: &VideoCodec{},
		audioCodec: &AudioCodec{},
		writer:     &FileWriter{},
	}
}

// Methodes simplifiees pour cas courants
func (v *VideoConverter2) Convert(filename, format string) {
	// ...
}

// Les utilisateurs avances peuvent acceder directement
// aux sous-systemes si necessaire
```

## Anti-patterns

```go
// MAUVAIS: Facade qui devient God Object
type GodFacade struct {
	// Trop de responsabilites
}

func (g *GodFacade) CreateUser() {}
func (g *GodFacade) ProcessPayment() {}
func (g *GodFacade) SendNotification() {}
func (g *GodFacade) GenerateReport() {}
func (g *GodFacade) BackupDatabase() {}
// ...50 autres methodes

// MAUVAIS: Facade qui expose trop de details
type LeakyFacade struct {
	inventory *InventoryService
}

func (l *LeakyFacade) GetInventoryService() *InventoryService {
	return l.inventory // Fuite d'abstraction
}

// MAUVAIS: Facade sans valeur ajoutee
type UselessFacade struct {
	service *SomeService
}

func (u *UselessFacade) DoSomething() {
	u.service.DoSomething() // Simple delegation
}
```

## Tests unitaires

```go
package main

import (
	"context"
	"testing"
)

func TestOrderFacade_PlaceOrder(t *testing.T) {
	facade := NewOrderFacade(
		&InventoryService{},
		&PaymentService{},
		&ShippingService{},
		&NotificationService{},
	)

	order := &Order{
		ID:    "order_1",
		Total: 100.0,
		Items: []OrderItem{{ProductID: "prod_1", Quantity: 2}},
		Customer: Customer{Email: "test@example.com"},
	}

	result, err := facade.PlaceOrder(context.Background(), order)
	if err != nil {
		t.Fatalf("PlaceOrder failed: %v", err)
	}

	if !result.Success {
		t.Error("Expected success")
	}
	if result.OrderID != "order_1" {
		t.Errorf("Expected order_1, got %s", result.OrderID)
	}
}

func TestVideoConverter_Convert(t *testing.T) {
	converter := NewVideoConverter()
	converter.Convert("test.avi", "mp4")
	// Verifier les logs ou le comportement
}
```

## Quand utiliser

- Simplifier l'acces a un sous-systeme complexe
- Reduire le couplage entre client et sous-systeme
- Definir des points d'entree dans les couches
- Orchestrer plusieurs services

## Patterns lies

- **Adapter** : Interface differente vs interface simplifiee
- **Mediator** : Centralise communication entre composants
- **Singleton** : Facade souvent en instance unique

## Sources

- [Refactoring Guru - Facade](https://refactoring.guru/design-patterns/facade)
