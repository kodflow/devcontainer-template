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

import "errors"

var (
	// ErrPoolClosed indicates the pool has been shut down.
	ErrPoolClosed = errors.New("worker pool is closed")

	// ErrQueueFull indicates the task queue is at capacity.
	ErrQueueFull = errors.New("task queue is full")

	// ErrInvalidWorkerCount indicates an invalid worker count.
	ErrInvalidWorkerCount = errors.New("worker count must be between 1 and 1000")
)
