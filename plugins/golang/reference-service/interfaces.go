// Package taskqueue provides a reference implementation of concurrent task processing
//
// Purpose:
//   Demonstrates ALL Go best practices including concurrency, channels, buffering,
//   error handling, context management, and proper testing patterns.
//
// Responsibilities:
//   - Define contracts for all dependencies
//   - Enable dependency injection and testability
//   - Support concurrent task processing
//
// Features:
//   - None (Interface definitions only)
//
// Constraints:
//   - Interfaces must be minimal (1-3 methods)
//   - All methods must be context-aware
//
package taskqueue

import (
	"context"
	"time"
)

// TaskRepository defines persistence operations for tasks
type TaskRepository interface {
	// Save stores a task
	Save(ctx context.Context, task *Task) error

	// GetByID retrieves a task by ID
	GetByID(ctx context.Context, id string) (*Task, error)

	// UpdateStatus updates task status
	UpdateStatus(ctx context.Context, id string, status TaskStatus) error

	// ListPending retrieves all pending tasks
	ListPending(ctx context.Context, limit int) ([]*Task, error)
}

// MessagePublisher publishes task results to message queue
type MessagePublisher interface {
	// Publish sends a message to specified topic
	Publish(ctx context.Context, topic string, message []byte) error
}

// MetricsCollector collects application metrics
type MetricsCollector interface {
	// IncrementCounter increments a counter metric
	IncrementCounter(ctx context.Context, name string, value int64)

	// RecordDuration records operation duration
	RecordDuration(ctx context.Context, name string, duration time.Duration)
}

// TaskExecutor executes a task and returns result
type TaskExecutor interface {
	// Execute processes a task
	Execute(ctx context.Context, task *Task) (*TaskResult, error)
}
