// Package taskqueue task creation request
//
// Purpose:
//   Defines the request DTO for creating new tasks.
//
// Responsibilities:
//   - Request structure
//   - Request validation
//
// Features:
//   - Validation
//
// Constraints:
//   - All fields must be validated
//
package taskqueue

import "errors"

// CreateTaskRequest represents request to create new task
// Fields ordered by size
type CreateTaskRequest struct {
	// 8-byte aligned
	Data map[string]interface{} // 8 bytes

	// 16-byte string
	Type string // 16 bytes

	// 8-byte int
	MaxRetries int // 8 bytes

	// 1-byte flags
	Flags uint8 // 1 byte
}

// Validate validates the create task request
func (r CreateTaskRequest) Validate() error {
	if r.Type == "" {
		return ErrInvalidTaskType
	}
	if r.Data == nil {
		return ErrInvalidTaskData
	}
	if r.MaxRetries < 0 {
		return errors.New("max retries cannot be negative")
	}
	if r.MaxRetries > MaxRetryLimit {
		return errors.New("max retries exceeds limit")
	}
	return nil
}
