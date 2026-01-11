# Bridge

> Decoupler une abstraction de son implementation pour qu'elles puissent varier independamment.

---

## Principe

Le pattern Bridge separe une grosse classe ou un ensemble de classes liees en deux hierarchies separees - abstraction et implementation - qui peuvent evoluer independamment l'une de l'autre.

```
┌─────────────────┐           ┌─────────────────┐
│   Abstraction   │───────────│  Implementor    │
│  (operation())  │           │  (operationImpl)│
└────────┬────────┘           └────────┬────────┘
         │                             │
┌────────┴────────┐           ┌────────┴────────┐
│RefinedAbstraction│          │ConcreteImpl A/B │
└─────────────────┘           └─────────────────┘
```

---

## Probleme resolu

- Explosion combinatoire de sous-classes (ex: Shape x Color x Platform)
- Couplage fort entre abstraction et implementation
- Besoin d'etendre dans deux dimensions independantes
- Changement d'implementation a l'execution

---

## Solution

```go
package main

import "fmt"

// Implementor definit l'interface d'implementation.
type Renderer interface {
    RenderCircle(radius float64)
    RenderSquare(side float64)
}

// Abstraction definit l'interface de haut niveau.
type Shape interface {
    Draw()
}

// Circle est une abstraction raffinee.
type Circle struct {
    renderer Renderer
    radius   float64
}

func NewCircle(renderer Renderer, radius float64) *Circle {
    return &Circle{renderer: renderer, radius: radius}
}

func (c *Circle) Draw() {
    c.renderer.RenderCircle(c.radius)
}

// Implementations concretes
type VectorRenderer struct{}

func (v *VectorRenderer) RenderCircle(radius float64) {
    fmt.Printf("Drawing circle with radius %.2f as vectors\n", radius)
}

func (v *VectorRenderer) RenderSquare(side float64) {
    fmt.Printf("Drawing square with side %.2f as vectors\n", side)
}

type RasterRenderer struct{}

func (r *RasterRenderer) RenderCircle(radius float64) {
    fmt.Printf("Drawing circle with radius %.2f as pixels\n", radius)
}

func (r *RasterRenderer) RenderSquare(side float64) {
    fmt.Printf("Drawing square with side %.2f as pixels\n", side)
}

// Usage:
// renderer := &VectorRenderer{}
// circle := NewCircle(renderer, 5)
// circle.Draw()
```

---

## Exemple complet

