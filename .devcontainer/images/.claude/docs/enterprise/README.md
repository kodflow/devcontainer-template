# Enterprise Patterns (PoEAA)

Patterns de Martin Fowler - Patterns of Enterprise Application Architecture.

## Domain Logic Patterns

### 1. Transaction Script

> Procédure qui gère une transaction métier complète.

```go
class OrderService {
  async placeOrder(customerId: string, items: OrderItem[]) {
    // Tout le logic dans une procédure
    const customer = await this.customerRepo.find(customerId);
    if (!customer) throw new Error('Customer not found');

    const order = new Order(customer);
    for (const item of items) {
      const product = await this.productRepo.find(item.productId);
      if (product.stock < item.quantity) {
        throw new Error('Insufficient stock');
      }
      order.addItem(product, item.quantity);
      product.stock -= item.quantity;
      await this.productRepo.save(product);
    }

    await this.orderRepo.save(order);
    await this.emailService.sendConfirmation(customer, order);
    return order;
  }
}
```

**Quand :** Logique simple, CRUD, applications petites.
**Lié à :** Service Layer.

---

### 2. Domain Model

> Objets métier avec comportements et règles.

```go
class Order {
  private items: OrderItem[] = [];
  private status: OrderStatus = 'draft';

  addItem(product: Product, quantity: number) {
    if (this.status !== 'draft') {
      throw new Error('Cannot modify non-draft order');
    }
    const existing = this.items.find((i) => i.product.id === product.id);
    if (existing) {
      existing.quantity += quantity;
    } else {
      this.items.push(new OrderItem(product, quantity));
    }
  }

  submit() {
    if (this.items.length === 0) {
      throw new Error('Cannot submit empty order');
    }
    this.status = 'submitted';
  }

  get total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.subtotal),
      Money.zero(),
    );
  }
}
```

**Quand :** Logique métier complexe, règles, validations.
**Lié à :** DDD, Rich Domain Model.

---

### 3. Table Module

> Une classe par table avec méthodes.

```go
class ProductTable {
  constructor(private db: Database) {}

  async findById(id: string): Promise<ProductRow> {
    return this.db.query('SELECT * FROM products WHERE id = ?', [id]);
  }

  async findByCategory(category: string): Promise<ProductRow[]> {
    return this.db.query('SELECT * FROM products WHERE category = ?', [category]);
  }

  async updatePrice(id: string, price: number) {
    return this.db.execute('UPDATE products SET price = ? WHERE id = ?', [price, id]);
  }

  async calculateTotalValue(): Promise<number> {
    const result = await this.db.query('SELECT SUM(price * stock) FROM products');
    return result[0].sum;
  }
}
```

**Quand :** .NET DataTable style, logique modérée.
**Lié à :** Table Data Gateway.

---

### 4. Service Layer

> Couche de coordination des opérations métier.

```go
class OrderApplicationService {
  constructor(
    private orderRepo: OrderRepository,
    private inventoryService: InventoryService,
    private paymentService: PaymentService,
    private notificationService: NotificationService,
  ) {}

  @Transactional()
  async placeOrder(dto: PlaceOrderDTO): Promise<OrderDTO> {
    // Coordonne mais ne contient pas de logique métier
    const order = Order.create(dto.customerId, dto.items);

    await this.inventoryService.reserve(order.items);

    try {
      await this.paymentService.charge(order.customerId, order.total);
    } catch (e) {
      await this.inventoryService.release(order.items);
      throw e;
    }

    await this.orderRepo.save(order);
    await this.notificationService.notifyOrderPlaced(order);

    return OrderDTO.from(order);
  }
}
```

**Quand :** Coordination, transactions, façade métier.
**Lié à :** Facade, Domain Model.

---

## Data Source Patterns

### 5. Table Data Gateway

> Une classe par table pour CRUD.

