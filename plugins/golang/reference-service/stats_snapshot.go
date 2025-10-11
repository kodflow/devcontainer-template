// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Snapshot structure for atomic statistics capture.
//
// Responsibilities:
//   - Provide immutable statistics snapshot
//   - Store point-in-time metrics
//
// Features:
//   - None
//
// Constraints:
//   - Immutable after creation
//   - All fields read-only
//
package taskqueue

import "time"

// StatsSnapshot captures current statistics atomically.
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
