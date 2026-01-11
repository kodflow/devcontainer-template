# Data Transfer Object (DTO)

> "An object that carries data between processes in order to reduce the number of method calls." - Martin Fowler, PoEAA

## Concept

Le DTO est un objet simple qui transporte des donnees entre les couches ou les processus. Il n'a pas de logique metier, seulement des donnees et eventuellement des methodes de serialisation.

## Objectifs

1. **Reduire les appels** : Agreger les donnees en un seul objet
2. **Decoupler** : Separer le modele de domaine de l'API
3. **Serialisation** : Format adapte au transfert (JSON, XML)
4. **Securite** : Ne pas exposer les details internes

## Implementation TypeScript

```typescript
// DTO de requete (input)
interface CreateOrderRequest {
  customerId: string;
  items: Array<{
    productId: string;
    quantity: number;
  }>;
  shippingAddress: {
    street: string;
    city: string;
    postalCode: string;
    country: string;
  };
  notes?: string;
}

// DTO de reponse (output)
interface OrderResponse {
  id: string;
  status: string;
  customerName: string;
  items: OrderItemResponse[];
  subtotal: number;
  tax: number;
  total: number;
  createdAt: string;
  estimatedDelivery: string;
}

interface OrderItemResponse {
  productId: string;
  productName: string;
  quantity: number;
  unitPrice: number;
  subtotal: number;
}

// DTO avec validation (class-validator)
class CreateOrderDTO {
  @IsUUID()
  customerId: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => OrderItemDTO)
  items: OrderItemDTO[];

  @ValidateNested()
  @Type(() => AddressDTO)
  shippingAddress: AddressDTO;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  notes?: string;
}

class OrderItemDTO {
  @IsUUID()
  productId: string;

  @IsInt()
  @Min(1)
  @Max(100)
  quantity: number;
}

class AddressDTO {
  @IsString()
  @MaxLength(200)
  street: string;

  @IsString()
  @MaxLength(100)
  city: string;

  @IsPostalCode('any')
  postalCode: string;

  @IsISO31661Alpha2()
  country: string;
}
```

## Assembler / Mapper

```typescript
// Assembler - Convertit Domain <-> DTO
class OrderAssembler {
  toDTO(order: Order, customer: Customer): OrderResponse {
    return {
      id: order.id,
      status: order.status,
      customerName: customer.name,
      items: order.items.map((item) => this.itemToDTO(item)),
      subtotal: order.subtotal.amount,
      tax: order.tax.amount,
      total: order.total.amount,
      createdAt: order.createdAt.toISOString(),
      estimatedDelivery: order.estimatedDelivery.toISOString(),
    };
  }

  private itemToDTO(item: OrderItem): OrderItemResponse {
    return {
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice.amount,
      subtotal: item.subtotal.amount,
    };
  }

  // DTO -> Domain (pour creation)
  toDomain(dto: CreateOrderDTO): OrderCreationParams {
    return {
      customerId: CustomerId.from(dto.customerId),
      items: dto.items.map((item) => ({
        productId: ProductId.from(item.productId),
        quantity: item.quantity,
      })),
      shippingAddress: new Address(
        dto.shippingAddress.street,
        dto.shippingAddress.city,
        dto.shippingAddress.postalCode,
        dto.shippingAddress.country,
      ),
      notes: dto.notes,
    };
  }
}

// DTOs pour differents use cases
class OrderSummaryDTO {
  id: string;
  status: string;
  total: number;
  itemCount: number;
  createdAt: string;

  static fromDomain(order: Order): OrderSummaryDTO {
    return {
      id: order.id,
      status: order.status,
      total: order.total.amount,
      itemCount: order.items.length,
      createdAt: order.createdAt.toISOString(),
    };
  }
}

class OrderDetailDTO extends OrderSummaryDTO {
  customerName: string;
  customerEmail: string;
  items: OrderItemResponse[];
  shippingAddress: AddressDTO;
  billingAddress: AddressDTO;
  paymentMethod: string;
  notes?: string;

  static fromDomain(order: Order, customer: Customer): OrderDetailDTO {
    return {
      ...OrderSummaryDTO.fromDomain(order),
      customerName: customer.name,
      customerEmail: customer.email.value,
      items: order.items.map((i) => OrderItemResponse.fromDomain(i)),
      shippingAddress: AddressDTO.fromDomain(order.shippingAddress),
      billingAddress: AddressDTO.fromDomain(order.billingAddress),
      paymentMethod: order.paymentMethod,
      notes: order.notes,
    };
  }
}
```

## DTOs dans une API REST

