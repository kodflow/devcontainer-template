// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates context patterns for cancellation, timeouts, and values.
//
// Responsibilities:
//   - Context-based cancellation
//   - Timeout and deadline management
//   - Context value propagation (with caution)
//
// Features:
//   - None (Standard library contexts)
//
// Constraints:
//   - Context values should be request-scoped only
//   - Never store context in struct fields
//   - Always check ctx.Done() in loops
//
package taskqueue

import (
	"context"
	"errors"
	"time"
)

// ProcessWithTimeout processes task with timeout.
// Demonstrates context.WithTimeout for operation limits.
func ProcessWithTimeout(ctx context.Context, task *Task, timeout time.Duration) error {
	// Create context with timeout
	ctx, cancel := context.WithTimeout(ctx, timeout)
	defer cancel() // Always defer cancel to release resources

	// Use errgroup for concurrent operations with timeout
	resultChan := make(chan error, 1)

	go func() {
		// Simulate long-running operation
		time.Sleep(50 * time.Millisecond)
		resultChan <- nil
	}()

	select {
	case <-ctx.Done():
		return ctx.Err() // context.DeadlineExceeded or context.Canceled
	case err := <-resultChan:
		return err
	}
}

// ProcessWithDeadline processes task before absolute deadline.
// Use WithDeadline when you have specific time (e.g., request deadline).
func ProcessWithDeadline(ctx context.Context, task *Task, deadline time.Time) error {
	ctx, cancel := context.WithDeadline(ctx, deadline)
	defer cancel()

	// Check if already past deadline
	if time.Now().After(deadline) {
		return context.DeadlineExceeded
	}

	return processTaskInternal(ctx, task)
}

// ProcessWithCancellation processes task with cancellation signal.
// Demonstrates context.WithCancel for user-initiated cancellation.
func ProcessWithCancellation(parentCtx context.Context, task *Task) (context.CancelFunc, error) {
	ctx, cancel := context.WithCancel(parentCtx)

	go func() {
		_ = processTaskInternal(ctx, task)
	}()

	return cancel, nil
}

// ProcessBatch processes tasks with shared context.
// If parent cancelled, all tasks stop.
func ProcessBatch(ctx context.Context, tasks []*Task) error {
	for _, task := range tasks {
		// Check cancellation before each task
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		if err := processTaskInternal(ctx, task); err != nil {
			return err
		}
	}

	return nil
}

// ProcessWithRetry retries failed tasks with exponential backoff.
// Respects context cancellation during retries.
func ProcessWithRetry(ctx context.Context, task *Task, maxRetries int) error {
	backoff := 100 * time.Millisecond

	for attempt := 0; attempt < maxRetries; attempt++ {
		// Check cancellation before retry
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}

		err := processTaskInternal(ctx, task)
		if err == nil {
			return nil // Success
		}

		// Don't retry on context errors
		if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
			return err
		}

		// Exponential backoff with jitter
		if attempt < maxRetries-1 {
			backoff *= 2
			timer := time.NewTimer(backoff)
			select {
			case <-ctx.Done():
				timer.Stop()
				return ctx.Err()
			case <-timer.C:
			}
		}
	}

	return errors.New("max retries exceeded")
}

// contextKey is a private type for context keys.
// Prevents collisions with keys from other packages.
type contextKey int

const (
	requestIDKey contextKey = iota
	userIDKey
	traceIDKey
)

// WithRequestID adds request ID to context.
// Demonstrates context value propagation (use sparingly).
func WithRequestID(ctx context.Context, requestID string) context.Context {
	return context.WithValue(ctx, requestIDKey, requestID)
}

// GetRequestID extracts request ID from context.
func GetRequestID(ctx context.Context) (string, bool) {
	requestID, ok := ctx.Value(requestIDKey).(string)
	return requestID, ok
}

// WithUserID adds user ID to context.
func WithUserID(ctx context.Context, userID string) context.Context {
	return context.WithValue(ctx, userIDKey, userID)
}

// GetUserID extracts user ID from context.
func GetUserID(ctx context.Context) (string, bool) {
	userID, ok := ctx.Value(userIDKey).(string)
	return userID, ok
}

