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

import "time"

const (
	// DefaultMaxTodos is the maximum number of todos that can be stored.
	DefaultMaxTodos = 10000

	// DefaultTimeout for repository operations.
	DefaultTimeout = 5 * time.Second

	// DefaultListLimit is the default page size for list operations.
	DefaultListLimit = 50

	// MaxListLimit is the maximum page size allowed.
	MaxListLimit = 500
)
