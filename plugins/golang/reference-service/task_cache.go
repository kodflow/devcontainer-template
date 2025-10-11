// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Map for concurrent task caching.
//
// Responsibilities:
//   - Concurrent task cache operations without explicit locking
//   - Task storage and retrieval with sync.Map
//   - Atomic cache operations (LoadOrStore, LoadAndDelete)
//
// Features:
//   - None (Pure concurrency primitives)
//
// Constraints:
//   - Optimized for write-once, read-many patterns
//   - No range-over-map support (use Range method)
//   - Type assertions required (interface{} storage)
//
package taskqueue

import (
	"sync"
)

// TaskCache implements a concurrent cache using sync.Map.
//
// sync.Map is optimized for two use cases:
// 1. Keys are write-once, read-many (stable keyset)
// 2. Multiple goroutines read/write/delete disjoint key sets
//
// Performance:
//   For these cases: 10-100x faster than map + RWMutex
//   For frequent updates to same keys: slower than RWMutex
type TaskCache struct {
	cache sync.Map // key: taskID (string), value: *Task
}

// NewTaskCache creates a concurrent task cache.
func NewTaskCache() *TaskCache {
	return &TaskCache{}
}

// Store stores task in cache (concurrent-safe).
// No explicit locking needed - sync.Map handles it.
func (c *TaskCache) Store(taskID string, task *Task) {
	c.cache.Store(taskID, task)
}

// Load retrieves task from cache (concurrent-safe).
// Returns (task, true) if found, (nil, false) otherwise.
func (c *TaskCache) Load(taskID string) (*Task, bool) {
	value, ok := c.cache.Load(taskID)
	if !ok {
		return nil, false
	}
	return value.(*Task), true
}

// LoadOrStore returns existing value or stores new one.
// Useful for deduplication and caching patterns.
func (c *TaskCache) LoadOrStore(taskID string, task *Task) (*Task, bool) {
	actual, loaded := c.cache.LoadOrStore(taskID, task)
	return actual.(*Task), loaded
}

// Delete removes task from cache (concurrent-safe).
func (c *TaskCache) Delete(taskID string) {
	c.cache.Delete(taskID)
}

// LoadAndDelete loads and deletes in single atomic operation.
// Useful for "take one" patterns (queue-like behavior).
func (c *TaskCache) LoadAndDelete(taskID string) (*Task, bool) {
	value, loaded := c.cache.LoadAndDelete(taskID)
	if !loaded {
		return nil, false
	}
	return value.(*Task), true
}

// Range iterates over all cached tasks.
// Stops if function returns false.
func (c *TaskCache) Range(f func(taskID string, task *Task) bool) {
	c.cache.Range(func(key, value interface{}) bool {
		return f(key.(string), value.(*Task))
	})
}

// Count returns approximate number of cached tasks.
// Not atomic - use for metrics only.
func (c *TaskCache) Count() int {
	count := 0
	c.cache.Range(func(_, _ interface{}) bool {
		count++
		return true
	})
	return count
}
