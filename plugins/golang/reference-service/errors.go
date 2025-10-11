// Package taskqueue error definitions
//
// Purpose:
//   Centralizes all error definitions for the package.
//
// Responsibilities:
//   - Sentinel error definitions
//   - Error constants
//
// Features:
//   - None
//
// Constraints:
//   - Errors must be lowercase without punctuation
//   - Use errors.New() for sentinel errors
//
package taskqueue

import "errors"

var (
	ErrInvalidTaskID     = errors.New("task ID is required")
	ErrInvalidTaskType   = errors.New("task type is required")
	ErrInvalidTaskData   = errors.New("task data is required")
	ErrInvalidStatus     = errors.New("invalid task status")
	ErrTaskNotFound      = errors.New("task not found")
	ErrProcessingTimeout = errors.New("task processing timeout")
	ErrWorkerNotRunning  = errors.New("worker not running")
	ErrWorkerRunning     = errors.New("worker already running")
	ErrTaskQueueFull     = errors.New("task queue full")
	ErrShutdownTimeout   = errors.New("shutdown timeout exceeded")
)
