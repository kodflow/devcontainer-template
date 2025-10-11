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

// IDGenerator defines the interface for generating unique IDs.
type IDGenerator interface {
	// Generate creates a new unique identifier.
	Generate() string
}
