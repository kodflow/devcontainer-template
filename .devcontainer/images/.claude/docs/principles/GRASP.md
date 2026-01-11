# GRASP Patterns

General Responsibility Assignment Software Patterns - Craig Larman.

9 patterns fondamentaux pour l'attribution des responsabilités en OOP.

---

## 1. Information Expert

> Assigner la responsabilité à la classe qui a l'information nécessaire.

```go
// ❌ MAUVAIS - Logic ailleurs que les données
type OrderService struct{}

func (s *OrderService) CalculateTotal(order *Order) float64 {
	total := 0.0
	for _, item := range order.Items {
		total += item.Price * float64(item.Quantity)
	}
	return total
}

// ✅ BON - Order a les données, Order calcule
type Order struct {
	Items []*OrderItem
}

// Total calculates the order total.
func (o *Order) Total() float64 {
	total := 0.0
	for _, item := range o.Items {
		total += item.Subtotal()
	}
	return total
}

type OrderItem struct {
	Price    float64
	Quantity int
}

// Subtotal calculates the item subtotal.
func (i *OrderItem) Subtotal() float64 {
	return i.Price * float64(i.Quantity)
}
```

**Règle :** Qui a les données, fait le calcul.

---

## 2. Creator

> Assigner la responsabilité de créer un objet à la classe qui :
>
> - Contient ou agrège l'objet
> - Enregistre l'objet
> - Utilise étroitement l'objet
> - A les données d'initialisation

```go
// ❌ MAUVAIS - Factory externe sans raison
type OrderItemFactory struct{}

func (f *OrderItemFactory) Create(product *Product, qty int) *OrderItem {
	return &OrderItem{
		ProductID: product.ID,
		Price:     product.Price,
		Quantity:  qty,
	}
}

// ✅ BON - Order crée ses OrderItems (il les contient)
type Order struct {
	Items []*OrderItem
}

// AddItem creates and adds an OrderItem to the order.
func (o *Order) AddItem(product *Product, quantity int) {
	// Order crée OrderItem car il les agrège
	item := &OrderItem{
		ProductID: product.ID,
		Price:     product.Price,
		Quantity:  quantity,
	}
	o.Items = append(o.Items, item)
}

// ✅ AUSSI BON - Factory method quand création complexe
func NewOrder(customer *Customer, cartItems []*CartItem) (*Order, error) {
	// Order se crée lui-même avec logique complexe
	order := &Order{
		CustomerID: customer.ID,
		Items:      make([]*OrderItem, 0, len(cartItems)),
	}
	
	for _, cartItem := range cartItems {
		order.AddItem(cartItem.Product, cartItem.Quantity)
	}
	
	return order, nil
}
```

---

## 3. Controller

> Premier objet après l'UI qui reçoit et coordonne les opérations système.

```go
// Façade Controller - Un controller par use case
type PlaceOrderController struct {
	orderService        *OrderService
	paymentService      *PaymentService
	notificationService *NotificationService
}

func NewPlaceOrderController(
	orderService *OrderService,
	paymentService *PaymentService,
	notificationService *NotificationService,
) *PlaceOrderController {
	return &PlaceOrderController{
		orderService:        orderService,
		paymentService:      paymentService,
		notificationService: notificationService,
	}
}

// Execute coordinates the place order use case.
func (c *PlaceOrderController) Execute(ctx context.Context, req *PlaceOrderRequest) (*PlaceOrderResponse, error) {
	// Coordonne mais ne contient pas de logique métier
	order, err := c.orderService.Create(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("creating order: %w", err)
	}
	
	if err := c.paymentService.Charge(ctx, order); err != nil {
		return nil, fmt.Errorf("charging payment: %w", err)
	}
	
	if err := c.notificationService.SendConfirmation(ctx, order); err != nil {
		// Log but don't fail
		fmt.Printf("failed to send confirmation: %v\n", err)
	}
	
	return &PlaceOrderResponse{OrderID: order.ID}, nil
}

// Use Case Controller - Un controller par agrégat
type OrderController struct {
	service *OrderService
}

func (c *OrderController) Place(ctx context.Context, req *http.Request) (*http.Response, error) {
	// ... place order logic
	return nil, nil
}

func (c *OrderController) Cancel(ctx context.Context, req *http.Request) (*http.Response, error) {
	// ... cancel order logic
	return nil, nil
}

func (c *OrderController) Update(ctx context.Context, req *http.Request) (*http.Response, error) {
	// ... update order logic
	return nil, nil
}
```

