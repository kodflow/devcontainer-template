// Package taskqueue_test task entity tests
//
// Purpose:
//   Tests for Task entity and state transition logic.
//
// Responsibilities:
//   - Test task state transitions
//   - Test CanTransition business rules
//   - Test all state combinations
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Test all valid and invalid transitions
//   - Test edge cases
//
package taskqueue_test

import (
	"testing"

	"taskqueue"
)

func TestTask_CanTransition(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name          string
		currentStatus taskqueue.TaskStatus
		newStatus     taskqueue.TaskStatus
		canTransition bool
	}{
		{
			name:          "pending to processing",
			currentStatus: taskqueue.TaskStatusPending,
			newStatus:     taskqueue.TaskStatusProcessing,
			canTransition: true,
		},
		{
			name:          "pending to completed - invalid",
			currentStatus: taskqueue.TaskStatusPending,
			newStatus:     taskqueue.TaskStatusCompleted,
			canTransition: false,
		},
		{
			name:          "pending to failed - invalid",
			currentStatus: taskqueue.TaskStatusPending,
			newStatus:     taskqueue.TaskStatusFailed,
			canTransition: false,
		},
		{
			name:          "processing to completed",
			currentStatus: taskqueue.TaskStatusProcessing,
			newStatus:     taskqueue.TaskStatusCompleted,
			canTransition: true,
		},
		{
			name:          "processing to failed",
			currentStatus: taskqueue.TaskStatusProcessing,
			newStatus:     taskqueue.TaskStatusFailed,
			canTransition: true,
		},
		{
			name:          "processing to pending - invalid",
			currentStatus: taskqueue.TaskStatusProcessing,
			newStatus:     taskqueue.TaskStatusPending,
			canTransition: false,
		},
		{
			name:          "completed to processing - invalid",
			currentStatus: taskqueue.TaskStatusCompleted,
			newStatus:     taskqueue.TaskStatusProcessing,
			canTransition: false,
		},
		{
			name:          "completed to failed - invalid",
			currentStatus: taskqueue.TaskStatusCompleted,
			newStatus:     taskqueue.TaskStatusFailed,
			canTransition: false,
		},
		{
			name:          "failed to processing - invalid",
			currentStatus: taskqueue.TaskStatusFailed,
			newStatus:     taskqueue.TaskStatusProcessing,
			canTransition: false,
		},
		{
			name:          "failed to completed - invalid",
			currentStatus: taskqueue.TaskStatusFailed,
			newStatus:     taskqueue.TaskStatusCompleted,
			canTransition: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			task := BuildTestTask(t, WithTaskStatus(tt.currentStatus))

			result := task.CanTransition(tt.newStatus)

			if result != tt.canTransition {
				t.Errorf("expected %v for transition from %s to %s, got %v",
					tt.canTransition, tt.currentStatus, tt.newStatus, result)
			}
		})
	}
}

func TestTask_CanTransition_AllStateCombinations(t *testing.T) {
	t.Parallel()

	allStatuses := []taskqueue.TaskStatus{
		taskqueue.TaskStatusPending,
		taskqueue.TaskStatusProcessing,
		taskqueue.TaskStatusCompleted,
		taskqueue.TaskStatusFailed,
	}

	for _, from := range allStatuses {
		for _, to := range allStatuses {
			t.Run(string(from)+"_to_"+string(to), func(t *testing.T) {
				task := BuildTestTask(t, WithTaskStatus(from))
				_ = task.CanTransition(to)
			})
		}
	}
}

func TestBuildTestTask_WithOptions(t *testing.T) {
	t.Parallel()

	task := BuildTestTask(t,
		WithTaskID("custom-id"),
		WithTaskType("custom-type"),
		WithTaskStatus(taskqueue.TaskStatusProcessing),
		WithTaskData(map[string]interface{}{"custom": "data"}),
	)

	if task.ID != "custom-id" {
		t.Errorf("expected 'custom-id', got %s", task.ID)
	}

	if task.Type != "custom-type" {
		t.Errorf("expected 'custom-type', got %s", task.Type)
	}

	if task.Status != taskqueue.TaskStatusProcessing {
		t.Errorf("expected processing status, got %s", task.Status)
	}

	if task.Data["custom"] != "data" {
		t.Errorf("expected custom data")
	}
}
