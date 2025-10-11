// Package taskqueue_test task result tests
//
// Purpose:
//   Tests for TaskResult struct creation and validation.
//
// Responsibilities:
//   - Test TaskResult field assignments
//   - Test zero values
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Test all fields
//
package taskqueue_test

import (
	"testing"
	"time"

	"taskqueue"
)

func TestTaskResult_Creation(t *testing.T) {
	t.Parallel()

	result := taskqueue.TaskResult{
		TaskID:    "test-task-id",
		Success:   true,
		Output:    map[string]interface{}{"result": "success"},
		Error:     "",
		Duration:  5 * time.Second,
		Timestamp: time.Now(),
	}

	if result.TaskID != "test-task-id" {
		t.Errorf("expected task ID 'test-task-id', got %s", result.TaskID)
	}

	if !result.Success {
		t.Error("expected success to be true")
	}

	if result.Output["result"] != "success" {
		t.Error("expected output to contain result")
	}

	if result.Error != "" {
		t.Errorf("expected empty error, got %s", result.Error)
	}

	if result.Duration != 5*time.Second {
		t.Errorf("expected duration 5s, got %v", result.Duration)
	}
}

func TestTaskResult_Failure(t *testing.T) {
	t.Parallel()

	result := taskqueue.TaskResult{
		TaskID:    "failed-task",
		Success:   false,
		Output:    nil,
		Error:     "processing failed",
		Duration:  2 * time.Second,
		Timestamp: time.Now(),
	}

	if result.Success {
		t.Error("expected success to be false")
	}

	if result.Error == "" {
		t.Error("expected error message")
	}

	if result.Error != "processing failed" {
		t.Errorf("expected 'processing failed', got %s", result.Error)
	}
}

func TestTaskResult_ZeroValue(t *testing.T) {
	t.Parallel()

	var result taskqueue.TaskResult

	if result.TaskID != "" {
		t.Errorf("expected empty task ID, got %s", result.TaskID)
	}

	if result.Success {
		t.Error("expected success to be false")
	}

	if result.Output != nil {
		t.Error("expected nil output")
	}

	if result.Error != "" {
		t.Error("expected empty error")
	}

	if result.Duration != 0 {
		t.Errorf("expected zero duration, got %v", result.Duration)
	}
}