**Règle :** Le controller coordonne, il ne fait pas le travail.

---

## 4. Low Coupling

> Minimiser les dépendances entre classes.

```go
// ❌ MAUVAIS - Couplage fort
type OrderService struct {
	db     *PostgresDatabase  // Couplé à Postgres
	mailer *SendGridMailer    // Couplé à SendGrid
	logger *WinstonLogger     // Couplé à Winston
}

// ✅ BON - Couplage faible via interfaces
type Database interface {
	Query(ctx context.Context, sql string, args ...interface{}) (*sql.Rows, error)
}

type Mailer interface {
	Send(ctx context.Context, to, subject, body string) error
}

type Logger interface {
	Log(message string)
	Error(message string)
}

type OrderService struct {
	db     Database  // Couplé à l'interface, pas l'implémentation
	mailer Mailer
	logger Logger
}

func NewOrderService(db Database, mailer Mailer, logger Logger) *OrderService {
	return &OrderService{
		db:     db,
		mailer: mailer,
		logger: logger,
	}
}
```

**Métriques :**

- Nombre d'imports
- Profondeur des dépendances
- Fan-out (classes utilisées)

---

## 5. High Cohesion

> Une classe fait une chose bien, tous ses membres sont liés.

```go
// ❌ MAUVAIS - Faible cohésion (fait trop de choses)
type UserManager struct {
	db *sql.DB
}

func (m *UserManager) CreateUser(user *User) error        { /* ... */ }
func (m *UserManager) DeleteUser(id string) error         { /* ... */ }
func (m *UserManager) SendEmail(to, subject string) error { /* ... */ }      // Pas lié aux users
func (m *UserManager) GenerateReport() ([]byte, error)    { /* ... */ }  // Pas lié aux users
func (m *UserManager) BackupDatabase() error              { /* ... */ }  // Vraiment pas lié

// ✅ BON - Haute cohésion (une responsabilité)
type UserRepository struct {
	db *sql.DB
}

func (r *UserRepository) Create(ctx context.Context, user *User) error {
	// ...
	return nil
}

func (r *UserRepository) Delete(ctx context.Context, id string) error {
	// ...
	return nil
}

func (r *UserRepository) Find(ctx context.Context, id string) (*User, error) {
	// ...
	return nil, nil
}

func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	// ...
	return nil, nil
}

type EmailService struct {
	mailer Mailer
}

func (s *EmailService) Send(ctx context.Context, to, subject, body string) error {
	return s.mailer.Send(ctx, to, subject, body)
}

func (s *EmailService) SendTemplate(ctx context.Context, to, template string, data map[string]interface{}) error {
	// ...
	return nil
}

type ReportGenerator struct{}

func (g *ReportGenerator) Generate(reportType string, data interface{}) ([]byte, error) {
	// ...
	return nil, nil
}
```

**Test :** Peux-tu décrire la classe en une phrase sans "et" ?

---

## 6. Polymorphism

> Utiliser le polymorphisme plutôt que les conditions sur le type.

```go
// ❌ MAUVAIS - Switch sur le type
type PaymentProcessor struct{}

func (p *PaymentProcessor) Process(payment *Payment) error {
	switch payment.Type {
	case "credit_card":
		return p.processCreditCard(payment)
	case "paypal":
		return p.processPaypal(payment)
	case "crypto":
		return p.processCrypto(payment)
	default:
		return errors.New("unknown payment type")
	}
}

// ✅ BON - Polymorphisme
type PaymentMethod interface {
	Process(ctx context.Context, amount float64) (*PaymentResult, error)
}

type CreditCardPayment struct {
	CardNumber string
	CVV        string
}

func (c *CreditCardPayment) Process(ctx context.Context, amount float64) (*PaymentResult, error) {
	// Logique carte de crédit
	return &PaymentResult{Success: true}, nil
}

type PaypalPayment struct {
	Email string
}

func (p *PaypalPayment) Process(ctx context.Context, amount float64) (*PaymentResult, error) {
	// Logique PayPal
	return &PaymentResult{Success: true}, nil
}

type CryptoPayment struct {
	WalletAddress string
}

func (c *CryptoPayment) Process(ctx context.Context, amount float64) (*PaymentResult, error) {
	// Logique crypto
	return &PaymentResult{Success: true}, nil
}

// Usage - pas de switch
type PaymentProcessor struct{}

func (p *PaymentProcessor) ProcessPayment(ctx context.Context, method PaymentMethod, amount float64) (*PaymentResult, error) {
	return method.Process(ctx, amount)
}
```

