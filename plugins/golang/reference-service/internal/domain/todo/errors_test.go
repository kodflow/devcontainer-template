package todo_test

import (
	"errors"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
)

func TestErrorMessages(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		err     error
		wantMsg string
	}{
		{
			name:    "ErrInvalidTitle",
			err:     todo.ErrInvalidTitle,
			wantMsg: "invalid title: must be between 1-200 characters",
		},
		{
			name:    "ErrInvalidDescription",
			err:     todo.ErrInvalidDescription,
			wantMsg: "invalid description: must not exceed 2000 characters",
		},
		{
			name:    "ErrInvalidStatus",
			err:     todo.ErrInvalidStatus,
			wantMsg: "invalid status: must be pending, active, completed, or archived",
		},
		{
			name:    "ErrInvalidPriority",
			err:     todo.ErrInvalidPriority,
			wantMsg: "invalid priority: must be low, medium, high, or critical",
		},
		{
			name:    "ErrInvalidTransition",
			err:     todo.ErrInvalidTransition,
			wantMsg: "invalid status transition",
		},
		{
			name:    "ErrTodoNotFound",
			err:     todo.ErrTodoNotFound,
			wantMsg: "todo not found",
		},
		{
			name:    "ErrTodoAlreadyExists",
			err:     todo.ErrTodoAlreadyExists,
			wantMsg: "todo already exists",
		},
		{
			name:    "ErrEmptyID",
			err:     todo.ErrEmptyID,
			wantMsg: "todo id cannot be empty",
		},
		{
			name:    "ErrNilTodo",
			err:     todo.ErrNilTodo,
			wantMsg: "todo cannot be nil",
		},
		{
			name:    "ErrTodoLimitExceeded",
			err:     todo.ErrTodoLimitExceeded,
			wantMsg: "todo limit exceeded",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.err.Error() != tt.wantMsg {
				t.Errorf("error message = %q, want %q", tt.err.Error(), tt.wantMsg)
			}
		})
	}
}

func TestErrorsAreDistinct(t *testing.T) {
	t.Parallel()

	allErrors := []error{
		todo.ErrInvalidTitle,
		todo.ErrInvalidDescription,
		todo.ErrInvalidStatus,
		todo.ErrInvalidPriority,
		todo.ErrInvalidTransition,
		todo.ErrTodoNotFound,
		todo.ErrTodoAlreadyExists,
		todo.ErrEmptyID,
		todo.ErrNilTodo,
		todo.ErrTodoLimitExceeded,
	}

	for i, err1 := range allErrors {
		for j, err2 := range allErrors {
			if i != j && errors.Is(err1, err2) {
				t.Errorf("errors at index %d and %d are not distinct", i, j)
			}
		}
	}
}
