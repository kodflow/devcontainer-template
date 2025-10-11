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

import "errors"

// Domain errors for Todo operations.
var (
	// ErrInvalidTitle indicates the title does not meet requirements.
	ErrInvalidTitle = errors.New("invalid title: must be between 1-200 characters")

	// ErrInvalidDescription indicates the description exceeds max length.
	ErrInvalidDescription = errors.New("invalid description: must not exceed 2000 characters")

	// ErrInvalidStatus indicates an unknown or invalid status value.
	ErrInvalidStatus = errors.New("invalid status: must be pending, active, completed, or archived")

	// ErrInvalidPriority indicates an unknown or invalid priority value.
	ErrInvalidPriority = errors.New("invalid priority: must be low, medium, high, or critical")

	// ErrInvalidTransition indicates an illegal status transition.
	ErrInvalidTransition = errors.New("invalid status transition")

	// ErrTodoNotFound indicates the requested todo does not exist.
	ErrTodoNotFound = errors.New("todo not found")

	// ErrTodoAlreadyExists indicates a todo with the same ID already exists.
	ErrTodoAlreadyExists = errors.New("todo already exists")

	// ErrEmptyID indicates an operation was attempted with an empty ID.
	ErrEmptyID = errors.New("todo id cannot be empty")

	// ErrNilTodo indicates a nil todo pointer was provided.
	ErrNilTodo = errors.New("todo cannot be nil")

	// ErrTodoLimitExceeded indicates the maximum number of todos has been reached.
	ErrTodoLimitExceeded = errors.New("todo limit exceeded")
)
