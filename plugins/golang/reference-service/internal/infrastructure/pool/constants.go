// Package pool provides worker pool implementation for concurrent task processing.
//
// Purpose:
//   Implements a bounded worker pool for executing tasks concurrently.
//
// Responsibilities:
//   - Manage pool of worker goroutines
//   - Queue and dispatch tasks to workers
//   - Track active and completed tasks
//
// Features:
//   - Concurrency Control
//   - Task Queue
//   - Worker Management
//
// Constraints:
//   - Maximum 1000 workers per pool
//   - Tasks must be non-blocking
//   - Workers execute sequentially
//
package pool

import "time"

const (
	// DefaultWorkerCount is the default number of workers.
	DefaultWorkerCount = 10

	// MaxWorkerCount is the maximum number of workers allowed.
	MaxWorkerCount = 1000

	// DefaultQueueSize is the default task queue capacity.
	DefaultQueueSize = 100

	// DefaultShutdownTimeout is the time to wait for graceful shutdown.
	DefaultShutdownTimeout = 30 * time.Second
)