```typescript
// Controller utilisant les DTOs
@Controller('/orders')
class OrderController {
  constructor(
    private readonly orderService: OrderApplicationService,
    private readonly assembler: OrderAssembler,
  ) {}

  @Post('/')
  @HttpCode(201)
  async createOrder(
    @Body() dto: CreateOrderDTO,
    @CurrentUser() user: User,
  ): Promise<OrderResponse> {
    // Validation automatique via class-validator
    const params = this.assembler.toDomain(dto);
    const order = await this.orderService.createOrder(params, user);
    return this.assembler.toDTO(order);
  }

  @Get('/:id')
  async getOrder(
    @Param('id') id: string,
    @CurrentUser() user: User,
  ): Promise<OrderDetailDTO> {
    const order = await this.orderService.getOrderById(id, user);
    return OrderDetailDTO.fromDomain(order);
  }

  @Get('/')
  async listOrders(
    @Query() query: ListOrdersQuery,
    @CurrentUser() user: User,
  ): Promise<PaginatedResponse<OrderSummaryDTO>> {
    const result = await this.orderService.listOrders(query, user);
    return {
      items: result.items.map(OrderSummaryDTO.fromDomain),
      total: result.total,
      page: query.page,
      pageSize: query.pageSize,
    };
  }

  @Patch('/:id')
  async updateOrder(
    @Param('id') id: string,
    @Body() dto: UpdateOrderDTO,
    @CurrentUser() user: User,
  ): Promise<OrderResponse> {
    const order = await this.orderService.updateOrder(id, dto, user);
    return this.assembler.toDTO(order);
  }
}

// Query DTO pour filtrage/pagination
class ListOrdersQuery {
  @IsOptional()
  @IsEnum(OrderStatus)
  status?: OrderStatus;

  @IsOptional()
  @IsDateString()
  fromDate?: string;

  @IsOptional()
  @IsDateString()
  toDate?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize?: number = 20;

  @IsOptional()
  @IsInt()
  @Min(1)
  page?: number = 1;
}
```

## DTOs vs Domain Objects

```typescript
// Domain Object - Logique metier, invariants
class Order {
  private status: OrderStatus;
  private items: OrderItem[];

  submit(): void {
    if (this.items.length === 0) {
      throw new DomainError('Cannot submit empty order');
    }
    this.status = OrderStatus.Submitted;
  }

  get total(): Money {
    return this.items.reduce((sum, item) => sum.add(item.subtotal), Money.zero());
  }
}

// DTO - Pas de logique, juste des donnees
interface OrderDTO {
  id: string;
  status: string;
  items: OrderItemDTO[];
  total: number;
  // Pas de methodes metier!
}
```

## Comparaison avec alternatives

| Aspect | DTO | Domain Object | Map/Record |
|--------|-----|---------------|------------|
| Type safety | Forte | Forte | Faible |
| Serialisation | Facile | Complexe | Native |
| Validation | Explicite | Invariants | Manuelle |
| Logique | Aucune | Riche | Aucune |
| Versioning | Facile | Difficile | Facile |

## Quand utiliser

**Utiliser DTO quand :**

- API REST/GraphQL (input/output)
- Communication entre services
- Separation domaine/presentation
- Versioning d'API
- Serialisation specifique

**Eviter DTO quand :**

- Duplication excessive (1:1 avec domain)
- Applications simples/CRUD
- Performance critique (overhead mapping)

## Relation avec DDD

Les DTOs vivent dans l'**Application Layer** ou **Interface Layer** :

```
┌─────────────────────────────────────────────┐
│              Interface Layer                │
│   - Controllers recoivent/retournent DTOs   │
│   - Assemblers convertissent                │
├─────────────────────────────────────────────┤
│           Application Layer                 │
│   - Services utilisent DTOs en entree       │
│   - Retournent Domain ou DTOs               │
├─────────────────────────────────────────────┤
│              Domain Layer                   │
│   - Entities, Value Objects (pas de DTOs)   │
│   - Logique metier pure                     │
├─────────────────────────────────────────────┤
│          Infrastructure Layer               │
│   - Peut avoir ses propres DTOs (DB rows)   │
└─────────────────────────────────────────────┘
```

## Anti-patterns a eviter

```typescript
// EVITER: DTO avec logique metier
class BadOrderDTO {
  calculateTotal(): number { // Logique dans DTO!
    return this.items.reduce((s, i) => s + i.price * i.qty, 0);
  }
}

// EVITER: Exposer les entites directement
@Get('/:id')
async getOrder(@Param('id') id: string): Promise<Order> {
  return this.orderRepo.findById(id); // Expose le domaine!
}

// EVITER: Mapper domain -> DTO dans le domaine
class Order {
  toDTO(): OrderDTO { // Le domaine ne devrait pas connaitre les DTOs
    return { ... };
  }
}
```

## Patterns associes

- **Assembler** : Conversion Domain <-> DTO
- **Remote Facade** : Utilise DTOs pour appels distants
- **CQRS** : Read Models sont des DTOs specialises
- **API Gateway** : Aggrege DTOs de plusieurs services

## Sources

- Martin Fowler, PoEAA, Chapter 15
- [Data Transfer Object - martinfowler.com](https://martinfowler.com/eaaCatalog/dataTransferObject.html)
