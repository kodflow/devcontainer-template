# Data Mapper

> "A layer of Mappers that moves data between objects and a database while keeping them independent of each other and the mapper itself." - Martin Fowler, PoEAA

## Concept

Data Mapper est un pattern qui separe completement les objets du domaine de la logique de persistance. Les objets metier n'ont aucune connaissance de la base de donnees, et inversement.

## Principes cles

1. **Separation totale** : Domain Model ignore la DB
2. **Bidirectionnel** : Mapping domaine <-> DB dans les deux sens
3. **Encapsulation** : Le mapper connait les deux mondes
4. **Testabilite** : Domain Model testable sans DB

## Implementation Go

```go
package datamapper

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

// OrderStatus represents order status.
type OrderStatus string

const (
	OrderStatusDraft     OrderStatus = "draft"
	OrderStatusSubmitted OrderStatus = "submitted"
)

// Order is a domain model with NO database dependencies.
type Order struct {
	id         string
	customerID string
	items      []*OrderItem
	status     OrderStatus
	createdAt  time.Time
	version    int
}

// NewOrder creates a new order.
func NewOrder(customerID string) *Order {
	return &Order{
		id:         generateID(),
		customerID: customerID,
		items:      make([]*OrderItem, 0),
		status:     OrderStatusDraft,
		createdAt:  time.Now(),
		version:    1,
	}
}

// Reconstitute creates an order from DB data.
func ReconstituteOrder(
	id, customerID string,
	items []*OrderItem,
	status OrderStatus,
	createdAt time.Time,
	version int,
) *Order {
	return &Order{
		id:         id,
		customerID: customerID,
		items:      items,
		status:     status,
		createdAt:  createdAt,
		version:    version,
	}
}

// AddItem adds an item to the order.
func (o *Order) AddItem(product *Product, quantity int) error {
	if o.status != OrderStatusDraft {
		return fmt.Errorf("cannot modify non-draft order")
	}

	item := NewOrderItem(product, quantity)
	o.items = append(o.items, item)
	return nil
}

// Submit submits the order.
func (o *Order) Submit() error {
	if len(o.items) == 0 {
		return fmt.Errorf("cannot submit empty order")
	}
	o.status = OrderStatusSubmitted
	return nil
}

// Total calculates the order total.
func (o *Order) Total() float64 {
	var total float64
	for _, item := range o.items {
		total += item.Subtotal()
	}
	return total
}

// GetState exposes state for mapper (package-private ideally).
type OrderState struct {
	ID         string
	CustomerID string
	Items      []OrderItemState
	Status     OrderStatus
	CreatedAt  time.Time
	Version    int
}

// GetState returns the order state for persistence.
func (o *Order) GetState() OrderState {
	items := make([]OrderItemState, len(o.items))
	for i, item := range o.items {
		items[i] = item.GetState()
	}

	return OrderState{
		ID:         o.id,
		CustomerID: o.customerID,
		Items:      items,
		Status:     o.status,
		CreatedAt:  o.createdAt,
		Version:    o.version,
	}
}

// OrderItem represents an order item.
type OrderItem struct {
	id          string
	productID   string
	productName string
	quantity    int
	unitPrice   float64
}

// NewOrderItem creates a new order item.
func NewOrderItem(product *Product, quantity int) *OrderItem {
	return &OrderItem{
		id:          generateID(),
		productID:   product.ID,
		productName: product.Name,
		quantity:    quantity,
		unitPrice:   product.Price,
	}
}

// ReconstituteOrderItem creates an order item from DB data.
func ReconstituteOrderItem(id, productID, productName string, quantity int, unitPrice float64) *OrderItem {
	return &OrderItem{
		id:          id,
		productID:   productID,
		productName: productName,
		quantity:    quantity,
		unitPrice:   unitPrice,
	}
}

// Subtotal calculates the item subtotal.
func (i *OrderItem) Subtotal() float64 {
	return float64(i.quantity) * i.unitPrice
}

// OrderItemState represents order item state.
type OrderItemState struct {
	ID          string
	ProductID   string
	ProductName string
	Quantity    int
	UnitPrice   float64
}

// GetState returns the item state.
func (i *OrderItem) GetState() OrderItemState {
	return OrderItemState{
		ID:          i.id,
		ProductID:   i.productID,
		ProductName: i.productName,
		Quantity:    i.quantity,
		UnitPrice:   i.unitPrice,
	}
}

// OrderDataMapper translates between domain and database.
type OrderDataMapper struct {
	db             *sql.DB
	orderItemMapper *OrderItemDataMapper
}

// NewOrderDataMapper creates a new order data mapper.
func NewOrderDataMapper(db *sql.DB) *OrderDataMapper {
	return &OrderDataMapper{
		db:             db,
		orderItemMapper: NewOrderItemDataMapper(db),
	}
}

// FindByID loads an order from the database.
func (m *OrderDataMapper) FindByID(ctx context.Context, id string) (*Order, error) {
	// Query order
	var row struct {
		ID         string
		CustomerID string
		Status     string
		CreatedAt  time.Time
		Version    int
	}

	err := m.db.QueryRowContext(ctx,
		`SELECT id, customer_id, status, created_at, version FROM orders WHERE id = ?`,
		id,
	).Scan(&row.ID, &row.CustomerID, &row.Status, &row.CreatedAt, &row.Version)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("query order: %w", err)
	}

	// Load items
	items, err := m.orderItemMapper.FindByOrderID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find order items: %w", err)
	}

	// Reconstitute domain object
	return ReconstituteOrder(
		row.ID,
		row.CustomerID,
		items,
		OrderStatus(row.Status),
		row.CreatedAt,
		row.Version,
	), nil
}

// Insert inserts a new order.
func (m *OrderDataMapper) Insert(ctx context.Context, order *Order) error {
	state := order.GetState()

	_, err := m.db.ExecContext(ctx,
		`INSERT INTO orders (id, customer_id, status, created_at, version)
		 VALUES (?, ?, ?, ?, ?)`,
		state.ID, state.CustomerID, state.Status, state.CreatedAt, state.Version,
	)
	if err != nil {
		return fmt.Errorf("insert order: %w", err)
	}

	// Insert items
	for _, item := range state.Items {
		if err := m.orderItemMapper.Insert(ctx, state.ID, item); err != nil {
			return fmt.Errorf("insert order item: %w", err)
		}
	}

	return nil
}

// Update updates an existing order.
func (m *OrderDataMapper) Update(ctx context.Context, order *Order) error {
	state := order.GetState()

	// Optimistic locking
	result, err := m.db.ExecContext(ctx,
		`UPDATE orders SET status = ?, version = version + 1
		 WHERE id = ? AND version = ?`,
		state.Status, state.ID, state.Version,
	)
	if err != nil {
		return fmt.Errorf("update order: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("rows affected: %w", err)
	}
	if rows == 0 {
		return fmt.Errorf("optimistic lock: order was modified by another process")
	}

	// Update items (simple: delete and reinsert)
	if err := m.orderItemMapper.DeleteByOrderID(ctx, state.ID); err != nil {
		return fmt.Errorf("delete order items: %w", err)
	}

	for _, item := range state.Items {
		if err := m.orderItemMapper.Insert(ctx, state.ID, item); err != nil {
			return fmt.Errorf("insert order item: %w", err)
		}
	}

	return nil
}

// Delete deletes an order.
func (m *OrderDataMapper) Delete(ctx context.Context, id string) error {
	if err := m.orderItemMapper.DeleteByOrderID(ctx, id); err != nil {
		return fmt.Errorf("delete order items: %w", err)
	}

	_, err := m.db.ExecContext(ctx, `DELETE FROM orders WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("delete order: %w", err)
	}

	return nil
}

