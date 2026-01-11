# Anti-Corruption Layer (ACL) Pattern

> Isoler le domaine metier des systemes legacy ou externes pour eviter la pollution du modele.

---

## Principe

```
┌─────────────────────────────────────────────────────────────────┐
│                  ANTI-CORRUPTION LAYER                           │
│                                                                  │
│   New Domain                 ACL                Legacy System    │
│   (Clean Model)           (Translator)         (Messy Model)    │
│                                                                  │
│  ┌───────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │               │      │              │      │              │  │
│  │   Customer    │      │   Adapter    │      │   CUST_TBL   │  │
│  │   Order       │◄────►│   Facade     │◄────►│   ORD_HDR    │  │
│  │   Product     │      │   Translator │      │   ITEM_MST   │  │
│  │               │      │              │      │              │  │
│  └───────────────┘      └──────────────┘      └──────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ L'ACL traduit entre les deux mondes:                        ││
│  │ - Noms de champs (customerId ↔ CUST_ID)                     ││
│  │ - Formats de donnees (ISO date ↔ YYYYMMDD)                  ││
│  │ - Logique metier (status enum ↔ codes numeriques)           ││
│  │ - Protocoles (REST ↔ SOAP/XML)                              ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

---

## Composants de l'ACL

| Composant | Role |
|-----------|------|
| **Facade** | Interface simplifiee vers le legacy |
| **Adapter** | Convertit les interfaces incompatibles |
| **Translator** | Transforme les donnees entre modeles |
| **Repository** | Abstrait l'acces aux donnees legacy |

---

## Implementation TypeScript

### Modeles de domaine (propres)

```typescript
// Notre domaine propre
interface Customer {
  id: string;
  email: string;
  fullName: string;
  createdAt: Date;
  status: CustomerStatus;
  address: Address;
}

enum CustomerStatus {
  Active = 'ACTIVE',
  Suspended = 'SUSPENDED',
  Closed = 'CLOSED',
}

interface Address {
  street: string;
  city: string;
  country: string;
  postalCode: string;
}

interface Order {
  id: string;
  customerId: string;
  items: OrderItem[];
  total: Money;
  status: OrderStatus;
  createdAt: Date;
}

interface Money {
  amount: number;
  currency: string;
}
```

---

### Modele Legacy (ce qu'on recoit)

```typescript
// Ce que retourne le systeme legacy (SOAP/XML converti)
interface LegacyCustomerRecord {
  CUST_ID: string;
  CUST_EMAIL: string;
  CUST_FNAME: string;
  CUST_LNAME: string;
  CUST_CREATED: string;  // Format: YYYYMMDD
  CUST_STATUS: number;   // 1=active, 2=suspended, 9=closed
  ADDR_LINE1: string;
  ADDR_CITY: string;
  ADDR_CNTRY: string;
  ADDR_ZIP: string;
}

interface LegacyOrderRecord {
  ORDER_NBR: string;
  CUST_ID: string;
  ORDER_AMT: number;     // Cents
  ORDER_CCY: string;
  ORDER_DT: string;      // YYYYMMDD
  ORDER_STAT: string;    // 'N', 'P', 'S', 'C'
  ITEMS: LegacyOrderItem[];
}
```

---

### Translator (coeur de l'ACL)

```typescript
class CustomerTranslator {
  // Legacy → Domain
  toDomain(legacy: LegacyCustomerRecord): Customer {
    return {
      id: legacy.CUST_ID,
      email: legacy.CUST_EMAIL,
      fullName: `${legacy.CUST_FNAME} ${legacy.CUST_LNAME}`.trim(),
      createdAt: this.parseDate(legacy.CUST_CREATED),
      status: this.mapStatus(legacy.CUST_STATUS),
      address: {
        street: legacy.ADDR_LINE1,
        city: legacy.ADDR_CITY,
        country: legacy.ADDR_CNTRY,
        postalCode: legacy.ADDR_ZIP,
      },
    };
  }

