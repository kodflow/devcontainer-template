# Structural Patterns (GoF)

Patterns de composition d'objets.

## Fichiers detailles

| Pattern | Fichier | Description |
|---------|---------|-------------|
| Adapter | [adapter.md](adapter.md) | Convertir interfaces incompatibles |
| Decorator | [decorator.md](decorator.md) | Ajouter comportements dynamiquement |
| Proxy | [proxy.md](proxy.md) | Virtual, Remote, Protection, Cache |
| Facade | [facade.md](facade.md) | Simplifier systemes complexes |

## Les 7 Patterns

### 1. Adapter

> Convertir une interface en une autre.

Voir fichier detaille: [adapter.md](adapter.md)

```go
package adapter

import "context"

// PaymentProcessor is our target interface.
type PaymentProcessor interface {
	Pay(ctx context.Context, amount float64) error
}

// StripeAPI is the external API we adapt.
type StripeAPI struct{}

func (s *StripeAPI) Charge(amountCents int64, currency string) error {
	// Stripe-specific implementation
	return nil
}

// StripeAdapter adapts StripeAPI to PaymentProcessor.
type StripeAdapter struct {
	stripe *StripeAPI
}

func NewStripeAdapter(stripe *StripeAPI) *StripeAdapter {
	return &StripeAdapter{stripe: stripe}
}

func (a *StripeAdapter) Pay(ctx context.Context, amount float64) error {
	return a.stripe.Charge(int64(amount*100), "EUR")
}
```

**Quand :** Integrer du code legacy ou librairies tierces.

---

### 2. Bridge

> Separer abstraction et implementation.

```go
package bridge

// Renderer is the implementation interface.
type Renderer interface {
	Render(shape string)
}

// Shape is the abstraction.
type Shape interface {
	Draw()
}

// Circle is a concrete abstraction.
type Circle struct {
	renderer Renderer
}

func NewCircle(renderer Renderer) *Circle {
	return &Circle{renderer: renderer}
}

func (c *Circle) Draw() {
	c.renderer.Render("circle")
}

// OpenGLRenderer is a concrete implementation.
type OpenGLRenderer struct{}

func (r *OpenGLRenderer) Render(shape string) {
	fmt.Printf("OpenGL rendering: %s\n", shape)
}
```

**Quand :** Plusieurs dimensions de variation independantes.

---

### 3. Composite

> Traiter objets simples et composes uniformement.

```go
package composite

// Component defines the common interface.
type Component interface {
	GetPrice() float64
}

// Product is a leaf component.
type Product struct {
	name  string
	price float64
}

func NewProduct(name string, price float64) *Product {
	return &Product{name: name, price: price}
}

func (p *Product) GetPrice() float64 {
	return p.price
}

// Box is a composite component.
type Box struct {
	items []Component
}

func NewBox() *Box {
	return &Box{items: make([]Component, 0)}
}

func (b *Box) Add(item Component) {
	b.items = append(b.items, item)
}

func (b *Box) GetPrice() float64 {
	var total float64
	for _, item := range b.items {
		total += item.GetPrice()
	}
	return total
}
```

**Quand :** Structures arborescentes (menus, fichiers, UI).

---

### 4. Decorator

> Ajouter des comportements dynamiquement.

Voir fichier detaille: [decorator.md](decorator.md)

```go
package decorator

import "context"

// HttpClient is the component interface.
type HttpClient interface {
	Do(ctx context.Context, req *Request) (*Response, error)
}

// LoggingDecorator adds logging to HttpClient.
type LoggingDecorator struct {
	client HttpClient
}

func NewLoggingDecorator(client HttpClient) *LoggingDecorator {
	return &LoggingDecorator{client: client}
}

func (d *LoggingDecorator) Do(ctx context.Context, req *Request) (*Response, error) {
	fmt.Printf("Request: %s %s\n", req.Method, req.URL)
	resp, err := d.client.Do(ctx, req)
	fmt.Printf("Response: %d\n", resp.StatusCode)
	return resp, err
}

// Usage: client = NewLoggingDecorator(NewAuthDecorator(baseClient))
```

