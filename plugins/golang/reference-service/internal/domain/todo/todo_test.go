package todo_test

import (
	"strings"
	"testing"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
)

func TestNewTodo_Success(t *testing.T) {
	t.Parallel()

	td, err := todo.NewTodo("Buy groceries", "Milk, eggs, bread", todo.PriorityMedium)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if td == nil {
		t.Fatal("expected todo to be created, got nil")
	}

	if td.Title != "Buy groceries" {
		t.Errorf("expected title 'Buy groceries', got '%s'", td.Title)
	}

	if td.Status != todo.StatusPending {
		t.Errorf("expected status '%s', got '%s'", todo.StatusPending, td.Status)
	}

	if td.Flags != todo.DefaultFlags {
		t.Errorf("expected flags %d, got %d", todo.DefaultFlags, td.Flags)
	}
}

func TestNewTodo_InvalidTitle_TooShort(t *testing.T) {
	t.Parallel()

	_, err := todo.NewTodo("", "Description", todo.PriorityLow)
	if err != todo.ErrInvalidTitle {
		t.Errorf("expected ErrInvalidTitle, got %v", err)
	}
}

func TestNewTodo_InvalidTitle_TooLong(t *testing.T) {
	t.Parallel()

	longTitle := strings.Repeat("a", 201)
	_, err := todo.NewTodo(longTitle, "Description", todo.PriorityHigh)
	if err != todo.ErrInvalidTitle {
		t.Errorf("expected ErrInvalidTitle, got %v", err)
	}
}

func TestNewTodo_InvalidDescription_TooLong(t *testing.T) {
	t.Parallel()

	longDesc := strings.Repeat("a", 2001)
	_, err := todo.NewTodo("Valid title", longDesc, todo.PriorityLow)
	if err != todo.ErrInvalidDescription {
		t.Errorf("expected ErrInvalidDescription, got %v", err)
	}
}

func TestNewTodo_InvalidPriority(t *testing.T) {
	t.Parallel()

	_, err := todo.NewTodo("Valid title", "Valid desc", "invalid")
	if err != todo.ErrInvalidPriority {
		t.Errorf("expected ErrInvalidPriority, got %v", err)
	}
}