```go
package main

import (
    "fmt"
    "io"
    "os"
)

// MessageSender est l'Implementor.
type MessageSender interface {
    Send(message string) error
}

// Message est l'Abstraction.
type Message struct {
    sender  MessageSender
    content string
}

func NewMessage(sender MessageSender, content string) *Message {
    return &Message{sender: sender, content: content}
}

func (m *Message) Send() error {
    return m.sender.Send(m.content)
}

// UrgentMessage est une abstraction raffinee.
type UrgentMessage struct {
    *Message
    priority int
}

func NewUrgentMessage(sender MessageSender, content string, priority int) *UrgentMessage {
    return &UrgentMessage{
        Message:  NewMessage(sender, content),
        priority: priority,
    }
}

func (u *UrgentMessage) Send() error {
    urgentContent := fmt.Sprintf("[URGENT P%d] %s", u.priority, u.content)
    return u.sender.Send(urgentContent)
}

// EmailSender est une implementation concrete.
type EmailSender struct {
    to   string
    from string
}

func NewEmailSender(from, to string) *EmailSender {
    return &EmailSender{from: from, to: to}
}

func (e *EmailSender) Send(message string) error {
    fmt.Printf("Email from %s to %s: %s\n", e.from, e.to, message)
    return nil
}

// SMSSender est une implementation concrete.
type SMSSender struct {
    phone string
}

func NewSMSSender(phone string) *SMSSender {
    return &SMSSender{phone: phone}
}

func (s *SMSSender) Send(message string) error {
    fmt.Printf("SMS to %s: %s\n", s.phone, message)
    return nil
}

// SlackSender est une implementation concrete.
type SlackSender struct {
    channel string
    webhook string
}

func NewSlackSender(channel, webhook string) *SlackSender {
    return &SlackSender{channel: channel, webhook: webhook}
}

func (s *SlackSender) Send(message string) error {
    fmt.Printf("Slack #%s: %s\n", s.channel, message)
    return nil
}

func main() {
    // Combiner differentes abstractions avec implementations
    emailSender := NewEmailSender("system@example.com", "user@example.com")
    smsSender := NewSMSSender("+1234567890")
    slackSender := NewSlackSender("alerts", "https://hooks.slack.com/...")

    // Message normal via email
    msg1 := NewMessage(emailSender, "Your report is ready")
    msg1.Send()

    // Message urgent via SMS
    msg2 := NewUrgentMessage(smsSender, "Server is down!", 1)
    msg2.Send()

    // Message normal via Slack
    msg3 := NewMessage(slackSender, "Deployment completed")
    msg3.Send()

    // Output:
    // Email from system@example.com to user@example.com: Your report is ready
    // SMS to +1234567890: [URGENT P1] Server is down!
    // Slack #alerts: Deployment completed
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Simple Bridge | Une seule abstraction | Separation implementation |
| Multi-level Bridge | Hierarchies multiples | Frameworks extensibles |
| Dynamic Bridge | Implementation changeable | Runtime switching |

---

## Quand utiliser

- Eviter liaison permanente abstraction/implementation
- Abstractions ET implementations extensibles
- Changements d'implementation transparents pour le client
- Partage d'implementation entre objets

## Quand NE PAS utiliser

- Une seule implementation prevue
- Peu de variations a prevoir
- Complexite non justifiee par les besoins

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Decoupage orthogonal des variations | Complexite accrue |
| Single Responsibility Principle | Indirection supplementaire |
| Open/Closed Principle | Sur-ingenierie possible |
| Changement d'implementation runtime | |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Adapter | Adapte apres conception, Bridge concu en amont |
| Strategy | Strategy change algorithme, Bridge change implementation |
| Abstract Factory | Peut creer les implementations du Bridge |
| Decorator | Enrichit sans changer structure, Bridge separe hierarchies |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| database/sql | Driver interface (implementation) + DB (abstraction) |
| io.Writer | Interface comme pont vers implementations |
| net/http | Handler interface |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Bridge premature | Complexite inutile | Attendre le besoin reel |
| Abstraction trop fine | Fragmentation | Regrouper les responsabilites |
| Implementation leaky | Couplage | Interface bien definie |

---

## Tests

```go
func TestMessage_Send(t *testing.T) {
    sender := NewEmailSender("from@test.com", "to@test.com")
    msg := NewMessage(sender, "Hello")

    err := msg.Send()
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
}

func TestUrgentMessage_Send(t *testing.T) {
    sender := NewSMSSender("+1234567890")
    msg := NewUrgentMessage(sender, "Alert", 1)

    err := msg.Send()
    if err != nil {
        t.Errorf("unexpected error: %v", err)
    }
}

func TestBridge_SwitchImplementation(t *testing.T) {
    email := NewEmailSender("a@b.com", "c@d.com")
    sms := NewSMSSender("+1234567890")

    // Meme abstraction, implementations differentes
    msg1 := NewMessage(email, "Test")
    msg2 := NewMessage(sms, "Test")

    if err := msg1.Send(); err != nil {
        t.Error(err)
    }
    if err := msg2.Send(); err != nil {
        t.Error(err)
    }
}
```

---

## Sources

- [Refactoring Guru - Bridge](https://refactoring.guru/design-patterns/bridge)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Go database/sql as Bridge example](https://pkg.go.dev/database/sql)
