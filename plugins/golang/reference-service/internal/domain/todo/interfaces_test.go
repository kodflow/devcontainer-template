package todo_test

import (
	"context"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
)

// mockRepository is a mock implementation of todo.Repository for testing.
type mockRepository struct {
	createFunc func(ctx context.Context, t *todo.Todo) (*todo.Todo, error)
	getByIDFunc func(ctx context.Context, id string) (*todo.Todo, error)
	updateFunc func(ctx context.Context, t *todo.Todo) error
	deleteFunc func(ctx context.Context, id string) error
	listFunc   func(ctx context.Context, filter todo.Filter) ([]*todo.Todo, error)
	countFunc  func(ctx context.Context, filter todo.Filter) (int, error)
}

func (m *mockRepository) Create(ctx context.Context, t *todo.Todo) (*todo.Todo, error) {
	if m.createFunc != nil {
		return m.createFunc(ctx, t)
	}
	return t, nil
}

func (m *mockRepository) GetByID(ctx context.Context, id string) (*todo.Todo, error) {
	if m.getByIDFunc != nil {
		return m.getByIDFunc(ctx, id)
	}
	return nil, todo.ErrTodoNotFound
}

func (m *mockRepository) Update(ctx context.Context, t *todo.Todo) error {
	if m.updateFunc != nil {
		return m.updateFunc(ctx, t)
	}
	return nil
}

func (m *mockRepository) Delete(ctx context.Context, id string) error {
	if m.deleteFunc != nil {
		return m.deleteFunc(ctx, id)
	}
	return nil
}

func (m *mockRepository) List(ctx context.Context, filter todo.Filter) ([]*todo.Todo, error) {
	if m.listFunc != nil {
		return m.listFunc(ctx, filter)
	}
	return []*todo.Todo{}, nil
}

func (m *mockRepository) Count(ctx context.Context, filter todo.Filter) (int, error) {
	if m.countFunc != nil {
		return m.countFunc(ctx, filter)
	}
	return 0, nil
}

// mockValidator is a mock implementation of todo.Validator for testing.
type mockValidator struct {
	validateFunc           func(t *todo.Todo) error
	validateTransitionFunc func(from, to string) error
}

func (m *mockValidator) Validate(t *todo.Todo) error {
	if m.validateFunc != nil {
		return m.validateFunc(t)
	}
	return nil
}

func (m *mockValidator) ValidateTransition(from, to string) error {
	if m.validateTransitionFunc != nil {
		return m.validateTransitionFunc(from, to)
	}
	return nil
}
