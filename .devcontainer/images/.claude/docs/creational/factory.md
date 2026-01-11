# Factory Patterns

> Deleguer la creation d'objets a des methodes ou classes specialisees.

## Factory Method

### Intention

Definir une interface pour creer un objet, mais laisser les sous-classes
decider quelle classe instancier.

### Structure

```go
package main

import (
	"context"
	"fmt"
)

// 1. Interface produit
type Notification interface {
	Send(ctx context.Context, message string) error
}

// 2. Produits concrets
type EmailNotification struct {
	email string
}

// NewEmailNotification cree une notification email.
func NewEmailNotification(email string) *EmailNotification {
	return &EmailNotification{email: email}
}

func (n *EmailNotification) Send(ctx context.Context, message string) error {
	fmt.Printf("Email to %s: %s\n", n.email, message)
	return nil
}

type SMSNotification struct {
	phone string
}

// NewSMSNotification cree une notification SMS.
func NewSMSNotification(phone string) *SMSNotification {
	return &SMSNotification{phone: phone}
}

func (n *SMSNotification) Send(ctx context.Context, message string) error {
	fmt.Printf("SMS to %s: %s\n", n.phone, message)
	return nil
}

type PushNotification struct {
	deviceID string
}

// NewPushNotification cree une notification push.
func NewPushNotification(deviceID string) *PushNotification {
	return &PushNotification{deviceID: deviceID}
}

func (n *PushNotification) Send(ctx context.Context, message string) error {
	fmt.Printf("Push to %s: %s\n", n.deviceID, message)
	return nil
}

// 3. Factory interface
type NotificationFactory interface {
	CreateNotification(recipient string) Notification
	Notify(ctx context.Context, recipient, message string) error
}

// 4. Factory de base avec methode template
type baseFactory struct{}

func (f *baseFactory) Notify(ctx context.Context, factory NotificationFactory, recipient, message string) error {
	notification := factory.CreateNotification(recipient)
	return notification.Send(ctx, message)
}

// 5. Factories concretes
type EmailNotificationFactory struct {
	baseFactory
}

func (f *EmailNotificationFactory) CreateNotification(email string) Notification {
	return NewEmailNotification(email)
}

func (f *EmailNotificationFactory) Notify(ctx context.Context, recipient, message string) error {
	return f.baseFactory.Notify(ctx, f, recipient, message)
}

type SMSNotificationFactory struct {
	baseFactory
}

func (f *SMSNotificationFactory) CreateNotification(phone string) Notification {
	return NewSMSNotification(phone)
}

func (f *SMSNotificationFactory) Notify(ctx context.Context, recipient, message string) error {
	return f.baseFactory.Notify(ctx, f, recipient, message)
}
```

## Abstract Factory

### Intention (Abstract Factory)

Fournir une interface pour creer des familles d'objets lies sans specifier
leurs classes concretes.

### Structure (Abstract Factory)

```go
package main

import "fmt"

// 1. Interfaces produits
type Button interface {
	Render() string
	OnClick(handler func())
}

type Input interface {
	Render() string
	GetValue() string
}

type Modal interface {
	Open()
	Close()
}

// 2. Abstract Factory interface
type UIFactory interface {
	CreateButton(label string) Button
	CreateInput(placeholder string) Input
	CreateModal(title string) Modal
}

// 3. Famille Material Design
type MaterialButton struct {
	label   string
	handler func()
}

func (b *MaterialButton) Render() string {
	return fmt.Sprintf("<md-button>%s</md-button>", b.label)
}

func (b *MaterialButton) OnClick(handler func()) {
	b.handler = handler
}

type MaterialInput struct {
	placeholder string
	value       string
}

func (i *MaterialInput) Render() string {
	return fmt.Sprintf(`<md-input placeholder="%s">`, i.placeholder)
}

func (i *MaterialInput) GetValue() string {
	return i.value
}

type MaterialModal struct {
	title string
}

func (m *MaterialModal) Open() {
	fmt.Printf("Opening Material modal: %s\n", m.title)
}

func (m *MaterialModal) Close() {
	fmt.Println("Closing Material modal")
}

type MaterialUIFactory struct{}

func (f *MaterialUIFactory) CreateButton(label string) Button {
	return &MaterialButton{label: label}
}

func (f *MaterialUIFactory) CreateInput(placeholder string) Input {
	return &MaterialInput{placeholder: placeholder}
}

func (f *MaterialUIFactory) CreateModal(title string) Modal {
	return &MaterialModal{title: title}
}

// 4. Famille Bootstrap
type BootstrapButton struct {
	label   string
	handler func()
}

func (b *BootstrapButton) Render() string {
	return fmt.Sprintf(`<button class="btn">%s</button>`, b.label)
}

func (b *BootstrapButton) OnClick(handler func()) {
	b.handler = handler
}

type BootstrapInput struct {
	placeholder string
	value       string
}

func (i *BootstrapInput) Render() string {
	return fmt.Sprintf(`<input class="form-control" placeholder="%s">`, i.placeholder)
}

func (i *BootstrapInput) GetValue() string {
	return i.value
}

type BootstrapModal struct {
	title string
}

func (m *BootstrapModal) Open() {
	fmt.Printf("Opening Bootstrap modal: %s\n", m.title)
}

func (m *BootstrapModal) Close() {
	fmt.Println("Closing Bootstrap modal")
}

type BootstrapUIFactory struct{}

func (f *BootstrapUIFactory) CreateButton(label string) Button {
	return &BootstrapButton{label: label}
}

func (f *BootstrapUIFactory) CreateInput(placeholder string) Input {
	return &BootstrapInput{placeholder: placeholder}
}

func (f *BootstrapUIFactory) CreateModal(title string) Modal {
	return &BootstrapModal{title: title}
}
```

