# SOLID Principles

5 principes fondamentaux de la programmation orientée objet par Robert C. Martin.

## Les 5 Principes

### S - Single Responsibility Principle (SRP)

> Une classe ne doit avoir qu'une seule raison de changer.

**Problème :**

```go
// ❌ Mauvais - Multiple responsabilités
type User struct {
	ID    string
	Email string
}

func (u *User) Save() error { /* DB logic */ }
func (u *User) Validate() error { /* Validation logic */ }
func (u *User) SendEmail() error { /* Email logic */ }
```

**Solution :**

```go
// ✅ Bon - Une responsabilité par type
type User struct {
	ID    string
	Email string
}

type UserRepository struct {
	db *sql.DB
}

func (r *UserRepository) Save(user *User) error { /* DB logic */ }

type UserValidator struct{}

func (v *UserValidator) Validate(user *User) error { /* Validation logic */ }

type UserNotifier struct {
	mailer Mailer
}

func (n *UserNotifier) SendEmail(user *User) error { /* Email logic */ }
```

**Quand l'appliquer :** Toujours. C'est le principe le plus fondamental.

---

### O - Open/Closed Principle (OCP)

> Ouvert à l'extension, fermé à la modification.

**Problème :**

```go
// ❌ Mauvais - Modifier pour ajouter
type PaymentProcessor struct{}

func (p *PaymentProcessor) Process(paymentType string) error {
	switch paymentType {
	case "card":
		// ... card logic
	case "paypal":
		// ... paypal logic
	// Ajouter ici = modifier
	default:
		return errors.New("unknown payment type")
	}
	return nil
}
```

**Solution :**

```go
// ✅ Bon - Étendre sans modifier
type PaymentMethod interface {
	Process() error
}

type CardPayment struct {
	CardNumber string
}

func (c *CardPayment) Process() error {
	// Card processing logic
	return nil
}

type PayPalPayment struct {
	Email string
}

func (p *PayPalPayment) Process() error {
	// PayPal processing logic
	return nil
}

// Ajouter = nouvelle struct implémentant PaymentMethod
type CryptoPayment struct {
	WalletAddress string
}

func (c *CryptoPayment) Process() error {
	// Crypto processing logic
	return nil
}

// Usage
type PaymentProcessor struct{}

func (p *PaymentProcessor) ProcessPayment(method PaymentMethod) error {
	return method.Process()
}
```

**Quand l'appliquer :** Quand le code change souvent pour ajouter des variantes.

---

### L - Liskov Substitution Principle (LSP)

> Les sous-types doivent être substituables à leurs types de base.

**Problème :**

```go
// ❌ Mauvais - Carré n'est pas un Rectangle
type Rectangle struct {
	width  float64
	height float64
}

func (r *Rectangle) SetWidth(w float64)  { r.width = w }
func (r *Rectangle) SetHeight(h float64) { r.height = h }
func (r *Rectangle) Area() float64       { return r.width * r.height }

type Square struct {
	Rectangle
}

func (s *Square) SetWidth(w float64) {
	s.width = w
	s.height = w // Viole LSP - comportement inattendu
}

func (s *Square) SetHeight(h float64) {
	s.width = h
	s.height = h // Viole LSP - comportement inattendu
}
```

**Solution :**

```go
// ✅ Bon - Abstraction commune
type Shape interface {
	Area() float64
}

type Rectangle struct {
	width  float64
	height float64
}

func NewRectangle(width, height float64) *Rectangle {
	return &Rectangle{width: width, height: height}
}

func (r *Rectangle) Area() float64 {
	return r.width * r.height
}

type Square struct {
	side float64
}

func NewSquare(side float64) *Square {
	return &Square{side: side}
}

func (s *Square) Area() float64 {
	return s.side * s.side
}

// Usage - les deux sont substituables
func PrintArea(s Shape) {
	fmt.Printf("Area: %.2f\n", s.Area())
}
```

**Quand l'appliquer :** Avant chaque héritage/composition, vérifier la substitution.

---

### I - Interface Segregation Principle (ISP)

> Plusieurs interfaces spécifiques valent mieux qu'une interface générale.

**Problème :**

