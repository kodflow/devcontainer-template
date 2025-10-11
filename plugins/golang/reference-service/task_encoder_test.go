package taskqueue_test

import (
	"encoding/json"
	"sync"
	"testing"

	"taskqueue"
)

func TestTaskEncoder_Encode(t *testing.T) {
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

func TestTaskEncoder_ConcurrentSafety(t *testing.T) {
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