```go
class ProductGateway {
  constructor(private db: Database) {}

  async find(id: string): Promise<ProductRow | null> {
    const rows = await this.db.query('SELECT * FROM products WHERE id = ?', [id]);
    return rows[0] || null;
  }

  async findAll(): Promise<ProductRow[]> {
    return this.db.query('SELECT * FROM products');
  }

  async insert(product: ProductRow): Promise<void> {
    await this.db.execute(
      'INSERT INTO products (id, name, price) VALUES (?, ?, ?)',
      [product.id, product.name, product.price],
    );
  }

  async update(product: ProductRow): Promise<void> {
    await this.db.execute(
      'UPDATE products SET name = ?, price = ? WHERE id = ?',
      [product.name, product.price, product.id],
    );
  }

  async delete(id: string): Promise<void> {
    await this.db.execute('DELETE FROM products WHERE id = ?', [id]);
  }
}
```

**Quand :** Accès simple aux données, pas d'ORM.
**Lié à :** Row Data Gateway, Data Mapper.

---

### 6. Row Data Gateway

> Un objet par ligne avec persistence.

```go
class ProductRow {
  constructor(
    private db: Database,
    public id: string,
    public name: string,
    public price: number,
  ) {}

  static async find(db: Database, id: string): Promise<ProductRow | null> {
    const rows = await db.query('SELECT * FROM products WHERE id = ?', [id]);
    if (!rows[0]) return null;
    return new ProductRow(db, rows[0].id, rows[0].name, rows[0].price);
  }

  async save(): Promise<void> {
    await this.db.execute(
      'UPDATE products SET name = ?, price = ? WHERE id = ?',
      [this.name, this.price, this.id],
    );
  }

  async delete(): Promise<void> {
    await this.db.execute('DELETE FROM products WHERE id = ?', [this.id]);
  }
}
```

**Quand :** Active Record simple, sans ORM complet.
**Lié à :** Active Record.

---

### 7. Active Record

> Objet qui encapsule ligne + logique métier + persistence.

```go
class User extends ActiveRecord {
  @Column() email: string;
  @Column() passwordHash: string;
  @Column() role: string;

  static async findByEmail(email: string): Promise<User | null> {
    return this.findOne({ email });
  }

  async setPassword(password: string) {
    this.passwordHash = await bcrypt.hash(password, 10);
  }

  async checkPassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.passwordHash);
  }

  isAdmin(): boolean {
    return this.role === 'admin';
  }
}

// Usage
const user = new User();
user.email = 'john@example.com';
await user.setPassword('secret');
await user.save();
```

**Quand :** CRUD simple avec peu de logique, Rails/Django style.
**Lié à :** Row Data Gateway, Domain Model.

---

### 8. Data Mapper

> Sépare complètement objet et persistence.

```go
// Domain object - aucune dépendance sur la DB
class Product {
  constructor(
    public readonly id: string,
    public name: string,
    public price: Money,
    private _stock: number,
  ) {}

  reduceStock(quantity: number) {
    if (quantity > this._stock) throw new Error('Insufficient stock');
    this._stock -= quantity;
  }

  get stock() { return this._stock; }
}

// Mapper - traduit entre domain et DB
class ProductMapper {
  constructor(private db: Database) {}

  async find(id: string): Promise<Product | null> {
    const row = await this.db.query('SELECT * FROM products WHERE id = ?', [id]);
    if (!row[0]) return null;
    return this.toDomain(row[0]);
  }

  async save(product: Product): Promise<void> {
    await this.db.execute(
      'UPDATE products SET name = ?, price = ?, stock = ? WHERE id = ?',
      [product.name, product.price.amount, product.stock, product.id],
    );
  }

  private toDomain(row: any): Product {
    return new Product(row.id, row.name, Money.of(row.price), row.stock);
  }
}
```

**Quand :** Domain model riche, séparation concerns, testabilité.
**Lié à :** Repository, Domain Model.

---

## Object-Relational Behavioral

### 9. Unit of Work

> Maintient la liste des objets modifiés pour une transaction.

