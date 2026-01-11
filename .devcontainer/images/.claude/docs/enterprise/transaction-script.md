# Transaction Script

> "Organizes business logic by procedures where each procedure handles a single request from the presentation." - Martin Fowler, PoEAA

## Concept

Transaction Script est le pattern le plus simple pour organiser la logique metier. Chaque operation metier est implementee comme une procedure unique qui execute toutes les etapes de la transaction de bout en bout.

## Caracteristiques

- **Procedurale** : Code organise par transactions, pas par objets
- **Directe** : Lecture lineaire du flux de donnees
- **Simple** : Pas d'abstraction complexe
- **Autonome** : Chaque script est independant

## Implementation TypeScript

```typescript
// Transaction Script - Approche procedurale
class OrderTransactionScripts {
  constructor(
    private db: Database,
    private emailService: EmailService,
    private paymentGateway: PaymentGateway,
  ) {}

  /**
   * Script complet pour placer une commande
   * Toute la logique dans une seule procedure
   */
  async placeOrder(
    customerId: string,
    items: Array<{ productId: string; quantity: number }>,
    paymentMethod: PaymentMethod,
  ): Promise<string> {
    // 1. Valider le client
    const customer = await this.db.query(
      'SELECT * FROM customers WHERE id = ? AND active = true',
      [customerId],
    );
    if (!customer) {
      throw new Error('Customer not found or inactive');
    }

    // 2. Verifier le stock et calculer le total
    let totalAmount = 0;
    const orderItems: OrderItem[] = [];

    for (const item of items) {
      const product = await this.db.query(
        'SELECT * FROM products WHERE id = ?',
        [item.productId],
      );
      if (!product) {
        throw new Error(`Product ${item.productId} not found`);
      }
      if (product.stock < item.quantity) {
        throw new Error(`Insufficient stock for ${product.name}`);
      }
      totalAmount += product.price * item.quantity;
      orderItems.push({ ...item, price: product.price, name: product.name });
    }

    // 3. Appliquer les reductions
    const discount = await this.calculateDiscount(customerId, totalAmount);
    const finalAmount = totalAmount - discount;

    // 4. Traiter le paiement
    const paymentResult = await this.paymentGateway.charge(
      paymentMethod,
      finalAmount,
    );
    if (!paymentResult.success) {
      throw new Error(`Payment failed: ${paymentResult.error}`);
    }

    // 5. Creer la commande et mettre a jour le stock
    const orderId = crypto.randomUUID();
    await this.db.transaction(async (tx) => {
      await tx.execute(
        `INSERT INTO orders (id, customer_id, total, status, created_at)
         VALUES (?, ?, ?, 'confirmed', NOW())`,
        [orderId, customerId, finalAmount],
      );

      for (const item of orderItems) {
        await tx.execute(
          `INSERT INTO order_items (order_id, product_id, quantity, price)
           VALUES (?, ?, ?, ?)`,
          [orderId, item.productId, item.quantity, item.price],
        );
        await tx.execute(
          'UPDATE products SET stock = stock - ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
    });

    // 6. Envoyer confirmation
    await this.emailService.sendOrderConfirmation(customer.email, {
      orderId,
      items: orderItems,
      total: finalAmount,
    });

    return orderId;
  }

  /**
   * Script pour annuler une commande
   */
  async cancelOrder(orderId: string, reason: string): Promise<void> {
    const order = await this.db.query(
      'SELECT * FROM orders WHERE id = ?',
      [orderId],
    );
    if (!order) throw new Error('Order not found');
    if (order.status === 'shipped') {
      throw new Error('Cannot cancel shipped order');
    }

    // Rembourser
    if (order.payment_id) {
      await this.paymentGateway.refund(order.payment_id);
    }

    // Restaurer le stock
    const items = await this.db.query(
      'SELECT * FROM order_items WHERE order_id = ?',
      [orderId],
    );

    await this.db.transaction(async (tx) => {
      for (const item of items) {
        await tx.execute(
          'UPDATE products SET stock = stock + ? WHERE id = ?',
          [item.quantity, item.product_id],
        );
      }
      await tx.execute(
        'UPDATE orders SET status = ?, cancelled_reason = ? WHERE id = ?',
        ['cancelled', reason, orderId],
      );
    });
  }

  private async calculateDiscount(
    customerId: string,
    amount: number,
  ): Promise<number> {
    const orderCount = await this.db.query(
      'SELECT COUNT(*) as count FROM orders WHERE customer_id = ?',
      [customerId],
    );
    // 10% pour clients fideles (10+ commandes)
    if (orderCount.count >= 10) {
      return amount * 0.1;
    }
    return 0;
  }
}
```

## Comparaison avec les alternatives

| Aspect | Transaction Script | Domain Model | Service Layer |
|--------|-------------------|--------------|---------------|
| Complexite | Faible | Elevee | Moyenne |
| Reutilisation | Faible | Elevee | Moyenne |
| Testabilite | Moyenne | Elevee | Elevee |
| Courbe d'apprentissage | Faible | Elevee | Moyenne |
| Maintenance long terme | Difficile | Facile | Moyenne |

## Quand utiliser

**Utiliser Transaction Script quand :**

- Logique metier simple et directe
- Applications CRUD basiques
- Prototypes et MVPs
- Equipe peu experimentee avec OOP/DDD
- Deadlines serrees
- Logique qui ne changera pas souvent

**Eviter Transaction Script quand :**

- Regles metier complexes ou changeantes
- Logique partagee entre plusieurs operations
- Besoin de tests unitaires fins
- Application destinee a evoluer significativement
- Domaine metier riche avec invariants

## Relation avec DDD

Transaction Script est souvent considere comme l'**antithese du DDD** :

```typescript
// Transaction Script = Anemic Domain Model
// La logique est dans les services, pas dans les entites

// Entite anemique (anti-pattern DDD)
class Order {
  id: string;
  customerId: string;
  items: OrderItem[];
  status: string;
  // Pas de comportement, juste des donnees
}

// Toute la logique dans le script
class OrderScript {
  async submit(order: Order) {
    if (order.items.length === 0) throw new Error('Empty order');
    order.status = 'submitted';
    await this.db.save(order);
  }
}
```

En DDD, on prefere un **Rich Domain Model** :

```typescript
// Entite riche (DDD)
class Order {
  private status: OrderStatus = OrderStatus.Draft;

  submit(): void {
    if (this.items.length === 0) {
      throw new DomainError('Cannot submit empty order');
    }
    this.status = OrderStatus.Submitted;
    this.addDomainEvent(new OrderSubmitted(this.id));
  }
}
```

## Evolution naturelle

Transaction Script evolue souvent vers :

1. **Service Layer** : Quand la coordination devient complexe
2. **Domain Model** : Quand la logique metier devient riche
3. **CQRS** : Quand lectures et ecritures divergent

## Anti-patterns a eviter

```typescript
// EVITER: Scripts trop longs (> 100 lignes)
// EVITER: Duplication entre scripts
// EVITER: Logique metier dans les controllers
// EVITER: Scripts avec trop de responsabilites
```

## Sources

- Martin Fowler, PoEAA, Chapter 9: Domain Logic Patterns
- [Transaction Script - martinfowler.com](https://martinfowler.com/eaaCatalog/transactionScript.html)
