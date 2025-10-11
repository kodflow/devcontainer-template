// Package taskqueue_test task status validation tests
//
// Purpose:
//   Tests for TaskStatus validation and state transitions.
//
// Responsibilities:
//   - Test status validation
//   - Test state transition rules
//   - Test all valid/invalid status combinations
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Test all state combinations
//   - Test invalid states
//
package taskqueue_test

import (
	"testing"

	"taskqueue"
)

func TestIsValidStatus(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name     string
		status   taskqueue.TaskStatus
		expected bool
	}{
		{
			name:     "pending status",
			status:   taskqueue.TaskStatusPending,
			expected: true,
		},
		{
			name:     "processing status",
			status:   taskqueue.TaskStatusProcessing,
			expected: true,
		},
		{
			name:     "completed status",
			status:   taskqueue.TaskStatusCompleted,
			expected: true,
		},
		{
			name:     "failed status",
			status:   taskqueue.TaskStatusFailed,
			expected: true,
		},
		{
			name:     "invalid status",
			status:   taskqueue.TaskStatus("invalid"),
			expected: false,
		},
		{
			name:     "empty status",
			status:   taskqueue.TaskStatus(""),
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			result := taskqueue.IsValidStatus(tt.status)

			if result != tt.expected {
				t.Errorf("expected %v, got %v", tt.expected, result)
			}
		})
	}
}

func TestTaskStatus_Constants(t *testing.T) {
	t.Parallel()

	if taskqueue.TaskStatusPending != "pending" {
		t.Errorf("expected 'pending', got %s", taskqueue.TaskStatusPending)
	}

	if taskqueue.TaskStatusProcessing != "processing" {
		t.Errorf("expected 'processing', got %s", taskqueue.TaskStatusProcessing)
	}

	if taskqueue.TaskStatusCompleted != "completed" {
		t.Errorf("expected 'completed', got %s", taskqueue.TaskStatusCompleted)
	}

	if taskqueue.TaskStatusFailed != "failed" {
		t.Errorf("expected 'failed', got %s", taskqueue.TaskStatusFailed)
	}
}