```go
class UnitOfWork {
  private newObjects = new Set<Entity>();
  private dirtyObjects = new Set<Entity>();
  private removedObjects = new Set<Entity>();

  registerNew(entity: Entity) {
    this.newObjects.add(entity);
  }

  registerDirty(entity: Entity) {
    if (!this.newObjects.has(entity)) {
      this.dirtyObjects.add(entity);
    }
  }

  registerRemoved(entity: Entity) {
    this.newObjects.delete(entity);
    this.dirtyObjects.delete(entity);
    this.removedObjects.add(entity);
  }

  async commit() {
    await this.insertNew();
    await this.updateDirty();
    await this.deleteRemoved();
    this.clear();
  }

  private async insertNew() {
    for (const entity of this.newObjects) {
      await this.mapper(entity).insert(entity);
    }
  }

  private async updateDirty() {
    for (const entity of this.dirtyObjects) {
      await this.mapper(entity).update(entity);
    }
  }

  private async deleteRemoved() {
    for (const entity of this.removedObjects) {
      await this.mapper(entity).delete(entity);
    }
  }
}
```

**Quand :** ORM, transactions complexes, batch updates.
**Lié à :** Repository, Identity Map.

---

### 10. Identity Map

> Cache des objets chargés par identité.

```go
class IdentityMap<T extends { id: string }> {
  private map = new Map<string, T>();

  get(id: string): T | undefined {
    return this.map.get(id);
  }

  add(entity: T) {
    this.map.set(entity.id, entity);
  }

  remove(id: string) {
    this.map.delete(id);
  }

  clear() {
    this.map.clear();
  }
}

class ProductRepository {
  private identityMap = new IdentityMap<Product>();

  async find(id: string): Promise<Product | null> {
    // Check identity map first
    const cached = this.identityMap.get(id);
    if (cached) return cached;

    // Load from DB
    const product = await this.mapper.find(id);
    if (product) {
      this.identityMap.add(product);
    }
    return product;
  }
}
```

**Quand :** Éviter doublons en mémoire, cohérence.
**Lié à :** Unit of Work, Cache.

---

### 11. Lazy Load

> Charger les données à la demande.

```go
// Virtual Proxy
class LazyProduct {
  private _details: ProductDetails | null = null;

  constructor(
    public readonly id: string,
    private loader: () => Promise<ProductDetails>,
  ) {}

  async getDetails(): Promise<ProductDetails> {
    if (!this._details) {
      this._details = await this.loader();
    }
    return this._details;
  }
}

// Ghost
class Product {
  private loaded = false;
  private _name?: string;
  private _price?: Money;

  constructor(
    public readonly id: string,
    private loader: (id: string) => Promise<ProductData>,
  ) {}

  private async ensureLoaded() {
    if (!this.loaded) {
      const data = await this.loader(this.id);
      this._name = data.name;
      this._price = data.price;
      this.loaded = true;
    }
  }

  async getName(): Promise<string> {
    await this.ensureLoaded();
    return this._name!;
  }
}
```

**Variantes :** Virtual Proxy, Value Holder, Ghost.
**Quand :** Relations coûteuses, chargement partiel.
**Lié à :** Proxy, Virtual Proxy.

---

## Object-Relational Structural

### 12. Foreign Key Mapping

> Mapper les relations via foreign keys.

```go
class OrderMapper {
  async find(id: string): Promise<Order> {
    const row = await this.db.query('SELECT * FROM orders WHERE id = ?', [id]);
    const order = new Order(row.id, row.date);

    // Lazy load customer via foreign key
    order.customerId = row.customer_id;
    order.getCustomer = async () => {
      return this.customerMapper.find(row.customer_id);
    };

    return order;
  }

  async findWithCustomer(id: string): Promise<Order> {
    const row = await this.db.query(`
      SELECT o.*, c.name as customer_name, c.email as customer_email
      FROM orders o
      JOIN customers c ON o.customer_id = c.id
      WHERE o.id = ?
    `, [id]);

    const customer = new Customer(row.customer_id, row.customer_name, row.customer_email);
    const order = new Order(row.id, row.date, customer);
    return order;
  }
}
```

**Quand :** Relations 1-N, N-1.
**Lié à :** Association Table Mapping.

---

### 13. Association Table Mapping

> Table de jonction pour relations N-N.

