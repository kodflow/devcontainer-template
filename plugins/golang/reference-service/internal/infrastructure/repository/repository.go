// Package repository provides in-memory storage implementation for todos.
//
// Purpose:
//   Implements the todo.Repository interface with thread-safe in-memory storage.
//
// Responsibilities:
//   - Store and retrieve todos from memory
//   - Provide CRUD operations with concurrency safety
//   - Filter and paginate todo lists
//
// Features:
//   - Database (in-memory)
//   - Concurrency Control
//
// Constraints:
//   - Data is not persisted across restarts
//   - Limited by available memory
//   - Maximum 10000 todos per repository instance
//
package repository

import (
	"context"
	"sync"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
	"github.com/google/uuid"
)

// Repository implements todo.Repository with in-memory storage.
// Fields ordered by size for memory optimization.
type Repository struct {
	todos map[string]*todo.Todo
	mu    sync.RWMutex
	idGen IDGenerator
	limit int
}

// Config holds configuration for creating a new Repository.
type Config struct {
	IDGenerator IDGenerator
	MaxTodos    int
}

// NewRepository creates a new Repository with the given configuration.
func NewRepository(cfg Config) (*Repository, error) {
	if cfg.IDGenerator == nil {
		cfg.IDGenerator = &uuidGenerator{}
	}

	if cfg.MaxTodos <= 0 {
		cfg.MaxTodos = DefaultMaxTodos
	}

	return &Repository{
		todos: make(map[string]*todo.Todo, cfg.MaxTodos),
		idGen: cfg.IDGenerator,
		limit: cfg.MaxTodos,
	}, nil
}

// Create stores a new todo and assigns it a unique ID.
func (r *Repository) Create(ctx context.Context, t *todo.Todo) (*todo.Todo, error) {
	if t == nil {
		return nil, todo.ErrNilTodo
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if len(r.todos) >= r.limit {
		return nil, todo.ErrTodoLimitExceeded
	}

	t.ID = r.idGen.Generate()
	r.todos[t.ID] = t

	return t, nil
}

// GetByID retrieves a todo by its ID.
func (r *Repository) GetByID(ctx context.Context, id string) (*todo.Todo, error) {
	if id == "" {
		return nil, todo.ErrEmptyID
	}

	r.mu.RLock()
	defer r.mu.RUnlock()

	t, exists := r.todos[id]
	if !exists {
		return nil, todo.ErrTodoNotFound
	}

	return t, nil
}

// Update modifies an existing todo.
func (r *Repository) Update(ctx context.Context, t *todo.Todo) error {
	if t == nil {
		return todo.ErrNilTodo
	}

	if t.ID == "" {
		return todo.ErrEmptyID
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.todos[t.ID]; !exists {
		return todo.ErrTodoNotFound
	}

	r.todos[t.ID] = t
	return nil
}

// Delete removes a todo by ID.
func (r *Repository) Delete(ctx context.Context, id string) error {
	if id == "" {
		return todo.ErrEmptyID
	}

	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.todos[id]; !exists {
		return todo.ErrTodoNotFound
	}

	delete(r.todos, id)
	return nil
}

// List retrieves todos matching the filter with pagination.
func (r *Repository) List(ctx context.Context, filter todo.Filter) ([]*todo.Todo, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	results := make([]*todo.Todo, 0, filter.Limit)
	skipped := 0

	for _, t := range r.todos {
		if !r.matchesFilter(t, filter) {
			continue
		}

		if skipped < filter.Offset {
			skipped++
			continue
		}

		if len(results) >= filter.Limit {
			break
		}

		results = append(results, t)
	}

	return results, nil
}

// Count returns the number of todos matching the filter.
func (r *Repository) Count(ctx context.Context, filter todo.Filter) (int, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	count := 0
	for _, t := range r.todos {
		if r.matchesFilter(t, filter) {
			count++
		}
	}

	return count, nil
}

func (r *Repository) matchesFilter(t *todo.Todo, filter todo.Filter) bool {
	if len(filter.Statuses) > 0 {
		found := false
		for _, status := range filter.Statuses {
			if t.Status == status {
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	if filter.Priority != "" && t.Priority != filter.Priority {
		return false
	}

	if filter.FlagsAll != 0 && t.Flags&filter.FlagsAll != filter.FlagsAll {
		return false
	}

	if filter.FlagsAny != 0 && t.Flags&filter.FlagsAny == 0 {
		return false
	}

	return true
}

// uuidGenerator implements IDGenerator using Google's UUID library.
type uuidGenerator struct{}

func (g *uuidGenerator) Generate() string {
	return uuid.New().String()
}
