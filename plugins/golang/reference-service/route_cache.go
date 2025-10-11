// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Map for caching routing decisions with write-once pattern.
//
// Responsibilities:
//   - Concurrent routing cache operations
//   - Atomic get-or-compute routing logic
//   - Cache invalidation for routing decisions
//
// Features:
//   - None (Pure concurrency primitives)
//
// Constraints:
//   - Optimized for write-once, read-many pattern
//   - No range-over-map support (use Range method)
//   - Type assertions required (interface{} storage)
//
package taskqueue

import (
	"sync"
)

// RouteCache caches routing decisions using sync.Map.
// Demonstrates write-once, read-many pattern (optimal for sync.Map).
type RouteCache struct {
	routes sync.Map // key: taskType (string), value: workerID (int)
}

// NewRouteCache creates a route cache.
func NewRouteCache() *RouteCache {
	return &RouteCache{}
}

// GetOrCompute returns cached route or computes new one.
// Uses LoadOrStore for atomic get-or-create.
func (c *RouteCache) GetOrCompute(taskType string, compute func() int) int {
	// Try to load existing route
	if value, ok := c.routes.Load(taskType); ok {
		return value.(int)
	}

	// Compute new route
	workerID := compute()

	// Store atomically (if another goroutine stored first, use theirs)
	actual, _ := c.routes.LoadOrStore(taskType, workerID)
	return actual.(int)
}

// Invalidate removes cached route.
func (c *RouteCache) Invalidate(taskType string) {
	c.routes.Delete(taskType)
}

// InvalidateAll clears entire cache.
func (c *RouteCache) InvalidateAll() {
	// Create new map (efficient for full clear)
	c.routes = sync.Map{}
}