**Quand :** Ajouter des responsabilites sans modifier la classe.

---

### 5. Facade

> Interface simplifiee pour un sous-systeme complexe.

Voir fichier detaille: [facade.md](facade.md)

```go
package facade

// VideoPublisher provides a simple API for video publishing.
type VideoPublisher struct {
	videoEncoder *VideoEncoder
	audioEncoder *AudioEncoder
	muxer        *Muxer
	uploader     *Uploader
}

func NewVideoPublisher() *VideoPublisher {
	return &VideoPublisher{
		videoEncoder: &VideoEncoder{},
		audioEncoder: &AudioEncoder{},
		muxer:        &Muxer{},
		uploader:     &Uploader{},
	}
}

func (vp *VideoPublisher) Publish(video, audio string) error {
	v := vp.videoEncoder.Encode(video)
	a := vp.audioEncoder.Encode(audio)
	file := vp.muxer.Mux(v, a)
	return vp.uploader.Upload(file)
}
```

**Quand :** Simplifier l'acces a un systeme complexe.

---

### 6. Flyweight

> Partager des etats communs entre objets.

```go
package flyweight

import "sync"

// CharacterFlyweight contains shared state.
type CharacterFlyweight struct {
	font string
	size int
}

// FlyweightFactory manages shared flyweights.
type FlyweightFactory struct {
	cache map[string]*CharacterFlyweight
	mu    sync.RWMutex
}

func NewFlyweightFactory() *FlyweightFactory {
	return &FlyweightFactory{
		cache: make(map[string]*CharacterFlyweight),
	}
}

func (f *FlyweightFactory) Get(font string, size int) *CharacterFlyweight {
	key := fmt.Sprintf("%s-%d", font, size)

	f.mu.RLock()
	if fw, exists := f.cache[key]; exists {
		f.mu.RUnlock()
		return fw
	}
	f.mu.RUnlock()

	f.mu.Lock()
	defer f.mu.Unlock()

	if fw, exists := f.cache[key]; exists {
		return fw
	}

	fw := &CharacterFlyweight{font: font, size: size}
	f.cache[key] = fw
	return fw
}
```

**Quand :** Beaucoup d'objets similaires (jeux, editeurs texte).

---

### 7. Proxy

> Controler l'acces a un objet.

Voir fichier detaille: [proxy.md](proxy.md)

```go
package proxy

import "sync"

// Image is the subject interface.
type Image interface {
	Display()
}

// RealImage is the real subject.
type RealImage struct {
	filename string
}

func NewRealImage(filename string) *RealImage {
	fmt.Printf("Loading image: %s\n", filename)
	return &RealImage{filename: filename}
}

func (ri *RealImage) Display() {
	fmt.Printf("Displaying: %s\n", ri.filename)
}

// ImageProxy is a virtual proxy.
type ImageProxy struct {
	filename  string
	realImage *RealImage
	once      sync.Once
}

func NewImageProxy(filename string) *ImageProxy {
	return &ImageProxy{filename: filename}
}

func (ip *ImageProxy) Display() {
	ip.once.Do(func() {
		ip.realImage = NewRealImage(ip.filename)
	})
	ip.realImage.Display()
}
```

**Types :** Virtual (lazy), Remote (RPC), Protection (auth), Cache.

---

## Tableau de decision

| Besoin | Pattern |
|--------|---------|
| Convertir interface | Adapter |
| Deux axes de variation | Bridge |
| Structure arborescente | Composite |
| Ajouter comportements | Decorator |
| Simplifier systeme complexe | Facade |
| Partager etat commun | Flyweight |
| Controler acces | Proxy |

## Sources

- [Refactoring Guru - Structural Patterns](https://refactoring.guru/design-patterns/structural-patterns)