---

## 7. Pure Fabrication

> Créer une classe artificielle pour maintenir cohésion et couplage.

```go
// Problème: où mettre la persistence des Orders?
// - Order? Non, violerait cohésion (logique métier + DB)
// - Database? Non, trop générique

// ✅ Pure Fabrication - Struct artificielle
type OrderRepository struct {
	db Database
}

func NewOrderRepository(db Database) *OrderRepository {
	return &OrderRepository{db: db}
}

// Save persists an order to the database.
func (r *OrderRepository) Save(ctx context.Context, order *Order) error {
	row := r.toRow(order)
	_, err := r.db.Query(ctx, "INSERT INTO orders (id, customer_id, total) VALUES ($1, $2, $3)",
		row["id"], row["customer_id"], row["total"])
	return err
}

// FindByID retrieves an order by ID.
func (r *OrderRepository) FindByID(ctx context.Context, id string) (*Order, error) {
	rows, err := r.db.Query(ctx, "SELECT id, customer_id, total FROM orders WHERE id = $1", id)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	
	if !rows.Next() {
		return nil, nil
	}
	
	return r.toDomain(rows)
}

func (r *OrderRepository) toRow(order *Order) map[string]interface{} {
	return map[string]interface{}{
		"id":          order.ID,
		"customer_id": order.CustomerID,
		"total":       order.Total(),
	}
}

func (r *OrderRepository) toDomain(rows *sql.Rows) (*Order, error) {
	var order Order
	err := rows.Scan(&order.ID, &order.CustomerID)
	return &order, err
}

// Autres Pure Fabrications communes:
// - Services (OrderService, PaymentService)
// - Factories (OrderFactory)
// - Strategies (PricingStrategy)
// - Adapters (EmailAdapter)
```

**Règle :** Si aucune struct existante ne convient, en créer une.

---

## 8. Indirection

> Ajouter un intermédiaire pour découpler.

```go
// ❌ Couplage direct
type TaxJarAPI struct{}

func (api *TaxJarAPI) Calculate(amount float64, state string) (float64, error) {
	// TaxJar-specific API call
	return 0, nil
}

type OrderService struct {
	taxApi *TaxJarAPI // Couplé à TaxJar
}

func (s *OrderService) CalculateTax(order *Order) (float64, error) {
	return s.taxApi.Calculate(order.Total(), order.State)
}

// ✅ Indirection via interface
type TaxCalculator interface {
	Calculate(ctx context.Context, amount float64, state string) (float64, error)
}

type TaxJarAdapter struct {
	api *TaxJarAPI
}

func (a *TaxJarAdapter) Calculate(ctx context.Context, amount float64, state string) (float64, error) {
	return a.api.Calculate(amount, state)
}

type OrderService struct {
	taxCalculator TaxCalculator // Découplé
}

func NewOrderService(taxCalculator TaxCalculator) *OrderService {
	return &OrderService{taxCalculator: taxCalculator}
}

func (s *OrderService) CalculateTax(ctx context.Context, order *Order) (float64, error) {
	return s.taxCalculator.Calculate(ctx, order.Total(), order.State)
}
```

**Formes d'indirection :**

- Adapter
- Facade
- Proxy
- Mediator

---

## 9. Protected Variations

> Protéger les éléments des variations d'autres éléments.

