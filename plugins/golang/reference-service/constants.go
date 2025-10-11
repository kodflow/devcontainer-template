// Package taskqueue constants and default values
//
// Purpose:
//   Centralizes all constants and default configuration values
//   to avoid magic numbers and improve maintainability.
//
// Responsibilities:
//   - Define default timeout values
//   - Define buffer sizes
//   - Define worker pool defaults
//   - Define retry limits
//
// Features:
//   - None (Constants only)
//
// Constraints:
//   - All defaults must be documented
//   - Values must be sensible for production
//
package taskqueue

import "time"

const (
	// Default worker pool configuration
	DefaultWorkerCount     = 5
	DefaultBufferSize      = 100
	DefaultShutdownTimeout = 30 * time.Second
	DefaultProcessTimeout  = 60 * time.Second

	// Task retry limits
	DefaultMaxRetries = 3
	MaxRetryLimit     = 10

	// Channel buffer sizes
	TaskChannelBuffer   = 100
	ResultChannelBuffer = 100

	// Task status values (for validation)
	StatusPending    = "pending"
	StatusProcessing = "processing"
	StatusCompleted  = "completed"
	StatusFailed     = "failed"

	// Bitwise flags for task options
	TaskFlagNone      uint8 = 0
	TaskFlagUrgent    uint8 = 1 << 0 // 0001
	TaskFlagRetryable uint8 = 1 << 1 // 0010
	TaskFlagLogged    uint8 = 1 << 2 // 0100
	TaskFlagMetrics   uint8 = 1 << 3 // 1000
)

// Task option combinations using bitwise operations
const (
	TaskFlagDefault        = TaskFlagRetryable | TaskFlagLogged           // 0110
	TaskFlagUrgentWithLogs = TaskFlagUrgent | TaskFlagLogged | TaskFlagMetrics // 1101
)
