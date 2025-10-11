// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Statistics tracking with atomic operations.
//
// Responsibilities:
//   - Track task processing metrics
//   - Provide thread-safe counters
//   - Calculate performance statistics
//
// Features:
//   - None (No telemetry, uses atomic only)
//
// Constraints:
//   - All operations must be lock-free
//   - Zero allocations for counter updates
//
package taskqueue

import (
	"sync/atomic"
	"time"
)

// WorkerStats tracks worker pool statistics using atomic operations.
// All fields use atomic operations for lock-free, high-performance updates.
// Fields are ordered by size (8-byte aligned first).
type WorkerStats struct {
	// 8-byte atomic counters (must be 64-bit aligned)
	tasksSubmitted   atomic.Uint64 // Total tasks submitted
	tasksProcessed   atomic.Uint64 // Total tasks completed
	tasksFailed      atomic.Uint64 // Total tasks that failed
	tasksRetried     atomic.Uint64 // Total retry attempts
	totalProcessTime atomic.Uint64 // Total processing time in nanoseconds

	// 4-byte atomic counters
	activeWorkers atomic.Uint32 // Current active workers

	// 1-byte atomic flag
	running atomic.Bool // Whether stats collection is active
}

// NewWorkerStats creates a new statistics tracker.
// All counters are initialized to zero atomically.
func NewWorkerStats() *WorkerStats {
	stats := &WorkerStats{}
	stats.running.Store(true)
	return stats
}

// RecordSubmission increments submitted task counter.
// Lock-free operation, safe for concurrent use.
func (s *WorkerStats) RecordSubmission() {
	s.tasksSubmitted.Add(1)
}

// RecordProcessed increments processed task counter and records duration.
// Duration is added to total processing time for average calculation.
func (s *WorkerStats) RecordProcessed(duration time.Duration) {
	s.tasksProcessed.Add(1)
	s.totalProcessTime.Add(uint64(duration.Nanoseconds()))
}

// RecordFailed increments failed task counter.
// Lock-free operation, safe for concurrent use.
func (s *WorkerStats) RecordFailed() {
	s.tasksFailed.Add(1)
}

// RecordRetry increments retry counter.
// Lock-free operation, safe for concurrent use.
func (s *WorkerStats) RecordRetry() {
	s.tasksRetried.Add(1)
}

// IncrementActive increments active worker counter.
// Called when a worker starts processing a task.
func (s *WorkerStats) IncrementActive() {
	s.activeWorkers.Add(1)
}

// DecrementActive decrements active worker counter.
// Called when a worker finishes processing a task.
func (s *WorkerStats) DecrementActive() {
	s.activeWorkers.Add(^uint32(0)) // Subtract 1 using two's complement
}

// GetSubmitted returns total tasks submitted.
// Atomic read, safe for concurrent use.
func (s *WorkerStats) GetSubmitted() uint64 {
	return s.tasksSubmitted.Load()
}

// GetProcessed returns total tasks processed.
// Atomic read, safe for concurrent use.
func (s *WorkerStats) GetProcessed() uint64 {
	return s.tasksProcessed.Load()
}

// GetFailed returns total tasks failed.
// Atomic read, safe for concurrent use.
func (s *WorkerStats) GetFailed() uint64 {
	return s.tasksFailed.Load()
}

// GetRetried returns total retry attempts.
// Atomic read, safe for concurrent use.
func (s *WorkerStats) GetRetried() uint64 {
	return s.tasksRetried.Load()
}

// GetActive returns current active workers.
// Atomic read, safe for concurrent use.
func (s *WorkerStats) GetActive() uint32 {
	return s.activeWorkers.Load()
}

// GetAverageProcessTime returns average processing time per task.
// Returns zero if no tasks have been processed.
func (s *WorkerStats) GetAverageProcessTime() time.Duration {
	processed := s.tasksProcessed.Load()
	if processed == 0 {
		return 0
	}

	totalNanos := s.totalProcessTime.Load()
	avgNanos := totalNanos / processed
	return time.Duration(avgNanos)
}

// GetSuccessRate returns success rate as a percentage (0-100).
// Returns 0 if no tasks have been submitted.
func (s *WorkerStats) GetSuccessRate() float64 {
	submitted := s.tasksSubmitted.Load()
	if submitted == 0 {
		return 0
	}

	processed := s.tasksProcessed.Load()
	return float64(processed) / float64(submitted) * 100
}

// Reset resets all counters to zero.
// Use with caution in production environments.
func (s *WorkerStats) Reset() {
	s.tasksSubmitted.Store(0)
	s.tasksProcessed.Store(0)
	s.tasksFailed.Store(0)
	s.tasksRetried.Store(0)
	s.totalProcessTime.Store(0)
	s.activeWorkers.Store(0)
}

// IsRunning returns whether stats collection is active.
// Atomic read, safe for concurrent use.
func (s *WorkerStats) IsRunning() bool {
	return s.running.Load()
}

// Stop stops stats collection.
// Atomic write, safe for concurrent use.
func (s *WorkerStats) Stop() {
	s.running.Store(false)
}

// Snapshot captures current statistics atomically.
// Returns a consistent view of all counters at a single point in time.
type StatsSnapshot struct {
	TasksSubmitted   uint64        // Total submitted
	TasksProcessed   uint64        // Total processed
	TasksFailed      uint64        // Total failed
	TasksRetried     uint64        // Total retried
	ActiveWorkers    uint32        // Currently active
	AverageTime      time.Duration // Average processing time
	SuccessRate      float64       // Success rate percentage
	TotalProcessTime time.Duration // Total processing time
}

// GetSnapshot returns a consistent snapshot of all statistics.
// All values are read atomically but may not represent a single instant.
func (s *WorkerStats) GetSnapshot() StatsSnapshot {
	return StatsSnapshot{
		TasksSubmitted:   s.GetSubmitted(),
		TasksProcessed:   s.GetProcessed(),
		TasksFailed:      s.GetFailed(),
		TasksRetried:     s.GetRetried(),
		ActiveWorkers:    s.GetActive(),
		AverageTime:      s.GetAverageProcessTime(),
		SuccessRate:      s.GetSuccessRate(),
		TotalProcessTime: time.Duration(s.totalProcessTime.Load()),
	}
}