```go
class ProductCategoryMapper {
  async findCategoriesForProduct(productId: string): Promise<Category[]> {
    const rows = await this.db.query(`
      SELECT c.* FROM categories c
      JOIN product_categories pc ON c.id = pc.category_id
      WHERE pc.product_id = ?
    `, [productId]);
    return rows.map((r) => new Category(r.id, r.name));
  }

  async addCategoryToProduct(productId: string, categoryId: string) {
    await this.db.execute(
      'INSERT INTO product_categories (product_id, category_id) VALUES (?, ?)',
      [productId, categoryId],
    );
  }

  async removeCategoryFromProduct(productId: string, categoryId: string) {
    await this.db.execute(
      'DELETE FROM product_categories WHERE product_id = ? AND category_id = ?',
      [productId, categoryId],
    );
  }
}
```

**Quand :** Relations many-to-many.
**Lié à :** Foreign Key Mapping.

---

### 14. Embedded Value

> Mapper un value object dans les colonnes de la table parente.

```go
// Value Object
class Address {
  constructor(
    public street: string,
    public city: string,
    public zipCode: string,
    public country: string,
  ) {}
}

// Entity with embedded value
class Customer {
  constructor(
    public id: string,
    public name: string,
    public address: Address,
  ) {}
}

// Mapper
class CustomerMapper {
  async find(id: string): Promise<Customer> {
    const row = await this.db.query('SELECT * FROM customers WHERE id = ?', [id]);
    return new Customer(
      row.id,
      row.name,
      new Address(row.street, row.city, row.zip_code, row.country),
    );
  }

  async save(customer: Customer) {
    await this.db.execute(`
      UPDATE customers SET
        name = ?, street = ?, city = ?, zip_code = ?, country = ?
      WHERE id = ?
    `, [
      customer.name,
      customer.address.street,
      customer.address.city,
      customer.address.zipCode,
      customer.address.country,
      customer.id,
    ]);
  }
}
```

**Quand :** Value objects sans table dédiée.
**Lié à :** Value Object, Serialized LOB.

---

### 15. Serialized LOB

> Sérialiser un graphe d'objets dans un champ.

```go
class ProductMapper {
  async find(id: string): Promise<Product> {
    const row = await this.db.query('SELECT * FROM products WHERE id = ?', [id]);
    return new Product(
      row.id,
      row.name,
      JSON.parse(row.attributes), // Serialized LOB
      JSON.parse(row.metadata),
    );
  }

  async save(product: Product) {
    await this.db.execute(`
      UPDATE products SET
        name = ?, attributes = ?, metadata = ?
      WHERE id = ?
    `, [
      product.name,
      JSON.stringify(product.attributes),
      JSON.stringify(product.metadata),
      product.id,
    ]);
  }
}
```

**Quand :** Données semi-structurées, schéma flexible.
**Lié à :** Embedded Value.

---

### 16. Inheritance Mapping

> Trois stratégies pour mapper l'héritage.

```go
// Single Table Inheritance
// Une seule table avec discriminator
// employees(id, name, type, salary, hourly_rate)
class EmployeeMapper {
  async find(id: string): Promise<Employee> {
    const row = await this.db.query('SELECT * FROM employees WHERE id = ?', [id]);
    switch (row.type) {
      case 'salaried':
        return new SalariedEmployee(row.id, row.name, row.salary);
      case 'hourly':
        return new HourlyEmployee(row.id, row.name, row.hourly_rate);
      default:
        throw new Error('Unknown type');
    }
  }
}

// Class Table Inheritance
// employees(id, name) + salaried_employees(id, salary) + hourly_employees(id, hourly_rate)
class EmployeeMapper {
  async find(id: string): Promise<Employee> {
    const base = await this.db.query('SELECT * FROM employees WHERE id = ?', [id]);
    const salaried = await this.db.query('SELECT * FROM salaried_employees WHERE id = ?', [id]);
    if (salaried[0]) {
      return new SalariedEmployee(base.id, base.name, salaried[0].salary);
    }
    const hourly = await this.db.query('SELECT * FROM hourly_employees WHERE id = ?', [id]);
    return new HourlyEmployee(base.id, base.name, hourly[0].hourly_rate);
  }
}

// Concrete Table Inheritance
// salaried_employees(id, name, salary) + hourly_employees(id, name, hourly_rate)
```

