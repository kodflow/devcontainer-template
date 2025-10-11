// Package todo provides the core domain entity for todo items.
//
// Purpose:
//   Defines the Todo entity with its business rules, validation logic,
//   and domain-specific constants for the todo management system.
//
// Responsibilities:
//   - Define Todo entity structure and behavior
//   - Provide validation rules for todo creation and updates
//   - Define status constants and flag operations
//   - Enforce business constraints
//
// Features:
//   - Domain Entity
//   - Validation
//   - Bitwise Flags
//
// Constraints:
//   - Title must be between 1-200 characters
//   - Description max 2000 characters
//   - Valid status transitions only
//   - Immutable ID after creation
//
package todo

import "context"

// Repository defines the interface for todo persistence operations.
// Implementations must be thread-safe.
type Repository interface {
	// Create stores a new todo and returns the created todo with assigned ID.
	Create(ctx context.Context, todo *Todo) (*Todo, error)

	// GetByID retrieves a todo by its unique identifier.
	GetByID(ctx context.Context, id string) (*Todo, error)

	// Update modifies an existing todo.
	Update(ctx context.Context, todo *Todo) error

	// Delete removes a todo by ID.
	Delete(ctx context.Context, id string) error

	// List retrieves todos with optional filtering and pagination.
	List(ctx context.Context, filter Filter) ([]*Todo, error)

	// Count returns the total number of todos matching the filter.
	Count(ctx context.Context, filter Filter) (int, error)
}

// Validator defines the interface for todo validation logic.
type Validator interface {
	// Validate checks if a todo meets all business rules.
	Validate(todo *Todo) error

	// ValidateTransition checks if a status transition is allowed.
	ValidateTransition(from, to string) error
}
