// Package taskqueue task status enumeration
//
// Purpose:
//   Defines task status values and validation with
//   set-based lookup for O(1) performance.
//
// Responsibilities:
//   - Status enumeration
//   - Status validation
//   - Status transition rules
//
// Features:
//   - Validation
//
// Constraints:
//   - Use map[string]struct{} for set operations
//   - Immutable status values
//
package taskqueue

// TaskStatus represents the state of a task
type TaskStatus string

const (
	TaskStatusPending    TaskStatus = "pending"
	TaskStatusProcessing TaskStatus = "processing"
	TaskStatusCompleted  TaskStatus = "completed"
	TaskStatusFailed     TaskStatus = "failed"
)

// validStatuses is a set using map[string]struct{} for O(1) lookup
// Empty struct{} uses 0 bytes of memory
var validStatuses = map[TaskStatus]struct{}{
	TaskStatusPending:    {},
	TaskStatusProcessing: {},
	TaskStatusCompleted:  {},
	TaskStatusFailed:     {},
}

// IsValidStatus checks if status is valid using set lookup O(1)
func IsValidStatus(status TaskStatus) bool {
	_, exists := validStatuses[status]
	return exists
}

// CanTransition checks if status transition is valid
func (t *Task) CanTransition(newStatus TaskStatus) bool {
	switch t.Status {
	case TaskStatusPending:
		return newStatus == TaskStatusProcessing
	case TaskStatusProcessing:
		return newStatus == TaskStatusCompleted || newStatus == TaskStatusFailed
	case TaskStatusCompleted, TaskStatusFailed:
		return false
	default:
		return false
	}
}