**Stratégies :**

- **Single Table** : Une table, discriminator column
- **Class Table** : Table par classe dans la hiérarchie
- **Concrete Table** : Table par classe concrète

**Quand :** Hiérarchies d'objets persistées.
**Lié à :** Polymorphism.

---

## Web Presentation

### 17. MVC (Model-View-Controller)

> Séparer données, présentation, et contrôle.

```go
// Model
class UserModel {
  constructor(
    public id: string,
    public name: string,
    public email: string,
  ) {}
}

// View
class UserView {
  render(user: UserModel): string {
    return `<div>
      <h1>${user.name}</h1>
      <p>${user.email}</p>
    </div>`;
  }
}

// Controller
class UserController {
  constructor(
    private userService: UserService,
    private view: UserView,
  ) {}

  async show(req: Request, res: Response) {
    const user = await this.userService.find(req.params.id);
    const html = this.view.render(user);
    res.send(html);
  }
}
```

**Quand :** Applications web, séparation concerns.
**Lié à :** MVP, MVVM.

---

### 18. Page Controller

> Un controller par page/action.

```go
// /users/show.ts
class ShowUserController {
  async handle(req: Request, res: Response) {
    const user = await this.userService.find(req.params.id);
    return res.render('users/show', { user });
  }
}

// /users/edit.ts
class EditUserController {
  async handle(req: Request, res: Response) {
    if (req.method === 'GET') {
      const user = await this.userService.find(req.params.id);
      return res.render('users/edit', { user });
    }
    if (req.method === 'POST') {
      await this.userService.update(req.params.id, req.body);
      return res.redirect(`/users/${req.params.id}`);
    }
  }
}
```

**Quand :** Applications simples, pages distinctes.
**Lié à :** Front Controller.

---

### 19. Front Controller

> Point d'entrée unique pour toutes les requêtes.

```go
class FrontController {
  private routes = new Map<string, Controller>();

  register(pattern: string, controller: Controller) {
    this.routes.set(pattern, controller);
  }

  async dispatch(req: Request, res: Response) {
    // Pre-processing
    await this.authenticate(req);
    await this.authorize(req);

    // Find and execute controller
    const controller = this.findController(req.path);
    await controller.handle(req, res);

    // Post-processing
    await this.log(req, res);
  }

  private findController(path: string): Controller {
    for (const [pattern, controller] of this.routes) {
      if (this.matches(path, pattern)) {
        return controller;
      }
    }
    throw new NotFoundError();
  }
}
```

**Quand :** Frameworks web, middleware, intercepteurs.
**Lié à :** Page Controller, Intercepting Filter.

---

### 20. Template View

> HTML avec placeholders.

```go
// template.html
// <h1>{{title}}</h1>
// <ul>
//   {{#each items}}
//     <li>{{name}}</li>
//   {{/each}}
// </ul>

class TemplateView {
  constructor(private engine: TemplateEngine) {}

  render(template: string, data: object): string {
    return this.engine.render(template, data);
  }
}

// Usage
const html = view.render('product/list', {
  title: 'Products',
  items: products,
});
```

**Quand :** HTML dynamique, server-side rendering.
**Lié à :** Transform View.

---

### 21. Transform View

> Transformer les données en sortie (XSLT, JSON, etc.).

```go
class JsonTransformView {
  transform(data: any): string {
    return JSON.stringify(data, null, 2);
  }
}

class XmlTransformView {
  transform(data: any): string {
    return this.objectToXml(data);
  }

  private objectToXml(obj: any, root = 'root'): string {
    let xml = `<${root}>`;
    for (const [key, value] of Object.entries(obj)) {
      if (Array.isArray(value)) {
        value.forEach((item) => {
          xml += this.objectToXml(item, key);
        });
      } else if (typeof value === 'object') {
        xml += this.objectToXml(value, key);
      } else {
        xml += `<${key}>${value}</${key}>`;
      }
    }
    xml += `</${root}>`;
    return xml;
  }
}
```

**Quand :** APIs, formats multiples, XSLT.
**Lié à :** Template View, Content Negotiation.

---

