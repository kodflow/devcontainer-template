// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Map for maintaining task status counters.
//
// Responsibilities:
//   - Concurrent status counter operations
//   - Task status indexing with sync.Map
//   - Atomic counter increments and decrements
//
// Features:
//   - None (Pure concurrency primitives)
//
// Constraints:
//   - Optimized for stable keyset (task statuses)
//   - No range-over-map support (use Range method)
//   - Type assertions required (interface{} storage)
//
package taskqueue

import (
	"sync"
	"sync/atomic"
)

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
