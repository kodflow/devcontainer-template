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

// MaxTodosPerStatus defines the maximum number of todos that can be indexed per status.
//
// This limit prevents unbounded memory growth and ensures reasonable performance
// for status-based queries. When this limit is reached, additional todos with
// the same status cannot be added to the index.
//
// Used by:
//   - StatusIndex to enforce capacity limits
//   - Application logic to validate batch operations
const MaxTodosPerStatus = 10000
