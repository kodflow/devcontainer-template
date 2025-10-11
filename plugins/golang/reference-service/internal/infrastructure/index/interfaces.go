// Package index provides indexing capabilities for fast todo lookups.
//
// Purpose:
//   Implements status-based indexing for efficient todo queries.
//
// Responsibilities:
//   - Index todos by status
//   - Fast status-based lookups
//   - Maintain index consistency
//
// Features:
//   - Indexing
//   - Fast Lookups
//
// Constraints:
//   - Index must be kept in sync with storage
//   - Maximum 10000 todos per status
//
package index

// Index defines the interface for todo indexing operations.
//
// Implementations must be thread-safe and maintain consistency with
// the underlying storage. The index should be updated atomically
// with storage operations to prevent desynchronization.
type Index interface {
	// Add indexes a todo by its ID under the given status.
	//
	// The operation is idempotent - adding the same ID multiple times
	// has no additional effect. Thread-safe using write lock.
	//
	// Parameters:
	//   - id: Todo unique identifier (must not be empty)
	//   - status: Status value to index under (must not be empty)
	//
	// Example:
	//   idx.Add("todo-123", todo.StatusActive)
	Add(id, status string)

	// Remove removes a todo ID from the status index.
	//
	// If the ID doesn't exist in the index, the operation is a no-op.
	// Thread-safe using write lock.
	//
	// Parameters:
	//   - id: Todo unique identifier to remove
	//   - status: Status index to remove from
	//
	// Example:
	//   idx.Remove("todo-123", todo.StatusActive)
	Remove(id, status string)

	// GetByStatus retrieves all todo IDs with the given status.
	//
	// Returns a new slice containing all IDs. The slice is safe to modify
	// without affecting the index. Thread-safe using read lock.
	//
	// Parameters:
	//   - status: Status value to query
	//
	// Returns:
	//   - []string: Slice of todo IDs (empty if status not found)
	//
	// Example:
	//   activeIDs := idx.GetByStatus(todo.StatusActive)
	//   for _, id := range activeIDs {
	//       // process active todo
	//   }
	GetByStatus(status string) []string

	// Count returns the number of todos indexed under the given status.
	//
	// Thread-safe using read lock. O(1) complexity.
	//
	// Parameters:
	//   - status: Status value to count
	//
	// Returns:
	//   - int: Number of todos with this status (0 if status not found)
	//
	// Example:
	//   count := idx.Count(todo.StatusActive)
	//   fmt.Printf("Active todos: %d\n", count)
	Count(status string) int
}
