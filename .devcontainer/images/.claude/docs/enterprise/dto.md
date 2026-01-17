# Data Transfer Object (DTO)

> "An object that carries data between processes in order to reduce the number of method calls." - Martin Fowler, PoEAA

## Concept

Le DTO est un objet simple qui transporte des donnees entre les couches ou les processus. Il n'a pas de logique metier, seulement des donnees et eventuellement des methodes de serialisation.

## Objectifs

1. **Reduire les appels** : Agreger les donnees en un seul objet
2. **Decoupler** : Separer le modele de domaine de l'API
3. **Serialisation** : Format adapte au transfert (JSON, XML)
4. **Securite** : Ne pas exposer les details internes
5. **Groupement** : Permettre plusieurs DTOs dans un meme fichier

## Convention Tags

**Format obligatoire :** `dto:"<direction>,<context>,<security>"`

Le tag `dto:` permet de :
- Exempter les structs de KTN-STRUCT-ONEFILE (groupement)
- Exempter les structs de KTN-STRUCT-CTOR (pas de constructeur requis)
- Documenter le flux et la sensibilite des donnees

### Valeurs

| Position | Valeurs | Description |
|----------|---------|-------------|
| direction | `in`, `out`, `inout` | Sens du flux |
| context | `api`, `cmd`, `query`, `event`, `msg`, `priv` | Type DTO |
| security | `pub`, `priv`, `pii`, `secret` | Classification |

### Classification Securite

| Valeur | Description | Logging | Marshaling |
|--------|-------------|---------|------------|
| `pub` | Donnees publiques | Affiche | Inclus |
| `priv` | Interne (IDs, timestamps) | Affiche | Inclus |
| `pii` | RGPD (email, nom, adresse) | Masque | Conditionnel |
| `secret` | Credentials (password, token) | REDACTED | Omis |

**Reference :** [conventions/dto-tags.md](../conventions/dto-tags.md)

## Implementation Go

```go
package dto

import (
	"time"
)

// Fichier: order_dto.go
// PLUSIEURS DTOs groupes grace au tag dto:"..."

// CreateOrderRequest is an input DTO for order creation.
type CreateOrderRequest struct {
	CustomerID      string             `dto:"in,api,priv" json:"customerId" validate:"required,uuid"`
	Items           []OrderItemRequest `dto:"in,api,pub" json:"items" validate:"required,min=1,dive"`
	ShippingAddress AddressRequest     `dto:"in,api,pii" json:"shippingAddress" validate:"required"`
	Notes           string             `dto:"in,api,pub" json:"notes,omitempty" validate:"max=500"`
}

// OrderItemRequest represents an order item in request.
type OrderItemRequest struct {
	ProductID string `dto:"in,api,pub" json:"productId" validate:"required,uuid"`
	Quantity  int    `dto:"in,api,pub" json:"quantity" validate:"required,min=1,max=100"`
}

// AddressRequest represents an address in request.
type AddressRequest struct {
	Street     string `dto:"in,api,pii" json:"street" validate:"required,max=200"`
	City       string `dto:"in,api,pii" json:"city" validate:"required,max=100"`
	PostalCode string `dto:"in,api,pii" json:"postalCode" validate:"required"`
	Country    string `dto:"in,api,pub" json:"country" validate:"required,iso3166_1_alpha2"`
}

// OrderResponse is an output DTO for order details.
type OrderResponse struct {
	ID                string              `dto:"out,api,pub" json:"id"`
	Status            string              `dto:"out,api,pub" json:"status"`
	CustomerName      string              `dto:"out,api,pii" json:"customerName"`
	Items             []OrderItemResponse `dto:"out,api,pub" json:"items"`
	Subtotal          float64             `dto:"out,api,pub" json:"subtotal"`
	Tax               float64             `dto:"out,api,pub" json:"tax"`
	Total             float64             `dto:"out,api,pub" json:"total"`
	CreatedAt         time.Time           `dto:"out,api,pub" json:"createdAt"`
	EstimatedDelivery time.Time           `dto:"out,api,pub" json:"estimatedDelivery"`
}

// OrderItemResponse represents an order item in response.
type OrderItemResponse struct {
	ProductID   string  `dto:"out,api,pub" json:"productId"`
	ProductName string  `dto:"out,api,pub" json:"productName"`
	Quantity    int     `dto:"out,api,pub" json:"quantity"`
	UnitPrice   float64 `dto:"out,api,pub" json:"unitPrice"`
	Subtotal    float64 `dto:"out,api,pub" json:"subtotal"`
}

// OrderSummaryDTO is a lightweight DTO for listings.
type OrderSummaryDTO struct {
	ID        string    `dto:"out,api,pub" json:"id"`
	Status    string    `dto:"out,api,pub" json:"status"`
	Total     float64   `dto:"out,api,pub" json:"total"`
	ItemCount int       `dto:"out,api,pub" json:"itemCount"`
	CreatedAt time.Time `dto:"out,api,pub" json:"createdAt"`
}

// ListOrdersQuery represents query parameters for listing orders.
type ListOrdersQuery struct {
	Status   string `dto:"in,query,pub" json:"status,omitempty"`
	FromDate string `dto:"in,query,pub" json:"fromDate,omitempty" validate:"omitempty,datetime=2006-01-02"`
	ToDate   string `dto:"in,query,pub" json:"toDate,omitempty" validate:"omitempty,datetime=2006-01-02"`
	PageSize int    `dto:"in,query,pub" json:"pageSize,omitempty" validate:"omitempty,min=1,max=100"`
	Page     int    `dto:"in,query,pub" json:"page,omitempty" validate:"omitempty,min=1"`
}

// Defaults sets default values for the query.
func (q *ListOrdersQuery) Defaults() {
	if q.PageSize == 0 {
		q.PageSize = 20
	}
	if q.Page == 0 {
		q.Page = 1
	}
}

// PaginatedResponse represents a paginated result.
type PaginatedResponse[T any] struct {
	Items    []T `dto:"out,api,pub" json:"items"`
	Total    int `dto:"out,api,pub" json:"total"`
	Page     int `dto:"out,api,pub" json:"page"`
	PageSize int `dto:"out,api,pub" json:"pageSize"`
}
```

