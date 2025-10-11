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

import "errors"

var (
	// ErrNilConfig indicates that a nil configuration was provided.
	ErrNilConfig = errors.New("repository config cannot be nil")

	// ErrInvalidLimit indicates that the limit exceeds the maximum allowed.
	ErrInvalidLimit = errors.New("limit exceeds maximum allowed")
)
