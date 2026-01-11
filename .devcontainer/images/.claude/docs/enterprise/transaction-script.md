# Transaction Script

> "Organizes business logic by procedures where each procedure handles a single request from the presentation." - Martin Fowler, PoEAA

## Concept

Transaction Script est le pattern le plus simple pour organiser la logique metier. Chaque operation metier est implementee comme une procedure unique qui execute toutes les etapes de la transaction de bout en bout.

## Caracteristiques

- **Procedurale** : Code organise par transactions, pas par objets
- **Directe** : Lecture lineaire du flux de donnees
- **Simple** : Pas d'abstraction complexe
- **Autonome** : Chaque script est independant

## Implementation Go

```go
package orderscripts

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// OrderTransactionScripts handles order operations.
type OrderTransactionScripts struct {
	db             *sql.DB
	emailService   EmailService
	paymentGateway PaymentGateway
}

// NewOrderTransactionScripts creates a new order scripts handler.
func NewOrderTransactionScripts(
	db *sql.DB,
	emailService EmailService,
	paymentGateway PaymentGateway,
) *OrderTransactionScripts {
	return &OrderTransactionScripts{
		db:             db,
		emailService:   emailService,
		paymentGateway: paymentGateway,
	}
}

// OrderItem represents an order item.
type OrderItem struct {
	ProductID string
	Quantity  int
	Price     float64
	Name      string
}

// PaymentMethod represents a payment method.
type PaymentMethod struct {
	Type  string
	Token string
}

// PlaceOrder places a complete order in a single transaction script.
func (s *OrderTransactionScripts) PlaceOrder(
	ctx context.Context,
	customerID string,
	items []struct {
		ProductID string
		Quantity  int
	},
	paymentMethod PaymentMethod,
) (string, error) {
	// 1. Validate customer
	customer, err := s.getCustomer(ctx, customerID)
	if err != nil {
		return "", fmt.Errorf("get customer: %w", err)
	}
	if customer == nil || !customer.Active {
		return "", fmt.Errorf("customer not found or inactive")
	}

	// 2. Verify stock and calculate total
	var totalAmount float64
	orderItems := make([]OrderItem, 0, len(items))

	for _, item := range items {
		product, err := s.getProduct(ctx, item.ProductID)
		if err != nil {
			return "", fmt.Errorf("get product %s: %w", item.ProductID, err)
		}
		if product == nil {
			return "", fmt.Errorf("product %s not found", item.ProductID)
		}
		if product.Stock < item.Quantity {
			return "", fmt.Errorf("insufficient stock for %s", product.Name)
		}

		totalAmount += product.Price * float64(item.Quantity)
		orderItems = append(orderItems, OrderItem{
			ProductID: item.ProductID,
			Quantity:  item.Quantity,
			Price:     product.Price,
			Name:      product.Name,
		})
	}

	// 3. Apply discount
	discount, err := s.calculateDiscount(ctx, customerID, totalAmount)
	if err != nil {
		return "", fmt.Errorf("calculate discount: %w", err)
	}
	finalAmount := totalAmount - discount

	// 4. Process payment
	paymentResult, err := s.paymentGateway.Charge(ctx, paymentMethod, finalAmount)
	if err != nil {
		return "", fmt.Errorf("payment gateway: %w", err)
	}
	if !paymentResult.Success {
		return "", fmt.Errorf("payment failed: %s", paymentResult.Error)
	}

	// 5. Create order and update stock
	orderID := uuid.New().String()

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return "", fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback()

	// Insert order
	_, err = tx.ExecContext(ctx,
		`INSERT INTO orders (id, customer_id, total, status, created_at)
		 VALUES (?, ?, ?, 'confirmed', ?)`,
		orderID, customerID, finalAmount, time.Now(),
	)
	if err != nil {
		return "", fmt.Errorf("insert order: %w", err)
	}

	// Insert order items and update stock
	for _, item := range orderItems {
		_, err = tx.ExecContext(ctx,
			`INSERT INTO order_items (order_id, product_id, quantity, price)
			 VALUES (?, ?, ?, ?)`,
			orderID, item.ProductID, item.Quantity, item.Price,
		)
		if err != nil {
			return "", fmt.Errorf("insert order item: %w", err)
		}

		_, err = tx.ExecContext(ctx,
			`UPDATE products SET stock = stock - ? WHERE id = ?`,
			item.Quantity, item.ProductID,
		)
		if err != nil {
			return "", fmt.Errorf("update stock: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return "", fmt.Errorf("commit transaction: %w", err)
	}

	// 6. Send confirmation
	if err := s.emailService.SendOrderConfirmation(ctx, customer.Email, OrderConfirmation{
		OrderID: orderID,
		Items:   orderItems,
		Total:   finalAmount,
	}); err != nil {
		// Log error but don't fail the order
		fmt.Printf("failed to send email: %v\n", err)
	}

	return orderID, nil
}

// CancelOrder cancels an order.
func (s *OrderTransactionScripts) CancelOrder(ctx context.Context, orderID, reason string) error {
	// Get order
	order, err := s.getOrder(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order: %w", err)
	}
	if order == nil {
		return fmt.Errorf("order not found")
	}
	if order.Status == "shipped" {
		return fmt.Errorf("cannot cancel shipped order")
	}

	// Refund payment
	if order.PaymentID != "" {
		if err := s.paymentGateway.Refund(ctx, order.PaymentID); err != nil {
			return fmt.Errorf("refund payment: %w", err)
		}
	}

	// Restore stock
	items, err := s.getOrderItems(ctx, orderID)
	if err != nil {
		return fmt.Errorf("get order items: %w", err)
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin transaction: %w", err)
	}
	defer tx.Rollback()

	for _, item := range items {
		_, err = tx.ExecContext(ctx,
			`UPDATE products SET stock = stock + ? WHERE id = ?`,
			item.Quantity, item.ProductID,
		)
		if err != nil {
			return fmt.Errorf("restore stock: %w", err)
		}
	}

	_, err = tx.ExecContext(ctx,
		`UPDATE orders SET status = ?, cancelled_reason = ? WHERE id = ?`,
		"cancelled", reason, orderID,
	)
	if err != nil {
		return fmt.Errorf("update order: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit transaction: %w", err)
	}

	return nil
}

func (s *OrderTransactionScripts) calculateDiscount(ctx context.Context, customerID string, amount float64) (float64, error) {
	var count int
	err := s.db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM orders WHERE customer_id = ?`,
		customerID,
	).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("query order count: %w", err)
	}

	// 10% for loyal customers (10+ orders)
	if count >= 10 {
		return amount * 0.1, nil
	}
	return 0, nil
}

