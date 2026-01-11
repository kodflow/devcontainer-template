# GRASP Patterns

General Responsibility Assignment Software Patterns - Craig Larman.

9 patterns fondamentaux pour l'attribution des responsabilités en OOP.

---

## 1. Information Expert

> Assigner la responsabilité à la classe qui a l'information nécessaire.

```typescript
// ❌ MAUVAIS - Logic ailleurs que les données
class OrderService {
  calculateTotal(order: Order): number {
    let total = 0;
    for (const item of order.items) {
      total += item.price * item.quantity;
    }
    return total;
  }
}

// ✅ BON - Order a les données, Order calcule
class Order {
  private items: OrderItem[] = [];

  get total(): number {
    return this.items.reduce(
      (sum, item) => sum + item.subtotal,
      0
    );
  }
}

class OrderItem {
  constructor(
    private price: number,
    private quantity: number,
  ) {}

  get subtotal(): number {
    return this.price * this.quantity;
  }
}
```

**Règle :** Qui a les données, fait le calcul.

---

## 2. Creator

> Assigner la responsabilité de créer un objet à la classe qui :
> - Contient ou agrège l'objet
> - Enregistre l'objet
> - Utilise étroitement l'objet
> - A les données d'initialisation

```typescript
// ❌ MAUVAIS - Factory externe sans raison
class OrderItemFactory {
  create(product: Product, qty: number): OrderItem {
    return new OrderItem(product, qty);
  }
}

// ✅ BON - Order crée ses OrderItems (il les contient)
class Order {
  private items: OrderItem[] = [];

  addItem(product: Product, quantity: number): void {
    // Order crée OrderItem car il les agrège
    const item = new OrderItem(product, quantity);
    this.items.push(item);
  }
}

// ✅ AUSSI BON - Factory quand création complexe
class Order {
  static create(customer: Customer, items: CartItem[]): Order {
    // Order se crée lui-même avec logique complexe
    const order = new Order(customer);
    for (const cartItem of items) {
      order.addItem(cartItem.product, cartItem.quantity);
    }
    return order;
  }
}
```

---

## 3. Controller

> Premier objet après l'UI qui reçoit et coordonne les opérations système.

```typescript
// Façade Controller - Un controller par use case
class PlaceOrderController {
  constructor(
    private orderService: OrderService,
    private paymentService: PaymentService,
    private notificationService: NotificationService,
  ) {}

  async execute(request: PlaceOrderRequest): Promise<PlaceOrderResponse> {
    // Coordonne mais ne contient pas de logique métier
    const order = await this.orderService.create(request);
    await this.paymentService.charge(order);
    await this.notificationService.sendConfirmation(order);
    return { orderId: order.id };
  }
}

// Use Case Controller - Un controller par agrégat
class OrderController {
  async place(req: Request): Promise<Response> { /* ... */ }
  async cancel(req: Request): Promise<Response> { /* ... */ }
  async update(req: Request): Promise<Response> { /* ... */ }
}
```

**Règle :** Le controller coordonne, il ne fait pas le travail.

---

## 4. Low Coupling

> Minimiser les dépendances entre classes.

```typescript
// ❌ MAUVAIS - Couplage fort
class OrderService {
  private db = new PostgresDatabase();      // Couplé à Postgres
  private mailer = new SendGridMailer();    // Couplé à SendGrid
  private logger = new WinstonLogger();     // Couplé à Winston
}

// ✅ BON - Couplage faible via interfaces
interface Database {
  query(sql: string): Promise<any>;
}

interface Mailer {
  send(to: string, subject: string, body: string): Promise<void>;
}

interface Logger {
  log(message: string): void;
}

class OrderService {
  constructor(
    private db: Database,        // Couplé à l'interface, pas l'implémentation
    private mailer: Mailer,
    private logger: Logger,
  ) {}
}
```

**Métriques :**
- Nombre d'imports
- Profondeur des dépendances
- Fan-out (classes utilisées)

---

## 5. High Cohesion

> Une classe fait une chose bien, tous ses membres sont liés.

```typescript
// ❌ MAUVAIS - Faible cohésion (fait trop de choses)
class UserManager {
  createUser() { /* ... */ }
  deleteUser() { /* ... */ }
  sendEmail() { /* ... */ }      // Pas lié aux users
  generateReport() { /* ... */ }  // Pas lié aux users
  backupDatabase() { /* ... */ }  // Vraiment pas lié
}

// ✅ BON - Haute cohésion (une responsabilité)
class UserRepository {
  create(user: User) { /* ... */ }
  delete(id: string) { /* ... */ }
  find(id: string) { /* ... */ }
  findByEmail(email: string) { /* ... */ }
}

class EmailService {
  send(to: string, subject: string, body: string) { /* ... */ }
  sendTemplate(to: string, template: string, data: object) { /* ... */ }
}

class ReportGenerator {
  generate(type: ReportType, data: ReportData) { /* ... */ }
}
```

**Test :** Peux-tu décrire la classe en une phrase sans "et" ?

---

## 6. Polymorphism

> Utiliser le polymorphisme plutôt que les conditions sur le type.