## Assembler Pattern

```go
// OrderAssembler converts between domain and DTO.
type OrderAssembler struct{}

// NewOrderAssembler creates a new assembler.
func NewOrderAssembler() *OrderAssembler {
	return &OrderAssembler{}
}

// ToDTO converts domain Order to OrderResponse.
func (a *OrderAssembler) ToDTO(order *Order, customer *Customer) *OrderResponse {
	items := make([]OrderItemResponse, len(order.Items))
	for i, item := range order.Items {
		items[i] = a.itemToDTO(item)
	}

	return &OrderResponse{
		ID:                order.ID,
		Status:            order.Status,
		CustomerName:      customer.Name,
		Items:             items,
		Subtotal:          order.Subtotal,
		Tax:               order.Tax,
		Total:             order.Total,
		CreatedAt:         order.CreatedAt,
		EstimatedDelivery: order.EstimatedDelivery,
	}
}

func (a *OrderAssembler) itemToDTO(item *OrderItem) OrderItemResponse {
	return OrderItemResponse{
		ProductID:   item.ProductID,
		ProductName: item.ProductName,
		Quantity:    item.Quantity,
		UnitPrice:   item.UnitPrice,
		Subtotal:    item.Subtotal,
	}
}

// ToDomain converts CreateOrderRequest to domain parameters.
func (a *OrderAssembler) ToDomain(dto *CreateOrderRequest) *OrderCreationParams {
	items := make([]OrderItemParams, len(dto.Items))
	for i, item := range dto.Items {
		items[i] = OrderItemParams{
			ProductID: item.ProductID,
			Quantity:  item.Quantity,
		}
	}

	return &OrderCreationParams{
		CustomerID: dto.CustomerID,
		Items:      items,
		ShippingAddress: Address{
			Street:     dto.ShippingAddress.Street,
			City:       dto.ShippingAddress.City,
			PostalCode: dto.ShippingAddress.PostalCode,
			Country:    dto.ShippingAddress.Country,
		},
		Notes: dto.Notes,
	}
}
```

## DTOs vs Domain Objects

```go
// Domain Object - Business logic, invariants (PAS de tags)
type DomainOrder struct {
	status OrderStatus
	items  []*OrderItem
}

func (o *DomainOrder) Submit() error {
	if len(o.items) == 0 {
		return fmt.Errorf("cannot submit empty order")
	}
	o.status = OrderStatusSubmitted
	return nil
}

func (o *DomainOrder) Total() float64 {
	var total float64
	for _, item := range o.items {
		total += item.Subtotal()
	}
	return total
}

// DTO - No logic, just data (AVEC dto:"..." tags)
type OrderDTO struct {
	ID     string         `dto:"out,api,pub" json:"id"`
	Status string         `dto:"out,api,pub" json:"status"`
	Items  []OrderItemDTO `dto:"out,api,pub" json:"items"`
	Total  float64        `dto:"out,api,pub" json:"total"`
	// No business methods!
}
```

## Guide de Decision

```
DIRECTION:
  - Entree utilisateur → in
  - Sortie vers client → out
  - Update/Patch → inout

CONTEXT:
  - API REST/GraphQL → api
  - Commande CQRS → cmd
  - Query CQRS → query
  - Event sourcing → event
  - Message queue → msg
  - Interne → priv

SECURITY:
  - Nom produit, status → pub
  - IDs, timestamps → priv
  - Email, nom, adresse → pii
  - Password, token, cle → secret
```

## Comparaison avec alternatives

| Aspect | DTO | Domain Object | Map/Record |
|--------|-----|---------------|------------|
| Type safety | Forte | Forte | Faible |
| Serialisation | Facile | Complexe | Native |
| Validation | Explicite | Invariants | Manuelle |
| Logique | Aucune | Riche | Aucune |
| Versioning | Facile | Difficile | Facile |
| Groupement | Oui (dto:) | Non | N/A |

## Quand utiliser

**Utiliser DTO quand :**

- API REST/GraphQL (input/output)
- Communication entre services
- Separation domaine/presentation
- Versioning d'API
- Serialisation specifique
- Groupement de structs liees

**Eviter DTO quand :**

- Duplication excessive (1:1 avec domain)
- Applications simples/CRUD
- Performance critique (overhead mapping)

## Patterns lies

- [Remote Facade](./remote-facade.md) - Utilise DTO pour transfert coarse-grained
- [Service Layer](./service-layer.md) - Convertit domaine en DTO
- [Domain Model](./domain-model.md) - Modele source des DTOs
- [Data Mapper](./data-mapper.md) - Similaire mais pour persistance
- [CQRS](../architectural/cqrs.md) - DTOs separes pour Command/Query

## Sources

- Martin Fowler, PoEAA, Chapter 15
- [Data Transfer Object - martinfowler.com](https://martinfowler.com/eaaCatalog/dataTransferObject.html)
- [conventions/dto-tags.md](../conventions/dto-tags.md) - Convention interne