  // Domain → Legacy
  toLegacy(customer: Customer): Partial<LegacyCustomerRecord> {
    const [firstName, ...lastNameParts] = customer.fullName.split(' ');
    return {
      CUST_ID: customer.id,
      CUST_EMAIL: customer.email,
      CUST_FNAME: firstName,
      CUST_LNAME: lastNameParts.join(' '),
      CUST_CREATED: this.formatDate(customer.createdAt),
      CUST_STATUS: this.reverseMapStatus(customer.status),
      ADDR_LINE1: customer.address.street,
      ADDR_CITY: customer.address.city,
      ADDR_CNTRY: customer.address.country,
      ADDR_ZIP: customer.address.postalCode,
    };
  }

  private parseDate(legacyDate: string): Date {
    // YYYYMMDD → Date
    const year = parseInt(legacyDate.substring(0, 4));
    const month = parseInt(legacyDate.substring(4, 6)) - 1;
    const day = parseInt(legacyDate.substring(6, 8));
    return new Date(year, month, day);
  }

  private formatDate(date: Date): string {
    // Date → YYYYMMDD
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}${month}${day}`;
  }

  private mapStatus(legacyStatus: number): CustomerStatus {
    const mapping: Record<number, CustomerStatus> = {
      1: CustomerStatus.Active,
      2: CustomerStatus.Suspended,
      9: CustomerStatus.Closed,
    };
    return mapping[legacyStatus] ?? CustomerStatus.Active;
  }

  private reverseMapStatus(status: CustomerStatus): number {
    const mapping: Record<CustomerStatus, number> = {
      [CustomerStatus.Active]: 1,
      [CustomerStatus.Suspended]: 2,
      [CustomerStatus.Closed]: 9,
    };
    return mapping[status];
  }
}

class OrderTranslator {
  toDomain(legacy: LegacyOrderRecord): Order {
    return {
      id: legacy.ORDER_NBR,
      customerId: legacy.CUST_ID,
      items: legacy.ITEMS.map((item) => this.translateItem(item)),
      total: {
        amount: legacy.ORDER_AMT / 100, // Cents → Dollars
        currency: legacy.ORDER_CCY,
      },
      status: this.mapOrderStatus(legacy.ORDER_STAT),
      createdAt: this.parseDate(legacy.ORDER_DT),
    };
  }

  private mapOrderStatus(status: string): OrderStatus {
    const mapping: Record<string, OrderStatus> = {
      N: OrderStatus.New,
      P: OrderStatus.Processing,
      S: OrderStatus.Shipped,
      C: OrderStatus.Cancelled,
    };
    return mapping[status] ?? OrderStatus.New;
  }

  private translateItem(item: LegacyOrderItem): OrderItem {
    // ... translation logic
  }

  private parseDate(date: string): Date {
    // Same as CustomerTranslator
  }
}
```

---

### Adapter pour le systeme legacy

```typescript
interface LegacySystemClient {
  executeQuery(query: string): Promise<any>;
  executeTransaction(commands: string[]): Promise<void>;
}

class LegacyCustomerAdapter {
  constructor(
    private readonly client: LegacySystemClient,
    private readonly translator: CustomerTranslator,
  ) {}

  async findById(id: string): Promise<Customer | null> {
    const result = await this.client.executeQuery(
      `SELECT * FROM CUST_TBL WHERE CUST_ID = '${id}'`,
    );

    if (!result || result.length === 0) {
      return null;
    }

    return this.translator.toDomain(result[0]);
  }

  async findByEmail(email: string): Promise<Customer | null> {
    const result = await this.client.executeQuery(
      `SELECT * FROM CUST_TBL WHERE CUST_EMAIL = '${email}'`,
    );

    if (!result || result.length === 0) {
      return null;
    }

    return this.translator.toDomain(result[0]);
  }

  async save(customer: Customer): Promise<void> {
    const legacyRecord = this.translator.toLegacy(customer);

    const existing = await this.findById(customer.id);
    if (existing) {
      await this.update(legacyRecord);
    } else {
      await this.insert(legacyRecord);
    }
  }

  private async insert(record: Partial<LegacyCustomerRecord>): Promise<void> {
    await this.client.executeTransaction([
      `INSERT INTO CUST_TBL (CUST_ID, CUST_EMAIL, ...) VALUES ('${record.CUST_ID}', ...)`,
    ]);
  }

  private async update(record: Partial<LegacyCustomerRecord>): Promise<void> {
    await this.client.executeTransaction([
      `UPDATE CUST_TBL SET CUST_EMAIL = '${record.CUST_EMAIL}', ... WHERE CUST_ID = '${record.CUST_ID}'`,
    ]);
  }
}
```

---

### Facade (interface simplifiee)

```typescript
// Interface propre pour le domaine
interface CustomerRepository {
  findById(id: string): Promise<Customer | null>;
  findByEmail(email: string): Promise<Customer | null>;
  save(customer: Customer): Promise<void>;
  delete(id: string): Promise<void>;
}

// Implementation via l'ACL
class LegacyCustomerRepository implements CustomerRepository {
  constructor(private readonly adapter: LegacyCustomerAdapter) {}

  async findById(id: string): Promise<Customer | null> {
    return this.adapter.findById(id);
  }

  async findByEmail(email: string): Promise<Customer | null> {
    return this.adapter.findByEmail(email);
  }

  async save(customer: Customer): Promise<void> {
    await this.adapter.save(customer);
  }

  async delete(id: string): Promise<void> {
    await this.adapter.markAsDeleted(id);
  }
}

// Le code metier utilise l'interface propre
class CustomerService {
  constructor(private readonly repository: CustomerRepository) {}

  async getCustomer(id: string): Promise<Customer> {
    const customer = await this.repository.findById(id);
    if (!customer) {
      throw new CustomerNotFoundError(id);
    }
    return customer;
  }

  // Le service ne sait pas qu'il parle a un legacy
}
```

---

### ACL pour API externe

```typescript
// API Stripe (externe) avec son propre modele
interface StripePaymentIntent {
  id: string;
  amount: number;
  currency: string;
  status: 'requires_payment_method' | 'succeeded' | 'canceled';
  metadata: Record<string, string>;
}

// Notre domaine
interface Payment {
  id: string;
  orderId: string;
  amount: Money;
  status: PaymentStatus;
}

class StripePaymentACL {
  constructor(private readonly stripe: Stripe) {}

  async createPayment(order: Order): Promise<Payment> {
    const intent = await this.stripe.paymentIntents.create({
      amount: Math.round(order.total.amount * 100),
      currency: order.total.currency.toLowerCase(),
      metadata: { orderId: order.id },
    });

    return this.toDomain(intent);
  }

  async getPayment(paymentId: string): Promise<Payment> {
    const intent = await this.stripe.paymentIntents.retrieve(paymentId);
    return this.toDomain(intent);
  }

  private toDomain(intent: StripePaymentIntent): Payment {
    return {
      id: intent.id,
      orderId: intent.metadata.orderId,
      amount: {
        amount: intent.amount / 100,
        currency: intent.currency.toUpperCase(),
      },
      status: this.mapStatus(intent.status),
    };
  }

  private mapStatus(stripeStatus: string): PaymentStatus {
    const mapping: Record<string, PaymentStatus> = {
      requires_payment_method: PaymentStatus.Pending,
      succeeded: PaymentStatus.Completed,
      canceled: PaymentStatus.Failed,
    };
    return mapping[stripeStatus] ?? PaymentStatus.Pending;
  }
}
```

---

## Quand utiliser

- Integration avec systeme legacy
- APIs tierces avec modeles differents
- Migration progressive (Strangler Fig)
- Bounded contexts differents (DDD)
- Protection contre changements externes

---

## Lie a

| Pattern | Relation |
|---------|----------|
| Adapter | Composant de l'ACL |
| Facade | Interface simplifiee |
| Translator | Conversion de donnees |
| Repository | Abstraction de persistence |
| Strangler Fig | Migration avec ACL |

---

## Sources

- [Eric Evans - DDD](https://domainlanguage.com/ddd/)
- [Microsoft - ACL Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/anti-corruption-layer)
- [Martin Fowler - Legacy Systems](https://martinfowler.com/bliki/StranglerFigApplication.html)
