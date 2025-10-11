package todo_test

import (
	"testing"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
)

func TestStatusConstants(t *testing.T) {
	t.Parallel()

	if todo.StatusPending != "pending" {
		t.Errorf("StatusPending = %q, want %q", todo.StatusPending, "pending")
	}
	if todo.StatusActive != "active" {
		t.Errorf("StatusActive = %q, want %q", todo.StatusActive, "active")
	}
	if todo.StatusCompleted != "completed" {
		t.Errorf("StatusCompleted = %q, want %q", todo.StatusCompleted, "completed")
	}
	if todo.StatusArchived != "archived" {
		t.Errorf("StatusArchived = %q, want %q", todo.StatusArchived, "archived")
	}
}

func TestPriorityConstants(t *testing.T) {
	t.Parallel()

	if todo.PriorityLow != "low" {
		t.Errorf("PriorityLow = %q, want %q", todo.PriorityLow, "low")
	}
	if todo.PriorityMedium != "medium" {
		t.Errorf("PriorityMedium = %q, want %q", todo.PriorityMedium, "medium")
	}
	if todo.PriorityHigh != "high" {
		t.Errorf("PriorityHigh = %q, want %q", todo.PriorityHigh, "high")
	}
	if todo.PriorityCritical != "critical" {
		t.Errorf("PriorityCritical = %q, want %q", todo.PriorityCritical, "critical")
	}
}

func TestFlagConstants(t *testing.T) {
	t.Parallel()

	if todo.FlagNone != 0 {
		t.Errorf("FlagNone = %d, want 0", todo.FlagNone)
	}
	if todo.FlagUrgent != 1 {
		t.Errorf("FlagUrgent = %d, want 1", todo.FlagUrgent)
	}
	if todo.FlagRecurring != 2 {
		t.Errorf("FlagRecurring = %d, want 2", todo.FlagRecurring)
	}
	if todo.FlagHasReminder != 4 {
		t.Errorf("FlagHasReminder = %d, want 4", todo.FlagHasReminder)
	}
}

func TestValidationConstants(t *testing.T) {
	t.Parallel()

	if todo.MinTitleLength != 1 {
		t.Errorf("MinTitleLength = %d, want 1", todo.MinTitleLength)
	}
	if todo.MaxTitleLength != 200 {
		t.Errorf("MaxTitleLength = %d, want 200", todo.MaxTitleLength)
	}
	if todo.MaxDescriptionLength != 2000 {
		t.Errorf("MaxDescriptionLength = %d, want 2000", todo.MaxDescriptionLength)
	}
}

func TestDefaultConstants(t *testing.T) {
	t.Parallel()

	if todo.DefaultPriority != "medium" {
		t.Errorf("DefaultPriority = %q, want %q", todo.DefaultPriority, "medium")
	}
	if todo.DefaultStatus != "pending" {
		t.Errorf("DefaultStatus = %q, want %q", todo.DefaultStatus, "pending")
	}
	if todo.DefaultFlags != 0 {
		t.Errorf("DefaultFlags = %d, want 0", todo.DefaultFlags)
	}
	if todo.DefaultMaxTodoLimit != 1000 {
		t.Errorf("DefaultMaxTodoLimit = %d, want 1000", todo.DefaultMaxTodoLimit)
	}
}

func TestTimeoutConstants(t *testing.T) {
	t.Parallel()

	if todo.DefaultOperationTimeout != 5*time.Second {
		t.Errorf("DefaultOperationTimeout = %v, want %v", todo.DefaultOperationTimeout, 5*time.Second)
	}
	if todo.DefaultMaxRetries != 3 {
		t.Errorf("DefaultMaxRetries = %d, want 3", todo.DefaultMaxRetries)
	}
	if todo.DefaultRetryDelay != 100*time.Millisecond {
		t.Errorf("DefaultRetryDelay = %v, want %v", todo.DefaultRetryDelay, 100*time.Millisecond)
	}
}
