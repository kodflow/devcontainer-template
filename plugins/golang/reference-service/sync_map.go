// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Map for lock-free concurrent map access.
//
// Responsibilities:
//   - Concurrent map operations without explicit locking
//   - Cache implementation with sync.Map
//   - Registry patterns with concurrent access
//
// Features:
//   - None (Pure concurrency primitives)
//
// Constraints:
//   - Optimized for specific use cases (see below)
//   - No range-over-map support (use Range method)
//   - Type assertions required (interface{} storage)
//
package taskqueue

import (
	"sync"
	"time"
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

// StatusIndex maintains task counts by status using sync.Map.
// Demonstrates sync.Map for counters (stable keyset).
type StatusIndex struct {
	counts sync.Map // key: TaskStatus, value: *atomic.Uint64
}

// NewStatusIndex creates a status index.
func NewStatusIndex() *StatusIndex {
	return &StatusIndex{}
}

// Increment increments counter for status.
func (s *StatusIndex) Increment(status TaskStatus) {
	counter, _ := s.counts.LoadOrStore(status, &atomic.Uint64{})
	counter.(*atomic.Uint64).Add(1)
}

// Decrement decrements counter for status.
func (s *StatusIndex) Decrement(status TaskStatus) {
	counter, ok := s.counts.Load(status)
	if !ok {
		return
	}
	counter.(*atomic.Uint64).Add(^uint64(0)) // -1 using two's complement
}

// Get returns count for status.
func (s *StatusIndex) Get(status TaskStatus) uint64 {
	counter, ok := s.counts.Load(status)
	if !ok {
		return 0
	}
	return counter.(*atomic.Uint64).Load()
}

// GetAll returns all status counts.
func (s *StatusIndex) GetAll() map[TaskStatus]uint64 {
	result := make(map[TaskStatus]uint64)
	s.counts.Range(func(key, value interface{}) bool {
		status := key.(TaskStatus)
		count := value.(*atomic.Uint64).Load()
		result[status] = count
		return true
	})
	return result
}

// SessionStore manages user sessions with sync.Map.
// Demonstrates cache with expiration (stable keyset pattern).
type SessionStore struct {
	sessions sync.Map // key: sessionID (string), value: *Session
}

// Session represents a user session.
type Session struct {
	UserID    string
	ExpiresAt time.Time
	Data      map[string]interface{}
}

// NewSessionStore creates a session store.
func NewSessionStore() *SessionStore {
	return &SessionStore{}
}

// Store stores session.
func (s *SessionStore) Store(sessionID string, session *Session) {
	s.sessions.Store(sessionID, session)
}

// Load retrieves session if not expired.
func (s *SessionStore) Load(sessionID string) (*Session, bool) {
	value, ok := s.sessions.Load(sessionID)
	if !ok {
		return nil, false
	}

	session := value.(*Session)
	if time.Now().After(session.ExpiresAt) {
		s.sessions.Delete(sessionID)
		return nil, false
	}

	return session, true
}

// CleanExpired removes expired sessions.
// Should be called periodically in background goroutine.
func (s *SessionStore) CleanExpired() int {
	removed := 0
	now := time.Now()

	s.sessions.Range(func(key, value interface{}) bool {
		session := value.(*Session)
		if now.After(session.ExpiresAt) {
			s.sessions.Delete(key)
			removed++
		}
		return true
	})

	return removed
}

// WorkerRegistry tracks active workers with sync.Map.
// Demonstrates disjoint key sets (each worker has unique ID).
type WorkerRegistry struct {
	workers sync.Map // key: workerID (int), value: *WorkerInfo
}

// WorkerInfo tracks worker state.
type WorkerInfo struct {
	ID          int
	StartTime   time.Time
	TasksCount  atomic.Uint64
	Active      atomic.Bool
	CurrentTask atomic.Value // *Task or nil
}

// NewWorkerRegistry creates a worker registry.
func NewWorkerRegistry() *WorkerRegistry {
	return &WorkerRegistry{}
}

// Register registers a worker.
func (r *WorkerRegistry) Register(workerID int) {
	info := &WorkerInfo{
		ID:        workerID,
		StartTime: time.Now(),
	}
	info.Active.Store(true)
	r.workers.Store(workerID, info)
}

// Unregister removes a worker.
func (r *WorkerRegistry) Unregister(workerID int) {
	r.workers.Delete(workerID)
}

// SetTask sets current task for worker.
func (r *WorkerRegistry) SetTask(workerID int, task *Task) {
	value, ok := r.workers.Load(workerID)
	if !ok {
		return
	}

	info := value.(*WorkerInfo)
	info.CurrentTask.Store(task)
	info.TasksCount.Add(1)
}

// ClearTask clears current task for worker.
func (r *WorkerRegistry) ClearTask(workerID int) {
	value, ok := r.workers.Load(workerID)
	if !ok {
		return
	}

	info := value.(*WorkerInfo)
	info.CurrentTask.Store((*Task)(nil))
}

// GetInfo returns worker info.
func (r *WorkerRegistry) GetInfo(workerID int) (*WorkerInfo, bool) {
	value, ok := r.workers.Load(workerID)
	if !ok {
		return nil, false
	}
	return value.(*WorkerInfo), true
}

// ActiveCount returns number of active workers.
func (r *WorkerRegistry) ActiveCount() int {
	count := 0
	r.workers.Range(func(_, value interface{}) bool {
		info := value.(*WorkerInfo)
		if info.Active.Load() {
			count++
		}
		return true
	})
	return count
}

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
