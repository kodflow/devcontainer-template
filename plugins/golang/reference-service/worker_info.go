// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Defines the WorkerInfo data structure for tracking worker state.
//
// Responsibilities:
//   - Worker state tracking data structure
//   - Atomic worker metrics (task count, active status)
//
// Features:
//   - None (Pure data structure with atomic fields)
//
// Constraints:
//   - Used with WorkerRegistry for concurrent access
//
package taskqueue

import (
	"sync/atomic"
	"time"
)

// WorkerInfo tracks worker state.
type WorkerInfo struct {
	ID          int
	StartTime   time.Time
	TasksCount  atomic.Uint64
	Active      atomic.Bool
	CurrentTask atomic.Value // *Task or nil
}