// Helper types and functions
type Customer struct {
	ID     string
	Email  string
	Active bool
}

type Product struct {
	ID    string
	Name  string
	Price float64
	Stock int
}

type Order struct {
	ID        string
	Status    string
	PaymentID string
}

type OrderConfirmation struct {
	OrderID string
	Items   []OrderItem
	Total   float64
}

func (s *OrderTransactionScripts) getCustomer(ctx context.Context, id string) (*Customer, error) {
	var c Customer
	err := s.db.QueryRowContext(ctx,
		`SELECT id, email, active FROM customers WHERE id = ?`, id,
	).Scan(&c.ID, &c.Email, &c.Active)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (s *OrderTransactionScripts) getProduct(ctx context.Context, id string) (*Product, error) {
	var p Product
	err := s.db.QueryRowContext(ctx,
		`SELECT id, name, price, stock FROM products WHERE id = ?`, id,
	).Scan(&p.ID, &p.Name, &p.Price, &p.Stock)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (s *OrderTransactionScripts) getOrder(ctx context.Context, id string) (*Order, error) {
	var o Order
	err := s.db.QueryRowContext(ctx,
		`SELECT id, status, payment_id FROM orders WHERE id = ?`, id,
	).Scan(&o.ID, &o.Status, &o.PaymentID)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &o, nil
}

func (s *OrderTransactionScripts) getOrderItems(ctx context.Context, orderID string) ([]OrderItem, error) {
	rows, err := s.db.QueryContext(ctx,
		`SELECT product_id, quantity, price, name FROM order_items WHERE order_id = ?`,
		orderID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []OrderItem
	for rows.Next() {
		var item OrderItem
		if err := rows.Scan(&item.ProductID, &item.Quantity, &item.Price, &item.Name); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

// EmailService sends emails.
type EmailService interface {
	SendOrderConfirmation(ctx context.Context, email string, confirmation OrderConfirmation) error
}

// PaymentGateway processes payments.
type PaymentGateway interface {
	Charge(ctx context.Context, method PaymentMethod, amount float64) (*PaymentResult, error)
	Refund(ctx context.Context, paymentID string) error
}

// PaymentResult represents a payment result.
type PaymentResult struct {
	Success bool
	Error   string
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

Transaction Script est souvent considere comme l'**antithese du DDD**.

## Patterns liés

- [Domain Model](./domain-model.md) - Alternative pour logique metier complexe
- [Service Layer](./service-layer.md) - Coordination au-dessus de Transaction Script
- [Table Data Gateway](./gateway.md) - Acces aux donnees simplifie
- [Active Record](./active-record.md) - Alternative avec persistance integree

## Sources

- Martin Fowler, PoEAA, Chapter 9: Domain Logic Patterns
- [Transaction Script - martinfowler.com](https://martinfowler.com/eaaCatalog/transactionScript.html)
