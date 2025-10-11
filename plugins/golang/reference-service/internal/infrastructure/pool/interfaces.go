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

import "context"

// Task represents a unit of work to be executed.
type Task func(ctx context.Context) error

// Pool defines the interface for worker pool operations.
type Pool interface {
	// Submit adds a task to the pool for execution.
	Submit(ctx context.Context, task Task) error

	// Shutdown stops the pool and waits for tasks to complete.
	Shutdown(ctx context.Context) error

	// ActiveWorkers returns the number of currently active workers.
	ActiveWorkers() int

	// CompletedTasks returns the total number of completed tasks.
	CompletedTasks() int64
}