// OrderItemDataMapper handles order item persistence.
type OrderItemDataMapper struct {
	db *sql.DB
}

// NewOrderItemDataMapper creates a new order item mapper.
func NewOrderItemDataMapper(db *sql.DB) *OrderItemDataMapper {
	return &OrderItemDataMapper{db: db}
}

// FindByOrderID loads order items.
func (m *OrderItemDataMapper) FindByOrderID(ctx context.Context, orderID string) ([]*OrderItem, error) {
	rows, err := m.db.QueryContext(ctx,
		`SELECT id, product_id, product_name, quantity, unit_price
		 FROM order_items WHERE order_id = ?`,
		orderID,
	)
	if err != nil {
		return nil, fmt.Errorf("query order items: %w", err)
	}
	defer rows.Close()

	var items []*OrderItem
	for rows.Next() {
		var (
			id          string
			productID   string
			productName string
			quantity    int
			unitPrice   float64
		)

		if err := rows.Scan(&id, &productID, &productName, &quantity, &unitPrice); err != nil {
			return nil, fmt.Errorf("scan order item: %w", err)
		}

		items = append(items, ReconstituteOrderItem(id, productID, productName, quantity, unitPrice))
	}

	return items, rows.Err()
}

// Insert inserts an order item.
func (m *OrderItemDataMapper) Insert(ctx context.Context, orderID string, item OrderItemState) error {
	_, err := m.db.ExecContext(ctx,
		`INSERT INTO order_items (id, order_id, product_id, product_name, quantity, unit_price)
		 VALUES (?, ?, ?, ?, ?, ?)`,
		item.ID, orderID, item.ProductID, item.ProductName, item.Quantity, item.UnitPrice,
	)
	return err
}

// DeleteByOrderID deletes all items for an order.
func (m *OrderItemDataMapper) DeleteByOrderID(ctx context.Context, orderID string) error {
	_, err := m.db.ExecContext(ctx, `DELETE FROM order_items WHERE order_id = ?`, orderID)
	return err
}

// Helper types
type Product struct {
	ID    string
	Name  string
	Price float64
}

func generateID() string {
	return fmt.Sprintf("id-%d", time.Now().UnixNano())
}
```

## Comparaison avec alternatives

| Aspect | Data Mapper | Active Record | Table Data Gateway |
|--------|-------------|---------------|-------------------|
| Couplage domaine-DB | Aucun | Fort | Moyen |
| Complexite | Elevee | Faible | Faible |
| Testabilite domaine | Excellente | Moyenne | N/A |
| ORM integration | Naturelle | Native | Manuelle |
| Domain Model rich | Oui | Difficile | Non |

## Quand utiliser

**Utiliser Data Mapper quand :**

- Domain Model riche avec logique complexe
- Tests unitaires du domaine sans DB
- Schema DB different du modele objet
- Multiple sources de donnees
- ORM (sqlx, ent, etc.)

**Eviter Data Mapper quand :**

- CRUD simple
- Schema DB = modele objet
- Performance critique (overhead mapping)
- Equipe non familiere avec le pattern

## Sources

- Martin Fowler, PoEAA, Chapter 10
- [Data Mapper - martinfowler.com](https://martinfowler.com/eaaCatalog/dataMapper.html)