```typescript
// ❌ MAUVAIS - Switch sur le type
class PaymentProcessor {
  process(payment: Payment) {
    switch (payment.type) {
      case 'credit_card':
        return this.processCreditCard(payment);
      case 'paypal':
        return this.processPaypal(payment);
      case 'crypto':
        return this.processCrypto(payment);
      default:
        throw new Error('Unknown payment type');
    }
  }
}

// ✅ BON - Polymorphisme
interface PaymentMethod {
  process(amount: Money): Promise<PaymentResult>;
}

class CreditCardPayment implements PaymentMethod {
  async process(amount: Money) {
    // Logique carte de crédit
  }
}

class PaypalPayment implements PaymentMethod {
  async process(amount: Money) {
    // Logique PayPal
  }
}

class CryptoPayment implements PaymentMethod {
  async process(amount: Money) {
    // Logique crypto
  }
}

// Usage - pas de switch
class PaymentProcessor {
  async process(method: PaymentMethod, amount: Money) {
    return method.process(amount);
  }
}
```

---

## 7. Pure Fabrication

> Créer une classe artificielle pour maintenir cohésion et couplage.

```typescript
// Problème: où mettre la persistence des Orders?
// - Order? Non, violerait cohésion (logique métier + DB)
// - Database? Non, trop générique

// ✅ Pure Fabrication - Classe artificielle
class OrderRepository {
  constructor(private db: Database) {}

  async save(order: Order): Promise<void> {
    await this.db.query(
      'INSERT INTO orders ...',
      this.toRow(order)
    );
  }

  async findById(id: OrderId): Promise<Order | null> {
    const row = await this.db.query('SELECT * FROM orders WHERE id = ?', [id]);
    return row ? this.toDomain(row) : null;
  }

  private toRow(order: Order) { /* mapping */ }
  private toDomain(row: any): Order { /* mapping */ }
}

// Autres Pure Fabrications communes:
// - Services (OrderService, PaymentService)
// - Factories (OrderFactory)
// - Strategies (PricingStrategy)
// - Adapters (EmailAdapter)
```

**Règle :** Si aucune classe existante ne convient, en créer une.

---

## 8. Indirection

> Ajouter un intermédiaire pour découpler.

```typescript
// ❌ Couplage direct
class OrderService {
  constructor(private taxApi: TaxJarAPI) {}  // Couplé à TaxJar

  calculateTax(order: Order) {
    return this.taxApi.calculate(order.total, order.state);
  }
}

// ✅ Indirection via interface
interface TaxCalculator {
  calculate(amount: number, state: string): Promise<number>;
}

class TaxJarAdapter implements TaxCalculator {
  constructor(private api: TaxJarAPI) {}

  async calculate(amount: number, state: string): Promise<number> {
    return this.api.calculate(amount, state);
  }
}

class OrderService {
  constructor(private taxCalculator: TaxCalculator) {}

  async calculateTax(order: Order) {
    return this.taxCalculator.calculate(order.total, order.state);
  }
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

```typescript
// Le problème: le code qui utilise PaymentProcessor
// ne devrait pas être affecté si on ajoute un nouveau type de paiement

// ✅ Protected Variations via interface stable
interface PaymentGateway {
  charge(amount: Money, method: PaymentMethod): Promise<Transaction>;
  refund(transactionId: string): Promise<void>;
}

// Les variations sont encapsulées dans les implémentations
class StripeGateway implements PaymentGateway {
  async charge(amount: Money, method: PaymentMethod) {
    // Stripe-specific implementation
  }
  async refund(transactionId: string) {
    // Stripe-specific implementation
  }
}

class PayPalGateway implements PaymentGateway {
  async charge(amount: Money, method: PaymentMethod) {
    // PayPal-specific implementation
  }
  async refund(transactionId: string) {
    // PayPal-specific implementation
  }
}

// Le code client est protégé des variations
class CheckoutService {
  constructor(private gateway: PaymentGateway) {}

  async checkout(cart: Cart) {
    // Ne sait pas et ne se soucie pas de l'implémentation
    const transaction = await this.gateway.charge(cart.total, cart.paymentMethod);
    return transaction;
  }
}
```

**Points de variation protégés :**
```typescript
// 1. Data source variations
interface Repository<T> {
  find(id: string): Promise<T | null>;
  save(entity: T): Promise<void>;
}
// Implémentations: PostgresRepository, MongoRepository, InMemoryRepository

// 2. External service variations
interface NotificationService {
  send(notification: Notification): Promise<void>;
}
// Implémentations: EmailNotification, SMSNotification, PushNotification

// 3. Algorithm variations
interface PricingStrategy {
  calculate(basePrice: Money, context: PricingContext): Money;
}
// Implémentations: RegularPricing, DiscountPricing, MemberPricing

// 4. Platform variations
interface FileStorage {
  upload(file: Buffer, path: string): Promise<string>;
  download(path: string): Promise<Buffer>;
}
// Implémentations: LocalStorage, S3Storage, GCSStorage
```

**Techniques :**
- Interfaces / Abstract classes
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
| High Cohesion | Comment garder focus ? | Une responsabilité par classe |
| Polymorphism | Comment éviter les switch sur type ? | Interfaces + implémentations |
| Pure Fabrication | Où mettre la logique orpheline ? | Créer une classe dédiée |
| Indirection | Comment découpler A de B ? | Ajouter un intermédiaire |
| Protected Variations | Comment isoler des changements ? | Interfaces stables |

## Relations avec autres patterns

| GRASP | GoF équivalent |
|-------|----------------|
| Polymorphism | Strategy, State |
| Pure Fabrication | Service, Repository |
| Indirection | Adapter, Facade, Proxy |
| Protected Variations | Abstract Factory, Bridge |

## Sources

- [GRASP - Craig Larman](https://en.wikipedia.org/wiki/GRASP_(object-oriented_design))
- [Applying UML and Patterns](https://www.amazon.com/Applying-UML-Patterns-Introduction-Object-Oriented/dp/0131489062)
