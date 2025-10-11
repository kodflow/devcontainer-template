// Package taskqueue_test sync.Pool tests and benchmarks
//
// Purpose:
//   Tests and benchmarks for sync.Pool usage.
//
// Responsibilities:
//   - Verify pool correctness
//   - Benchmark pool performance vs allocations
//   - Demonstrate pool effectiveness
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Must show significant performance improvement
//
package taskqueue_test

import (
	"bytes"
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"

	"taskqueue"
)

func TestBufferPool_Encode(t *testing.T) {
	t.Parallel()

	encoder := taskqueue.NewTaskEncoder()
	task := &taskqueue.Task{
		ID:     "test-123",
		Type:   "email",
		Status: taskqueue.TaskStatusPending,
	}

	data, err := encoder.Encode(task)
	if err != nil {
		t.Fatalf("encode failed: %v", err)
	}

	if len(data) == 0 {
		t.Error("expected non-empty encoded data")
	}

	// Verify JSON is valid
	var decoded map[string]interface{}
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Errorf("invalid JSON: %v", err)
	}
}

func TestRequestPool_AcquireRelease(t *testing.T) {
	t.Parallel()

	// Acquire request
	req := taskqueue.AcquireRequest()
	if req == nil {
		t.Fatal("expected non-nil request")
	}

	// Modify request
	req.Type = "email"
	req.MaxRetries = 3
	req.Data["to"] = "test@example.com"

	// Release request
	taskqueue.ReleaseRequest(req)

	// Acquire again (should get same object, but reset)
	req2 := taskqueue.AcquireRequest()

	// Verify reset
	if req2.Type != "" {
		t.Error("expected Type to be reset")
	}
	if req2.MaxRetries != 0 {
		t.Error("expected MaxRetries to be reset")
	}
	if len(req2.Data) != 0 {
		t.Error("expected Data to be empty")
	}
}

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

func TestTrackedPool_Statistics(t *testing.T) {
	t.Parallel()

	pool := taskqueue.NewTrackedPool(func() interface{} {
		return &bytes.Buffer{}
	})

	// Get from empty pool (should create new)
	obj1 := pool.Get()
	if obj1 == nil {
		t.Fatal("expected non-nil object")
	}

	// Put back
	pool.Put(obj1)

	// Get again (should reuse)
	obj2 := pool.Get()
	if obj2 == nil {
		t.Fatal("expected non-nil object")
	}

	stats := pool.GetStats()
	if stats.Ratio == 0 {
		t.Error("expected non-zero hit ratio")
	}
}

func TestPoolConcurrent_Safety(t *testing.T) {
	t.Parallel()

	const goroutines = 50
	const operations = 1000

	encoder := taskqueue.NewTaskEncoder()
	task := &taskqueue.Task{
		ID:     "concurrent-test",
		Type:   "test",
		Status: taskqueue.TaskStatusPending,
	}

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < operations; j++ {
				_, err := encoder.Encode(task)
				if err != nil {
					t.Errorf("encode failed: %v", err)
				}
			}
		}()
	}

	wg.Wait()
}