## Simple Factory (non-GoF mais courant)

```go
package main

import (
	"errors"
	"fmt"
)

type NotificationType string

const (
	NotificationEmail NotificationType = "email"
	NotificationSMS   NotificationType = "sms"
	NotificationPush  NotificationType = "push"
)

// CreateNotification cree une notification selon le type.
func CreateNotification(notifType NotificationType, recipient string) (Notification, error) {
	switch notifType {
	case NotificationEmail:
		return NewEmailNotification(recipient), nil
	case NotificationSMS:
		return NewSMSNotification(recipient), nil
	case NotificationPush:
		return NewPushNotification(recipient), nil
	default:
		return nil, fmt.Errorf("unknown notification type: %s", notifType)
	}
}

// Usage
func ExampleSimpleFactory() {
	notification, err := CreateNotification(NotificationEmail, "user@example.com")
	if err != nil {
		panic(err)
	}
	_ = notification
}
```

## Variantes modernes

### Factory avec registre

```go
package main

import (
	"errors"
	"fmt"
	"sync"
)

// Creator definit une fonction de creation.
type Creator func(...interface{}) Notification

// NotificationRegistry gere un registre de creators.
type NotificationRegistry struct {
	mu       sync.RWMutex
	creators map[string]Creator
}

// NewNotificationRegistry cree un nouveau registre.
func NewNotificationRegistry() *NotificationRegistry {
	return &NotificationRegistry{
		creators: make(map[string]Creator),
	}
}

// Register enregistre un creator pour un type donne.
func (r *NotificationRegistry) Register(notifType string, creator Creator) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.creators[notifType] = creator
}

// Create cree une notification selon le type enregistre.
func (r *NotificationRegistry) Create(notifType string, args ...interface{}) (Notification, error) {
	r.mu.RLock()
	creator, exists := r.creators[notifType]
	r.mu.RUnlock()

	if !exists {
		return nil, fmt.Errorf("unknown type: %s", notifType)
	}
	return creator(args...), nil
}

// Usage
func ExampleRegistry() {
	registry := NewNotificationRegistry()

	registry.Register("email", func(args ...interface{}) Notification {
		return NewEmailNotification(args[0].(string))
	})

	registry.Register("sms", func(args ...interface{}) Notification {
		return NewSMSNotification(args[0].(string))
	})

	notification, err := registry.Create("email", "user@example.com")
	if err != nil {
		panic(err)
	}
	_ = notification
}
```

### Factory avec Dependency Injection

```go
package main

import "context"

// NotificationConfig configure la creation de notifications.
type NotificationConfig struct {
	Type      NotificationType
	Recipient string
}

// NotificationService gere les factories injectees.
type NotificationService struct {
	emailFactory func(string) Notification
	smsFactory   func(string) Notification
	pushFactory  func(string) Notification
}

// NewNotificationService cree un service avec DI.
func NewNotificationService(
	emailFactory func(string) Notification,
	smsFactory func(string) Notification,
	pushFactory func(string) Notification,
) *NotificationService {
	return &NotificationService{
		emailFactory: emailFactory,
		smsFactory:   smsFactory,
		pushFactory:  pushFactory,
	}
}

// Create cree une notification selon la config.
func (s *NotificationService) Create(config NotificationConfig) (Notification, error) {
	switch config.Type {
	case NotificationEmail:
		return s.emailFactory(config.Recipient), nil
	case NotificationSMS:
		return s.smsFactory(config.Recipient), nil
	case NotificationPush:
		return s.pushFactory(config.Recipient), nil
	default:
		return nil, errors.New("unknown notification type")
	}
}
```

