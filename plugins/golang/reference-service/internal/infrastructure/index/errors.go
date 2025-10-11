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

import "errors"

// Index operation errors.
var (
	// ErrIndexFull is returned when a status index reaches MaxTodosPerStatus capacity.
	//
	// Returned by:
	//   - StatusIndex.Add when the status index is at capacity
	//
	// Resolution:
	//   - Archive or delete completed todos to free up index space
	//   - Increase MaxTodosPerStatus if needed (not recommended)
	ErrIndexFull = errors.New("status index is at maximum capacity")

	// ErrInvalidStatus is returned when operating on an empty or invalid status.
	//
	// Returned by:
	//   - StatusIndex.Add when status parameter is empty
	//   - StatusIndex.Remove when status parameter is empty
	//   - StatusIndex.GetByStatus when status parameter is empty
	//
	// Resolution:
	//   - Provide a valid non-empty status string
	//   - Use todo.Status constants (StatusPending, StatusActive, etc.)
	ErrInvalidStatus = errors.New("status cannot be empty")
)
