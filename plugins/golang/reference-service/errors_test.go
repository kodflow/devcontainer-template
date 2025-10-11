package taskqueue_test

import (
	"testing"

	"taskqueue"
)

func TestErrors_Constants(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name     string
		err      error
		expected string
	}{
		{
			name:     "ErrInvalidTaskID",
			err:      taskqueue.ErrInvalidTaskID,
			expected: "task ID is required",
		},
		{
			name:     "ErrInvalidTaskType",
			err:      taskqueue.ErrInvalidTaskType,
			expected: "task type is required",
		},
		{
			name:     "ErrInvalidTaskData",
			err:      taskqueue.ErrInvalidTaskData,
			expected: "task data is required",
		},
		{
			name:     "ErrInvalidStatus",
			err:      taskqueue.ErrInvalidStatus,
			expected: "invalid task status",
		},
		{
			name:     "ErrTaskNotFound",
			err:      taskqueue.ErrTaskNotFound,
			expected: "task not found",
		},
		{
			name:     "ErrProcessingTimeout",
			err:      taskqueue.ErrProcessingTimeout,
			expected: "task processing timeout",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			if tt.err.Error() != tt.expected {
				t.Errorf("expected error '%s', got '%s'", tt.expected, tt.err.Error())
			}
		})
	}
}