func TestTodo_Validate_Success(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{
		Title:       "Valid title",
		Description: "Valid description",
		Priority:    todo.PriorityMedium,
		Status:      todo.StatusPending,
	}

	if err := td.Validate(); err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestTodo_IsValidStatus(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name   string
		status string
		want   bool
	}{
		{"pending", todo.StatusPending, true},
		{"active", todo.StatusActive, true},
		{"completed", todo.StatusCompleted, true},
		{"archived", todo.StatusArchived, true},
		{"invalid", "invalid", false},
		{"empty", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			td := &todo.Todo{Status: tt.status}
			if got := td.IsValidStatus(); got != tt.want {
				t.Errorf("IsValidStatus() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestTodo_IsValidPriority(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name     string
		priority string
		want     bool
	}{
		{"low", todo.PriorityLow, true},
		{"medium", todo.PriorityMedium, true},
		{"high", todo.PriorityHigh, true},
		{"critical", todo.PriorityCritical, true},
		{"invalid", "invalid", false},
		{"empty", "", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			td := &todo.Todo{Priority: tt.priority}
			if got := td.IsValidPriority(); got != tt.want {
				t.Errorf("IsValidPriority() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestTodo_SetStatus_Success(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{
		Status:    todo.StatusPending,
		UpdatedAt: time.Now().Add(-1 * time.Hour),
	}

	oldTime := td.UpdatedAt
	time.Sleep(1 * time.Millisecond)

	if err := td.SetStatus(todo.StatusActive); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if td.Status != todo.StatusActive {
		t.Errorf("expected status '%s', got '%s'", todo.StatusActive, td.Status)
	}

	if !td.UpdatedAt.After(oldTime) {
		t.Error("expected UpdatedAt to be updated")
	}
}

func TestTodo_SetStatus_InvalidTransition(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Status: todo.StatusArchived}

	err := td.SetStatus(todo.StatusPending)
	if err != todo.ErrInvalidTransition {
		t.Errorf("expected ErrInvalidTransition, got %v", err)
	}
}

func TestTodo_ValidateTransition(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		from    string
		to      string
		wantErr error
	}{
		{"pending to active", todo.StatusPending, todo.StatusActive, nil},
		{"active to completed", todo.StatusActive, todo.StatusCompleted, nil},
		{"completed to archived", todo.StatusCompleted, todo.StatusArchived, nil},
		{"archived to pending", todo.StatusArchived, todo.StatusPending, todo.ErrInvalidTransition},
		{"pending to completed", todo.StatusPending, todo.StatusCompleted, todo.ErrInvalidTransition},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			td := &todo.Todo{Status: tt.from}
			err := td.ValidateTransition(tt.from, tt.to)
			if err != tt.wantErr {
				t.Errorf("ValidateTransition() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestTodo_HasFlag(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Flags: todo.FlagUrgent | todo.FlagRecurring}

	if !td.HasFlag(todo.FlagUrgent) {
		t.Error("expected HasFlag(FlagUrgent) to be true")
	}

	if !td.HasFlag(todo.FlagRecurring) {
		t.Error("expected HasFlag(FlagRecurring) to be true")
	}

	if td.HasFlag(todo.FlagHasReminder) {
		t.Error("expected HasFlag(FlagHasReminder) to be false")
	}
}

func TestTodo_SetFlag(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{
		Flags:     todo.FlagNone,
		UpdatedAt: time.Now().Add(-1 * time.Hour),
	}

	oldTime := td.UpdatedAt
	time.Sleep(1 * time.Millisecond)

	td.SetFlag(todo.FlagUrgent)

	if !td.HasFlag(todo.FlagUrgent) {
		t.Error("expected FlagUrgent to be set")
	}

	if !td.UpdatedAt.After(oldTime) {
		t.Error("expected UpdatedAt to be updated")
	}
}

func TestTodo_ClearFlag(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{
		Flags:     todo.FlagUrgent | todo.FlagRecurring,
		UpdatedAt: time.Now().Add(-1 * time.Hour),
	}

	oldTime := td.UpdatedAt
	time.Sleep(1 * time.Millisecond)

	td.ClearFlag(todo.FlagUrgent)

	if td.HasFlag(todo.FlagUrgent) {
		t.Error("expected FlagUrgent to be cleared")
	}

	if !td.HasFlag(todo.FlagRecurring) {
		t.Error("expected FlagRecurring to still be set")
	}

	if !td.UpdatedAt.After(oldTime) {
		t.Error("expected UpdatedAt to be updated")
	}
}

func TestTodo_IsUrgent(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Flags: todo.FlagUrgent}
	if !td.IsUrgent() {
		t.Error("expected IsUrgent() to be true")
	}

	td.Flags = todo.FlagNone
	if td.IsUrgent() {
		t.Error("expected IsUrgent() to be false")
	}
}

func TestTodo_IsRecurring(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Flags: todo.FlagRecurring}
	if !td.IsRecurring() {
		t.Error("expected IsRecurring() to be true")
	}

	td.Flags = todo.FlagNone
	if td.IsRecurring() {
		t.Error("expected IsRecurring() to be false")
	}
}

func TestTodo_HasReminder(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Flags: todo.FlagHasReminder}
	if !td.HasReminder() {
		t.Error("expected HasReminder() to be true")
	}

	td.Flags = todo.FlagNone
	if td.HasReminder() {
		t.Error("expected HasReminder() to be false")
	}
}

func TestTodo_IsOverdue(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{DueDate: time.Now().Add(-1 * time.Hour)}
	if !td.IsOverdue() {
		t.Error("expected IsOverdue() to be true")
	}

	td.DueDate = time.Now().Add(1 * time.Hour)
	if td.IsOverdue() {
		t.Error("expected IsOverdue() to be false")
	}

	td.DueDate = time.Time{}
	if td.IsOverdue() {
		t.Error("expected IsOverdue() to be false for zero time")
	}
}

func TestTodo_Complete(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Status: todo.StatusActive}

	if err := td.Complete(); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if td.Status != todo.StatusCompleted {
		t.Errorf("expected status '%s', got '%s'", todo.StatusCompleted, td.Status)
	}
}

func TestTodo_Archive(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Status: todo.StatusCompleted}

	if err := td.Archive(); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if td.Status != todo.StatusArchived {
		t.Errorf("expected status '%s', got '%s'", todo.StatusArchived, td.Status)
	}
}

func TestTodo_Activate(t *testing.T) {
	t.Parallel()

	td := &todo.Todo{Status: todo.StatusPending}

	if err := td.Activate(); err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if td.Status != todo.StatusActive {
		t.Errorf("expected status '%s', got '%s'", todo.StatusActive, td.Status)
	}
}
