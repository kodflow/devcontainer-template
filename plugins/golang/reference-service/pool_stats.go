// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Pool usage statistics tracking.
//
// Responsibilities:
//   - Track pool Get/Put operations
//   - Calculate hit ratios
//
// Features:
//   - None
//
// Constraints:
//   - Uses atomic operations only
//
package taskqueue

import "sync/atomic"

// PoolStats tracks pool usage statistics.
// Demonstrates monitoring pool effectiveness.
type PoolStats struct {
	Gets  atomic.Uint64 // Total Get() calls
	Puts  atomic.Uint64 // Total Put() calls
	News  atomic.Uint64 // Total new allocations
	Hits  atomic.Uint64 // Get() returned existing object
	Ratio float64       // Hit ratio (hits/gets)
}