## Distribution Patterns

### 22. Remote Facade

> Interface simplifiée pour appels distants.

```go
// Fine-grained domain objects
class Order { /* many methods */ }
class OrderItem { /* many methods */ }
class Customer { /* many methods */ }

// Coarse-grained remote facade
class OrderFacade {
  @RemoteMethod()
  async placeOrder(dto: PlaceOrderDTO): Promise<OrderConfirmation> {
    // Single remote call does many operations
    const customer = await this.customerRepo.find(dto.customerId);
    const order = new Order(customer);

    for (const item of dto.items) {
      order.addItem(item.productId, item.quantity);
    }

    await this.orderRepo.save(order);
    return { orderId: order.id, total: order.total };
  }
}
```

**Quand :** APIs, microservices, réduire round-trips.
**Lié à :** Facade, DTO.

---

### 23. Data Transfer Object (DTO)

> Objet pour transférer des données entre couches.

```go
// DTOs - no behavior, just data
class OrderDTO {
  id: string;
  customerName: string;
  items: OrderItemDTO[];
  total: number;

  static from(order: Order): OrderDTO {
    return {
      id: order.id,
      customerName: order.customer.name,
      items: order.items.map(OrderItemDTO.from),
      total: order.total.amount,
    };
  }
}

class OrderItemDTO {
  productName: string;
  quantity: number;
  unitPrice: number;

  static from(item: OrderItem): OrderItemDTO {
    return {
      productName: item.product.name,
      quantity: item.quantity,
      unitPrice: item.product.price.amount,
    };
  }
}
```

**Quand :** APIs, sérialisation, isolation couches.
**Lié à :** Remote Facade, Assembler.

---

## Offline Concurrency

### 24. Optimistic Offline Lock

> Détecter les conflits au moment de la sauvegarde.

```go
class ProductMapper {
  async update(product: Product): Promise<void> {
    const result = await this.db.execute(`
      UPDATE products
      SET name = ?, price = ?, version = version + 1
      WHERE id = ? AND version = ?
    `, [product.name, product.price, product.id, product.version]);

    if (result.affectedRows === 0) {
      throw new OptimisticLockException('Product was modified by another user');
    }

    product.version++;
  }
}

// Usage
try {
  await productMapper.update(product);
} catch (e) {
  if (e instanceof OptimisticLockException) {
    // Reload and retry or notify user
    const fresh = await productMapper.find(product.id);
    // Merge changes...
  }
}
```

**Quand :** Conflits rares, pas de verrouillage long.
**Lié à :** Pessimistic Lock.

---

### 25. Pessimistic Offline Lock

> Verrouiller la ressource avant modification.

```go
class LockManager {
  private locks = new Map<string, { userId: string; expires: Date }>();

  acquire(resourceId: string, userId: string, ttlMinutes = 30): boolean {
    const existing = this.locks.get(resourceId);
    if (existing && existing.expires > new Date() && existing.userId !== userId) {
      return false; // Already locked by another user
    }

    this.locks.set(resourceId, {
      userId,
      expires: new Date(Date.now() + ttlMinutes * 60000),
    });
    return true;
  }

  release(resourceId: string, userId: string): boolean {
    const lock = this.locks.get(resourceId);
    if (lock && lock.userId === userId) {
      this.locks.delete(resourceId);
      return true;
    }
    return false;
  }

  isLocked(resourceId: string): boolean {
    const lock = this.locks.get(resourceId);
    return lock !== undefined && lock.expires > new Date();
  }
}
```

**Quand :** Conflits fréquents, édition longue.
**Lié à :** Optimistic Lock.

---

### 26. Coarse-Grained Lock

> Verrouiller un agrégat entier.

```go
class OrderLock {
  constructor(private lockManager: LockManager) {}

  async acquireForOrder(orderId: string, userId: string) {
    // Lock entire order aggregate
    const order = await this.orderRepo.find(orderId);

    const locked = await this.lockManager.acquire(`order:${orderId}`, userId);
    if (!locked) {
      throw new LockedException('Order is being edited by another user');
    }

    // Also lock all items
    for (const item of order.items) {
      await this.lockManager.acquire(`orderitem:${item.id}`, userId);
    }

    return order;
  }
}
```