// WithTraceID adds trace ID to context.
func WithTraceID(ctx context.Context, traceID string) context.Context {
	return context.WithValue(ctx, traceIDKey, traceID)
}

// GetTraceID extracts trace ID from context.
func GetTraceID(ctx context.Context) (string, bool) {
	traceID, ok := ctx.Value(traceIDKey).(string)
	return traceID, ok
}

// ProcessWithContext demonstrates proper context usage.
// Shows checking Done channel in loops.
func ProcessWithContext(ctx context.Context, tasks []*Task) error {
	for i, task := range tasks {
		// Check context every N iterations
		if i%10 == 0 {
			select {
			case <-ctx.Done():
				return ctx.Err()
			default:
			}
		}

		if err := processTaskInternal(ctx, task); err != nil {
			return err
		}
	}

	return nil
}

// ProcessConcurrent processes tasks concurrently with context.
// All goroutines respect parent context cancellation.
func ProcessConcurrent(ctx context.Context, tasks []*Task, concurrency int) error {
	taskChan := make(chan *Task, len(tasks))
	errChan := make(chan error, concurrency)

	// Fill task channel
	for _, task := range tasks {
		taskChan <- task
	}
	close(taskChan)

	// Start workers
	for i := 0; i < concurrency; i++ {
		go func() {
			for task := range taskChan {
				select {
				case <-ctx.Done():
					errChan <- ctx.Err()
					return
				default:
					if err := processTaskInternal(ctx, task); err != nil {
						errChan <- err
						return
					}
				}
			}
			errChan <- nil
		}()
	}

	// Wait for all workers
	for i := 0; i < concurrency; i++ {
		if err := <-errChan; err != nil {
			return err
		}
	}

	return nil
}

// ProcessWithGracefulShutdown demonstrates graceful shutdown pattern.
// Allows in-flight tasks to complete but rejects new ones.
func ProcessWithGracefulShutdown(ctx context.Context, tasks []*Task, shutdownGrace time.Duration) error {
	taskChan := make(chan *Task, len(tasks))
	resultChan := make(chan error, 1)

	// Start processor
	go func() {
		for task := range taskChan {
			if err := processTaskInternal(ctx, task); err != nil {
				resultChan <- err
				return
			}
		}
		resultChan <- nil
	}()

	// Send tasks
	for _, task := range tasks {
		select {
		case <-ctx.Done():
			// Shutdown initiated
			close(taskChan)

			// Wait for in-flight tasks (with grace period)
			graceCtx, cancel := context.WithTimeout(context.Background(), shutdownGrace)
			defer cancel()

			select {
			case <-graceCtx.Done():
				return errors.New("graceful shutdown timeout")
			case err := <-resultChan:
				return err
			}

		case taskChan <- task:
			// Task sent successfully
		}
	}

	close(taskChan)
	return <-resultChan
}

// WatchContext monitors context for cancellation.
// Returns channel that closes when context is cancelled.
func WatchContext(ctx context.Context) <-chan struct{} {
	done := make(chan struct{})
	go func() {
		<-ctx.Done()
		close(done)
	}()
	return done
}

// MergeContexts creates context cancelled when any parent is cancelled.
// Useful for "first to cancel" semantics.
func MergeContexts(ctx1, ctx2 context.Context) (context.Context, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.Background())

	go func() {
		select {
		case <-ctx1.Done():
			cancel()
		case <-ctx2.Done():
			cancel()
		}
	}()

	return ctx, cancel
}

// TimeoutOrCancel creates context with both timeout and cancellation.
func TimeoutOrCancel(ctx context.Context, timeout time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, timeout)
}

// processTaskInternal is internal helper that respects context.
func processTaskInternal(ctx context.Context, task *Task) error {
	// Check context before starting
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
	}

	// Simulate work with context checking
	for i := 0; i < 10; i++ {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(10 * time.Millisecond):
			// Continue working
		}
	}

	return nil
}

// CascadeTimeout creates child context with shorter timeout.
// Ensures child completes before parent times out.
func CascadeTimeout(ctx context.Context, parentTimeout, childTimeout time.Duration) (context.Context, context.CancelFunc) {
	if childTimeout >= parentTimeout {
		childTimeout = parentTimeout / 2 // Child must complete first
	}
	return context.WithTimeout(ctx, childTimeout)
}