```go
// Le problème: le code qui utilise PaymentGateway
// ne devrait pas être affecté si on ajoute un nouveau type de paiement

// ✅ Protected Variations via interface stable
type PaymentGateway interface {
	Charge(ctx context.Context, amount float64, method PaymentMethod) (*Transaction, error)
	Refund(ctx context.Context, transactionID string) error
}

// Les variations sont encapsulées dans les implémentations
type StripeGateway struct {
	apiKey string
}

func (g *StripeGateway) Charge(ctx context.Context, amount float64, method PaymentMethod) (*Transaction, error) {
	// Stripe-specific implementation
	return &Transaction{ID: "stripe-123"}, nil
}

func (g *StripeGateway) Refund(ctx context.Context, transactionID string) error {
	// Stripe-specific implementation
	return nil
}

type PayPalGateway struct {
	clientID string
}

func (g *PayPalGateway) Charge(ctx context.Context, amount float64, method PaymentMethod) (*Transaction, error) {
	// PayPal-specific implementation
	return &Transaction{ID: "paypal-456"}, nil
}

func (g *PayPalGateway) Refund(ctx context.Context, transactionID string) error {
	// PayPal-specific implementation
	return nil
}

// Le code client est protégé des variations
type CheckoutService struct {
	gateway PaymentGateway
}

func NewCheckoutService(gateway PaymentGateway) *CheckoutService {
	return &CheckoutService{gateway: gateway}
}

func (s *CheckoutService) Checkout(ctx context.Context, cart *Cart) (*Transaction, error) {
	// Ne sait pas et ne se soucie pas de l'implémentation
	transaction, err := s.gateway.Charge(ctx, cart.Total, cart.PaymentMethod)
	if err != nil {
		return nil, fmt.Errorf("charging payment: %w", err)
	}
	return transaction, nil
}
```

**Points de variation protégés :**

```go
// 1. Data source variations
type Repository[T any] interface {
	Find(ctx context.Context, id string) (*T, error)
	Save(ctx context.Context, entity *T) error
}
// Implémentations: PostgresRepository, MongoRepository, InMemoryRepository

// 2. External service variations
type NotificationService interface {
	Send(ctx context.Context, notification *Notification) error
}
// Implémentations: EmailNotification, SMSNotification, PushNotification

// 3. Algorithm variations
type PricingStrategy interface {
	Calculate(basePrice float64, context *PricingContext) float64
}
// Implémentations: RegularPricing, DiscountPricing, MemberPricing

// 4. Platform variations
type FileStorage interface {
	Upload(ctx context.Context, file []byte, path string) (string, error)
	Download(ctx context.Context, path string) ([]byte, error)
}
// Implémentations: LocalStorage, S3Storage, GCSStorage
```

**Techniques :**

- Interfaces
- Dependency Injection
- Configuration externe
- Plugins / Extensions

---

## Tableau récapitulatif

| Pattern | Question | Réponse |
|---------|----------|---------|
| Information Expert | Qui doit faire X ? | Celui qui a les données |
| Creator | Qui doit créer X ? | Celui qui contient/utilise X |
| Controller | Qui reçoit les requêtes ? | Un coordinateur dédié |
| Low Coupling | Comment réduire les dépendances ? | Interfaces, DI |
| High Cohesion | Comment garder focus ? | Une responsabilité par struct |
| Polymorphism | Comment éviter les switch sur type ? | Interfaces + implémentations |
| Pure Fabrication | Où mettre la logique orpheline ? | Créer une struct dédiée |
| Indirection | Comment découpler A de B ? | Ajouter un intermédiaire |
| Protected Variations | Comment isoler des changements ? | Interfaces stables |

## Relations avec autres patterns

| GRASP | GoF équivalent |
|-------|----------------|
| Polymorphism | Strategy, State |
| Pure Fabrication | Service, Repository |
| Indirection | Adapter, Facade, Proxy |
| Protected Variations | Abstract Factory, Bridge |

## Quand utiliser

- Lors de la conception de classes et de l'attribution des responsabilites
- Quand on hesite sur "ou placer cette methode ou ce comportement"
- Pour evaluer la qualite d'une architecture orientee objet
- Lors de refactoring pour ameliorer la cohesion et reduire le couplage
- Avant de creer une nouvelle classe ou interface

## Patterns liés

- [SOLID](./SOLID.md) - Complementaire pour les principes OOP
- [DRY](./DRY.md) - Pure Fabrication aide a centraliser la logique
- [Defensive Programming](./defensive.md) - Controller coordonne les validations

## Sources

- [GRASP - Craig Larman](https://en.wikipedia.org/wiki/GRASP_(object-oriented_design))
- [Applying UML and Patterns](https://www.amazon.com/Applying-UML-Patterns-Introduction-Object-Oriented/dp/0131489062)
