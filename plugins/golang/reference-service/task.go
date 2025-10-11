// Package taskqueue task entity definition
//
// Purpose:
//   Defines the Task entity with optimized memory layout
//   and bitwise flag support for performance.
//
// Responsibilities:
//   - Task entity structure
//   - Task flag operations
//   - Task validation
//
// Features:
//   - Validation
//
// Constraints:
//   - Fields ordered by size (largest first) for memory alignment
//   - Use bitwise flags for options
//
package taskqueue

import "time"

// Task represents a task to be processed
// Fields ordered by size for optimal memory alignment:
// - pointers and maps (8 bytes on 64-bit)
// - time.Time (24 bytes - 3 int64)
// - strings (16 bytes - pointer + length)
// - int (8 bytes on 64-bit)
// - uint8 (1 byte)
type Task struct {
	// 8-byte aligned fields first
	Data map[string]interface{} // 8 bytes (pointer)

	// 24-byte time.Time fields
	CreatedAt time.Time // 24 bytes
	UpdatedAt time.Time // 24 bytes

	// 16-byte string fields
	ID   string // 16 bytes
	Type string // 16 bytes

	// 8-byte int fields
	Status     TaskStatus // 16 bytes (string under the hood)
	Retries    int        // 8 bytes
	MaxRetries int        // 8 bytes

	// 1-byte fields (packed together)
	Flags uint8 // 1 byte - bitwise flags for options
}

// HasFlag checks if task has specific flag set using bitwise AND
func (t *Task) HasFlag(flag uint8) bool {
	return t.Flags&flag != 0
}

// SetFlag sets a flag using bitwise OR
func (t *Task) SetFlag(flag uint8) {
	t.Flags |= flag
}

// ClearFlag clears a flag using bitwise AND with complement
func (t *Task) ClearFlag(flag uint8) {
	t.Flags &^= flag
}

// ToggleFlag toggles a flag using bitwise XOR
func (t *Task) ToggleFlag(flag uint8) {
	t.Flags ^= flag
}

// IsUrgent checks if task is urgent using bitwise operation
func (t *Task) IsUrgent() bool {
	return t.HasFlag(TaskFlagUrgent)
}

// IsRetryable checks if task is retryable
func (t *Task) IsRetryable() bool {
	return t.HasFlag(TaskFlagRetryable)
}

// ShouldLogMetrics checks if task should log metrics
func (t *Task) ShouldLogMetrics() bool {
	return t.HasFlag(TaskFlagMetrics)
}