## Anti-patterns

```go
// MAUVAIS: Factory avec trop de responsabilites
type GodFactory struct{}

func (f *GodFactory) CreateUser() interface{}         { return nil }
func (f *GodFactory) CreateOrder() interface{}        { return nil }
func (f *GodFactory) CreateNotification() interface{} { return nil }
// Viole SRP

// MAUVAIS: Logique metier dans la factory
func BadCreateNotification(notifType string) Notification {
	notification := NewEmailNotification("")
	// Non! C'est de la logique metier
	// notification.Validate()
	// notification.Save()
	return notification
}

// MAUVAIS: Factory qui retourne interface{} sans type
func UnsafeCreate(notifType string) interface{} {
	// Perte de type safety
	return NewEmailNotification("")
}
```

## Alternative moderne : Functions

```go
package main

import "context"

// Factory functions (plus simple, meme resultat)
func createEmailNotification(email string) Notification {
	return NewEmailNotification(email)
}

func createSMSNotification(phone string) Notification {
	return NewSMSNotification(phone)
}

// NotificationOptions configure les options de notification.
type NotificationOptions struct {
	Retries int
	Timeout int
}

// CreateNotificationWithOptions cree une notification avec options.
func CreateNotificationWithOptions(
	notifType NotificationType,
	recipient string,
	opts NotificationOptions,
) (Notification, error) {
	creators := map[NotificationType]func(string) Notification{
		NotificationEmail: createEmailNotification,
		NotificationSMS:   createSMSNotification,
		NotificationPush:  func(id string) Notification { return NewPushNotification(id) },
	}

	creator, exists := creators[notifType]
	if !exists {
		return nil, errors.New("unknown notification type")
	}
	return creator(recipient), nil
}
```

## Tests unitaires

```go
package main

import (
	"context"
	"testing"
)

func TestEmailNotificationFactory_CreateNotification(t *testing.T) {
	factory := &EmailNotificationFactory{}
	notification := factory.CreateNotification("test@example.com")

	if notification == nil {
		t.Fatal("expected notification, got nil")
	}

	if _, ok := notification.(*EmailNotification); !ok {
		t.Errorf("expected *EmailNotification, got %T", notification)
	}
}

func TestNotificationFactory_Notify(t *testing.T) {
	factory := &SMSNotificationFactory{}
	ctx := context.Background()

	err := factory.Notify(ctx, "+1234567890", "Hello")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestNotificationRegistry(t *testing.T) {
	registry := NewNotificationRegistry()

	registry.Register("webhook", func(args ...interface{}) Notification {
		return NewPushNotification(args[0].(string))
	})

	notification, err := registry.Create("webhook", "https://example.com")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if notification == nil {
		t.Error("expected notification, got nil")
	}
}

func TestNotificationRegistry_UnknownType(t *testing.T) {
	registry := NewNotificationRegistry()

	_, err := registry.Create("unknown")
	if err == nil {
		t.Error("expected error for unknown type")
	}
}

func TestUIFactory_CreateConsistentFamily(t *testing.T) {
	factory := &MaterialUIFactory{}

	button := factory.CreateButton("Click")
	input := factory.CreateInput("Type here")

	if button == nil || input == nil {
		t.Fatal("expected UI components, got nil")
	}

	buttonHTML := button.Render()
	inputHTML := input.Render()

	if buttonHTML == "" || inputHTML == "" {
		t.Error("expected rendered HTML")
	}
}
```

## Quand utiliser

### Choisir Factory Method

- Creation deleguee aux sous-classes
- Produit unique avec variantes

### Choisir Abstract Factory

- Familles d'objets coherents
- Independance plateforme/theme

### Simple Factory

- Logique de creation centralisee
- Pas besoin d'extensibilite par heritage

## Patterns lies

- **Builder** : Construction complexe vs selection de type
- **Prototype** : Clonage vs instantiation
- **Singleton** : Souvent combine avec Factory

## Sources

- [Refactoring Guru - Factory Method](https://refactoring.guru/design-patterns/factory-method)
- [Refactoring Guru - Abstract Factory](https://refactoring.guru/design-patterns/abstract-factory)
