package taskqueue_test

import (
	"strings"
	"testing"

	"taskqueue"
)

func TestBatchProcessor_ProcessBatch(t *testing.T) {
	t.Parallel()

	processor := taskqueue.NewBatchProcessor()

	tasks := []*taskqueue.Task{
		{ID: "task-1", Type: "email", Status: taskqueue.TaskStatusPending},
		{ID: "task-2", Type: "sms", Status: taskqueue.TaskStatusPending},
		{ID: "task-3", Type: "push", Status: taskqueue.TaskStatusPending},
	}

	results, err := processor.ProcessBatch(tasks)
	if err != nil {
		t.Fatalf("process batch failed: %v", err)
	}

	if len(results) != len(tasks) {
		t.Errorf("expected %d results, got %d", len(tasks), len(results))
	}

	for i, result := range results {
		if len(result) == 0 {
			t.Errorf("result %d is empty", i)
		}
	}
}

func TestFormatTaskSummary(t *testing.T) {
	t.Parallel()

	task := &taskqueue.Task{
		ID:     "task-123",
		Type:   "email",
		Status: taskqueue.TaskStatusProcessing,
	}

	summary := taskqueue.FormatTaskSummary(task)

	if !strings.Contains(summary, "task-123") {
		t.Error("summary missing task ID")
	}
	if !strings.Contains(summary, "email") {
		t.Error("summary missing type")
	}
	if !strings.Contains(summary, "processing") {
		t.Error("summary missing status")
	}
}
