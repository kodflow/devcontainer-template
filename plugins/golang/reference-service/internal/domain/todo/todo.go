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

import (
	"strings"
	"time"
)

// Todo represents a task item in the todo list.
// Fields are ordered by size for memory optimization.
type Todo struct {
	CreatedAt   time.Time // 24 bytes
	UpdatedAt   time.Time // 24 bytes
	DueDate     time.Time // 24 bytes
	Description string    // 16 bytes
	Title       string    // 16 bytes
	ID          string    // 16 bytes
	Priority    string    // 16 bytes
	Status      string    // 16 bytes
	Flags       uint8     // 1 byte
}

// Filter defines query parameters for listing todos.
// Fields ordered by size.
type Filter struct {
	Statuses  []string // 24 bytes
	Priority  string   // 16 bytes
	Limit     int      // 8 bytes
	Offset    int      // 8 bytes
	FlagsAny  uint8    // 1 byte
	FlagsAll  uint8    // 1 byte
}

// NewTodo creates a new Todo with validation.
// Returns error if validation fails.
func NewTodo(title, description, priority string) (*Todo, error) {
	todo := &Todo{
		Title:       strings.TrimSpace(title),
		Description: strings.TrimSpace(description),
		Priority:    priority,
		Status:      DefaultStatus,
		Flags:       DefaultFlags,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	if err := todo.Validate(); err != nil {
		return nil, err
	}

	return todo, nil
}

// Validate checks if the Todo meets all business rules.
func (t *Todo) Validate() error {
	if len(t.Title) < MinTitleLength || len(t.Title) > MaxTitleLength {
		return ErrInvalidTitle
	}

	if len(t.Description) > MaxDescriptionLength {
		return ErrInvalidDescription
	}

	if !t.IsValidStatus() {
		return ErrInvalidStatus
	}

	if !t.IsValidPriority() {
		return ErrInvalidPriority
	}

	return nil
}

// IsValidStatus checks if the current status is valid.
func (t *Todo) IsValidStatus() bool {
	validStatuses := map[string]struct{}{
		StatusPending:   {},
		StatusActive:    {},
		StatusCompleted: {},
		StatusArchived:  {},
	}
	_, exists := validStatuses[t.Status]
	return exists
}

// IsValidPriority checks if the current priority is valid.
func (t *Todo) IsValidPriority() bool {
	validPriorities := map[string]struct{}{
		PriorityLow:      {},
		PriorityMedium:   {},
		PriorityHigh:     {},
		PriorityCritical: {},
	}
	_, exists := validPriorities[t.Priority]
	return exists
}

// SetStatus updates the status with validation.
func (t *Todo) SetStatus(newStatus string) error {
	if err := t.ValidateTransition(t.Status, newStatus); err != nil {
		return err
	}
	t.Status = newStatus
	t.UpdatedAt = time.Now()
	return nil
}

// ValidateTransition checks if a status transition is allowed.
func (t *Todo) ValidateTransition(from, to string) error {
	validTransitions := map[string]map[string]struct{}{
		StatusPending: {
			StatusActive:    {},
			StatusArchived:  {},
		},
		StatusActive: {
			StatusCompleted: {},
			StatusPending:   {},
			StatusArchived:  {},
		},
		StatusCompleted: {
			StatusArchived: {},
			StatusActive:   {},
		},
		StatusArchived: {},
	}

	allowedStates, exists := validTransitions[from]
	if !exists {
		return ErrInvalidStatus
	}

	if _, allowed := allowedStates[to]; !allowed {
		return ErrInvalidTransition
	}

	return nil
}

// HasFlag checks if a specific flag is set.
func (t *Todo) HasFlag(flag uint8) bool {
	return t.Flags&flag != 0
}

// SetFlag adds a flag to the todo.
func (t *Todo) SetFlag(flag uint8) {
	t.Flags |= flag
	t.UpdatedAt = time.Now()
}

// ClearFlag removes a flag from the todo.
func (t *Todo) ClearFlag(flag uint8) {
	t.Flags &^= flag
	t.UpdatedAt = time.Now()
}

// IsUrgent checks if the todo is marked as urgent.
func (t *Todo) IsUrgent() bool {
	return t.HasFlag(FlagUrgent)
}

// IsRecurring checks if the todo is recurring.
func (t *Todo) IsRecurring() bool {
	return t.HasFlag(FlagRecurring)
}

// HasReminder checks if the todo has a reminder set.
func (t *Todo) HasReminder() bool {
	return t.HasFlag(FlagHasReminder)
}

// IsOverdue checks if the todo is past its due date.
func (t *Todo) IsOverdue() bool {
	return !t.DueDate.IsZero() && time.Now().After(t.DueDate)
}

// Complete marks the todo as completed.
func (t *Todo) Complete() error {
	return t.SetStatus(StatusCompleted)
}

// Archive marks the todo as archived.
func (t *Todo) Archive() error {
	return t.SetStatus(StatusArchived)
}

// Activate marks the todo as active.
func (t *Todo) Activate() error {
	return t.SetStatus(StatusActive)
}
