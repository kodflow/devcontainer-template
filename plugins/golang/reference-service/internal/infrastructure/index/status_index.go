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

import (
	"sync"
)

// StatusIndex implements fast status-based lookups for todos using map[string]struct{}.
//
// Fields:
//   - index: Two-level map: status -> set of todo IDs
//     Uses map[string]struct{} for zero-byte memory-efficient sets
//   - mu: Read-write mutex for thread-safe concurrent access
//
// Thread Safety:
//   All methods are thread-safe using RWMutex.
//   Multiple readers can access simultaneously, writes are exclusive.
//
// Memory:
//   Uses map[T]struct{} pattern for zero-byte sets (only keys consume memory).
//   Fields ordered by size for memory alignment.
type StatusIndex struct {
	index map[string]map[string]struct{}
	mu    sync.RWMutex
}

// NewStatusIndex creates a new empty StatusIndex ready for use.
//
// The index is initialized with an empty map and requires no configuration.
// All operations are thread-safe from first use.
//
// Returns:
//   - *StatusIndex: New index instance with no initial data
//
// Example:
//   idx := NewStatusIndex()
//   idx.Add("todo-1", todo.StatusActive)
//   count := idx.Count(todo.StatusActive) // returns 1
func NewStatusIndex() *StatusIndex {
	return &StatusIndex{
		index: make(map[string]map[string]struct{}),
	}
}

// Add indexes a todo ID under the specified status.
//
// The operation is idempotent - adding the same ID multiple times has no effect.
// If the status doesn't exist in the index, it's created automatically.
// Thread-safe using write lock.
//
// Parameters:
//   - id: Todo unique identifier (must not be empty)
//   - status: Status value to index under (e.g., "pending", "active")
//
// Example:
//   idx.Add("todo-123", todo.StatusActive)
//   idx.Add("todo-124", todo.StatusActive) // same status, different ID
//   idx.Add("todo-123", todo.StatusActive) // idempotent, no change
func (si *StatusIndex) Add(id, status string) {
	si.mu.Lock()
	defer si.mu.Unlock()

	if si.index[status] == nil {
		si.index[status] = make(map[string]struct{})
	}

	si.index[status][id] = struct{}{}
}

// Remove removes a todo ID from the specified status index.
//
// If the ID doesn't exist in the status index, the operation is a no-op.
// If the status doesn't exist, the operation is also a no-op.
// Thread-safe using write lock.
//
// Parameters:
//   - id: Todo unique identifier to remove
//   - status: Status index to remove from
//
// Example:
//   idx.Add("todo-123", todo.StatusActive)
//   idx.Remove("todo-123", todo.StatusActive) // removes from index
//   idx.Remove("todo-999", todo.StatusActive) // no-op, ID doesn't exist
func (si *StatusIndex) Remove(id, status string) {
	si.mu.Lock()
	defer si.mu.Unlock()

	if si.index[status] != nil {
		delete(si.index[status], id)
	}
}

// GetByStatus retrieves all todo IDs indexed under the specified status.
//
// Returns a new slice containing all IDs. The slice is safe to modify
// without affecting the internal index. If the status doesn't exist,
// returns an empty slice (not nil).
// Thread-safe using read lock.
//
// Parameters:
//   - status: Status value to query (e.g., "active", "completed")
//
// Returns:
//   - []string: Slice of todo IDs (empty if status not found, never nil)
//
// Performance:
//   - O(n) where n is the number of todos with this status
//   - Pre-allocates slice with exact capacity for efficiency
//
// Example:
//   activeIDs := idx.GetByStatus(todo.StatusActive)
//   fmt.Printf("Found %d active todos\n", len(activeIDs))
//   for _, id := range activeIDs {
//       // process each active todo
//   }
func (si *StatusIndex) GetByStatus(status string) []string {
	si.mu.RLock()
	defer si.mu.RUnlock()

	ids := make([]string, 0, len(si.index[status]))
	for id := range si.index[status] {
		ids = append(ids, id)
	}

	return ids
}

// Count returns the number of todos indexed under the specified status.
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
//   if count > 100 {
//       fmt.Println("High number of active todos!")
//   }
func (si *StatusIndex) Count(status string) int {
	si.mu.RLock()
	defer si.mu.RUnlock()

	return len(si.index[status])
}
