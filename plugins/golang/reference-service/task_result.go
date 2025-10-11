// Package taskqueue task result entity
//
// Purpose:
//   Defines the TaskResult entity with optimized memory layout.
//
// Responsibilities:
//   - Task result structure
//   - Result validation
//
// Features:
//   - None
//
// Constraints:
//   - Fields ordered by size for memory alignment
//
package taskqueue

import "time"

// TaskResult represents the result of task execution
// Fields ordered by size for optimal memory alignment
type TaskResult struct {
	// 8-byte aligned fields first
	Output map[string]interface{} // 8 bytes (pointer)

	// 24-byte time.Time
	Timestamp time.Time // 24 bytes

	// 16-byte strings
	TaskID string // 16 bytes
	Error  string // 16 bytes

	// 8-byte fields
	Duration time.Duration // 8 bytes

	// 1-byte bool (packed at end)
	Success bool // 1 byte
}
