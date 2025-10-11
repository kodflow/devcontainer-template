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

import "time"

// Status constants for Todo items using type-safe string enum.
const (
	StatusPending   = "pending"
	StatusActive    = "active"
	StatusCompleted = "completed"
	StatusArchived  = "archived"
)

// Priority constants for Todo items.
const (
	PriorityLow      = "low"
	PriorityMedium   = "medium"
	PriorityHigh     = "high"
	PriorityCritical = "critical"
)

// Bitwise flags for Todo features (memory optimization: 1 byte vs 3+ bytes).
const (
	FlagNone       uint8 = 0
	FlagUrgent     uint8 = 1 << 0 // 0000 0001
	FlagRecurring  uint8 = 1 << 1 // 0000 0010
	FlagHasReminder uint8 = 1 << 2 // 0000 0100
)

// Validation constraints.
const (
	MinTitleLength       = 1
	MaxTitleLength       = 200
	MaxDescriptionLength = 2000
	MinPriority          = 1
	MaxPriority          = 4
)

// Default values.
const (
	DefaultPriority     = PriorityMedium
	DefaultStatus       = StatusPending
	DefaultFlags        = FlagNone
	DefaultMaxTodoLimit = 1000
)

// Timeout and retry constants.
const (
	DefaultOperationTimeout = 5 * time.Second
	DefaultMaxRetries       = 3
	DefaultRetryDelay       = 100 * time.Millisecond
)