```go
// ❌ Mauvais - Interface trop large
type Worker interface {
	Work()
	Eat()
	Sleep()
}

type Robot struct{}

func (r *Robot) Work() {
	// OK
}

func (r *Robot) Eat() {
	// Robots don't eat - méthode forcée
	panic("robots don't eat")
}

func (r *Robot) Sleep() {
	// Robots don't sleep - méthode forcée
	panic("robots don't sleep")
}
```

**Solution :**

```go
// ✅ Bon - Interfaces spécifiques
type Workable interface {
	Work()
}

type Eatable interface {
	Eat()
}

type Sleepable interface {
	Sleep()
}

type Robot struct{}

func (r *Robot) Work() {
	// OK - Robot implémente seulement Workable
}

type Human struct{}

func (h *Human) Work()  { /* ... */ }
func (h *Human) Eat()   { /* ... */ }
func (h *Human) Sleep() { /* ... */ }

// Usage
func DoWork(w Workable) {
	w.Work()
}

func TakeCareOf(e Eatable, s Sleepable) {
	e.Eat()
	s.Sleep()
}
```

**Quand l'appliquer :** Quand des implémenteurs doivent laisser des méthodes vides ou panic.

---

### D - Dependency Inversion Principle (DIP)

> Dépendre d'abstractions, pas d'implémentations concrètes.

**Problème :**

```go
// ❌ Mauvais - Dépendance concrète
type MySQLDatabase struct{}

func (db *MySQLDatabase) Query(sql string) ([]byte, error) {
	// MySQL-specific query
	return nil, nil
}

type UserService struct {
	db *MySQLDatabase // Couplage fort à MySQL
}

func NewUserService() *UserService {
	return &UserService{
		db: &MySQLDatabase{}, // Dépendance hard-codée
	}
}

func (s *UserService) GetUser(id string) (*User, error) {
	data, err := s.db.Query(fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", id))
	if err != nil {
		return nil, err
	}
	// ... parse data
	return nil, nil
}
```

**Solution :**

```go
// ✅ Bon - Dépendance sur abstraction
type Database interface {
	Query(ctx context.Context, sql string, args ...interface{}) ([]byte, error)
}

type MySQLDatabase struct{}

func (db *MySQLDatabase) Query(ctx context.Context, sql string, args ...interface{}) ([]byte, error) {
	// MySQL-specific implementation
	return nil, nil
}

type PostgresDatabase struct{}

func (db *PostgresDatabase) Query(ctx context.Context, sql string, args ...interface{}) ([]byte, error) {
	// Postgres-specific implementation
	return nil, nil
}

type UserService struct {
	db Database // Dépend de l'abstraction
}

func NewUserService(db Database) *UserService {
	return &UserService{db: db} // Injection de dépendance
}

func (s *UserService) GetUser(ctx context.Context, id string) (*User, error) {
	data, err := s.db.Query(ctx, "SELECT * FROM users WHERE id = $1", id)
	if err != nil {
		return nil, fmt.Errorf("querying user: %w", err)
	}
	// ... parse data
	return nil, nil
}

// Usage
func main() {
	// Facilement interchangeable
	mysqlDB := &MySQLDatabase{}
	service1 := NewUserService(mysqlDB)
	
	postgresDB := &PostgresDatabase{}
	service2 := NewUserService(postgresDB)
	
	_, _ = service1, service2
}
```

**Quand l'appliquer :** Pour tout ce qui est externe (DB, API, filesystem).

---

## Résumé Visuel

```
┌─────────────────────────────────────────────────────────────┐
│  S  │ Une struct/package = Une responsabilité               │
├─────────────────────────────────────────────────────────────┤
│  O  │ Ajouter du code, pas modifier                         │
├─────────────────────────────────────────────────────────────┤
│  L  │ Sous-type = comportement parent préservé              │
├─────────────────────────────────────────────────────────────┤
│  I  │ Interfaces petites et spécifiques                     │
├─────────────────────────────────────────────────────────────┤
│  D  │ Dépendre d'interfaces, pas de structs                 │
└─────────────────────────────────────────────────────────────┘
```

## Patterns liés

- **Factory** : Respecte OCP pour la création
- **Strategy** : Respecte OCP pour les algorithmes
- **Adapter** : Aide à respecter DIP
- **Facade** : Aide à respecter ISP

## Sources

- [Robert C. Martin - Clean Architecture](https://blog.cleancoder.com/)
- [SOLID Principles - Wikipedia](https://en.wikipedia.org/wiki/SOLID)
