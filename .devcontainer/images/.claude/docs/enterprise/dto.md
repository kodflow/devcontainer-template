# Data Transfer Object (DTO)

> "An object that carries data between processes in order to reduce the number of method calls." - Martin Fowler, PoEAA

## Concept

Le DTO est un objet simple qui transporte des donnees entre les couches ou les processus. Il n'a pas de logique metier, seulement des donnees et eventuellement des methodes de serialisation.

## Objectifs

1. **Reduire les appels** : Agreger les donnees en un seul objet
2. **Decoupler** : Separer le modele de domaine de l'API
3. **Serialisation** : Format adapte au transfert (JSON, XML)
4. **Securite** : Ne pas exposer les details internes

## Implementation Go

```go
package dto

import (
	"encoding/json"
	"fmt"
	"time"
)

// CreateOrderRequest is an input DTO.
type CreateOrderRequest struct {
	CustomerID      string                `json:"customerId" validate:"required,uuid"`
	Items           []OrderItemRequest    `json:"items" validate:"required,min=1,dive"`
	ShippingAddress AddressRequest        `json:"shippingAddress" validate:"required"`
	Notes           string                `json:"notes,omitempty" validate:"max=500"`
}

// OrderItemRequest represents an order item.
type OrderItemRequest struct {
	ProductID string `json:"productId" validate:"required,uuid"`
	Quantity  int    `json:"quantity" validate:"required,min=1,max=100"`
}

// AddressRequest represents an address.
type AddressRequest struct {
	Street     string `json:"street" validate:"required,max=200"`
	City       string `json:"city" validate:"required,max=100"`
	PostalCode string `json:"postalCode" validate:"required"`
	Country    string `json:"country" validate:"required,iso3166_1_alpha2"`
}

// OrderResponse is an output DTO.
type OrderResponse struct {
	ID                string              `json:"id"`
	Status            string              `json:"status"`
	CustomerName      string              `json:"customerName"`
	Items             []OrderItemResponse `json:"items"`
	Subtotal          float64             `json:"subtotal"`
	Tax               float64             `json:"tax"`
	Total             float64             `json:"total"`
	CreatedAt         time.Time           `json:"createdAt"`
	EstimatedDelivery time.Time           `json:"estimatedDelivery"`
}

// OrderItemResponse represents an order item response.
type OrderItemResponse struct {
	ProductID   string  `json:"productId"`
	ProductName string  `json:"productName"`
	Quantity    int     `json:"quantity"`
	UnitPrice   float64 `json:"unitPrice"`
	Subtotal    float64 `json:"subtotal"`
}

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

// OrderSummaryDTO is a lightweight DTO for listings.
type OrderSummaryDTO struct {
	ID        string    `json:"id"`
	Status    string    `json:"status"`
	Total     float64   `json:"total"`
	ItemCount int       `json:"itemCount"`
	CreatedAt time.Time `json:"createdAt"`
}

// FromDomain creates a summary DTO from domain order.
func OrderSummaryFromDomain(order *Order) *OrderSummaryDTO {
	return &OrderSummaryDTO{
		ID:        order.ID,
		Status:    order.Status,
		Total:     order.Total,
		ItemCount: len(order.Items),
		CreatedAt: order.CreatedAt,
	}
}

// OrderDetailDTO extends OrderSummaryDTO with more details.
type OrderDetailDTO struct {
	OrderSummaryDTO
	CustomerName    string              `json:"customerName"`
	CustomerEmail   string              `json:"customerEmail"`
	Items           []OrderItemResponse `json:"items"`
	ShippingAddress AddressDTO          `json:"shippingAddress"`
	BillingAddress  AddressDTO          `json:"billingAddress"`
	PaymentMethod   string              `json:"paymentMethod"`
	Notes           string              `json:"notes,omitempty"`
}

// AddressDTO represents an address DTO.
type AddressDTO struct {
	Street     string `json:"street"`
	City       string `json:"city"`
	PostalCode string `json:"postalCode"`
	Country    string `json:"country"`
}

// FromDomain creates a detail DTO from domain.
func OrderDetailFromDomain(order *Order, customer *Customer) *OrderDetailDTO {
	items := make([]OrderItemResponse, len(order.Items))
	for i, item := range order.Items {
		items[i] = OrderItemResponse{
			ProductID:   item.ProductID,
			ProductName: item.ProductName,
			Quantity:    item.Quantity,
			UnitPrice:   item.UnitPrice,
			Subtotal:    item.Subtotal,
		}
	}

	return &OrderDetailDTO{
		OrderSummaryDTO: *OrderSummaryFromDomain(order),
		CustomerName:    customer.Name,
		CustomerEmail:   customer.Email,
		Items:           items,
		ShippingAddress: AddressFromDomain(&order.ShippingAddress),
		BillingAddress:  AddressFromDomain(&order.BillingAddress),
		PaymentMethod:   order.PaymentMethod,
		Notes:           order.Notes,
	}
}

// AddressFromDomain converts domain address to DTO.
func AddressFromDomain(addr *Address) AddressDTO {
	return AddressDTO{
		Street:     addr.Street,
		City:       addr.City,
		PostalCode: addr.PostalCode,
		Country:    addr.Country,
	}
}

// PaginatedResponse represents a paginated result.
type PaginatedResponse[T any] struct {
	Items    []T `json:"items"`
	Total    int `json:"total"`
	Page     int `json:"page"`
	PageSize int `json:"pageSize"`
}

// ListOrdersQuery represents query parameters for listing orders.
type ListOrdersQuery struct {
	Status   string `json:"status,omitempty"`
	FromDate string `json:"fromDate,omitempty" validate:"omitempty,datetime=2006-01-02"`
	ToDate   string `json:"toDate,omitempty" validate:"omitempty,datetime=2006-01-02"`
	PageSize int    `json:"pageSize,omitempty" validate:"omitempty,min=1,max=100"`
	Page     int    `json:"page,omitempty" validate:"omitempty,min=1"`
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

// Domain types (for reference)
type Order struct {
	ID                string
	Status            string
	CustomerID        string
	Items             []*OrderItem
	Subtotal          float64
	Tax               float64
	Total             float64
	ShippingAddress   Address
	BillingAddress    Address
	PaymentMethod     string
	Notes             string
	CreatedAt         time.Time
	EstimatedDelivery time.Time
}

type OrderItem struct {
	ProductID   string
	ProductName string
	Quantity    int
	UnitPrice   float64
	Subtotal    float64
}

type Customer struct {
	ID    string
	Name  string
	Email string
}

type Address struct {
	Street     string
	City       string
	PostalCode string
	Country    string
}

type OrderCreationParams struct {
	CustomerID      string
	Items           []OrderItemParams
	ShippingAddress Address
	Notes           string
}

type OrderItemParams struct {
	ProductID string
	Quantity  int
}
```

## DTOs vs Domain Objects

```go
// Domain Object - Business logic, invariants
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

// DTO - No logic, just data
type OrderDTO struct {
	ID     string            `json:"id"`
	Status string            `json:"status"`
	Items  []OrderItemDTO    `json:"items"`
	Total  float64           `json:"total"`
	// No business methods!
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

## Sources

- Martin Fowler, PoEAA, Chapter 15
- [Data Transfer Object - martinfowler.com](https://martinfowler.com/eaaCatalog/dataTransferObject.html)