**Quand :** Agrégats DDD, cohérence forte.
**Lié à :** Aggregate, Pessimistic Lock.

---

## Session State

### 27. Client Session State

> État stocké côté client.

```go
// JWT Token
class ClientSessionState {
  createToken(user: User): string {
    return jwt.sign({
      userId: user.id,
      role: user.role,
      preferences: user.preferences,
    }, SECRET, { expiresIn: '1h' });
  }

  parseToken(token: string): SessionData {
    return jwt.verify(token, SECRET) as SessionData;
  }
}

// Cookie
class CookieSession {
  save(res: Response, data: SessionData) {
    res.cookie('session', JSON.stringify(data), {
      httpOnly: true,
      secure: true,
      sameSite: 'strict',
    });
  }

  load(req: Request): SessionData | null {
    const cookie = req.cookies.session;
    return cookie ? JSON.parse(cookie) : null;
  }
}
```

**Quand :** Stateless servers, scalabilité.
**Lié à :** Server Session State.

---

### 28. Server Session State

> État stocké côté serveur.

```go
class ServerSessionState {
  private sessions = new Map<string, SessionData>();

  create(data: SessionData): string {
    const sessionId = crypto.randomUUID();
    this.sessions.set(sessionId, data);
    return sessionId;
  }

  get(sessionId: string): SessionData | undefined {
    return this.sessions.get(sessionId);
  }

  update(sessionId: string, data: Partial<SessionData>) {
    const session = this.sessions.get(sessionId);
    if (session) {
      Object.assign(session, data);
    }
  }

  destroy(sessionId: string) {
    this.sessions.delete(sessionId);
  }
}

// Redis-backed for distributed systems
class RedisSessionState {
  async get(sessionId: string): Promise<SessionData | null> {
    const data = await this.redis.get(`session:${sessionId}`);
    return data ? JSON.parse(data) : null;
  }

  async save(sessionId: string, data: SessionData, ttlSeconds = 3600) {
    await this.redis.setex(`session:${sessionId}`, ttlSeconds, JSON.stringify(data));
  }
}
```

**Quand :** Données sensibles, contrôle serveur.
**Lié à :** Client Session State.

---

### 29. Database Session State

> État stocké en base de données.

```go
class DatabaseSessionState {
  async create(data: SessionData): Promise<string> {
    const sessionId = crypto.randomUUID();
    await this.db.execute(`
      INSERT INTO sessions (id, data, expires_at)
      VALUES (?, ?, ?)
    `, [sessionId, JSON.stringify(data), this.expiresAt()]);
    return sessionId;
  }

  async get(sessionId: string): Promise<SessionData | null> {
    const rows = await this.db.query(`
      SELECT data FROM sessions
      WHERE id = ? AND expires_at > NOW()
    `, [sessionId]);
    return rows[0] ? JSON.parse(rows[0].data) : null;
  }

  async cleanup() {
    await this.db.execute('DELETE FROM sessions WHERE expires_at < NOW()');
  }
}
```

**Quand :** Persistance, survie redémarrage.
**Lié à :** Server Session State.

---

## Tableau de décision

| Besoin | Pattern |
|--------|---------|
| Logic simple/CRUD | Transaction Script |
| Logic métier riche | Domain Model |
| Coordination services | Service Layer |
| CRUD simple par table | Table/Row Data Gateway |
| Objets auto-persistants | Active Record |
| Séparation domain/persistence | Data Mapper |
| Tracking modifications | Unit of Work |
| Éviter doublons mémoire | Identity Map |
| Chargement différé | Lazy Load |
| Relations N-N | Association Table Mapping |
| Value objects | Embedded Value |
| Données flexibles | Serialized LOB |
| Héritage en DB | Inheritance Mapping |
| Réduire round-trips | Remote Facade + DTO |
| Conflits rares | Optimistic Lock |
| Conflits fréquents | Pessimistic Lock |

## Sources

- [Patterns of Enterprise Application Architecture - Martin Fowler](https://martinfowler.com/eaaCatalog/)
