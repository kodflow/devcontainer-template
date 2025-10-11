package taskqueue_test

import (
	"context"
	"errors"
	"testing"
	"time"

	"taskqueue"
)

func TestProcessWithTimeout_Success(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	task := &taskqueue.Task{ID: "task-1"}

	err := taskqueue.ProcessWithTimeout(ctx, task, time.Second)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestProcessWithTimeout_Exceeded(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	task := &taskqueue.Task{ID: "task-1"}

	err := taskqueue.ProcessWithTimeout(ctx, task, 10*time.Millisecond)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("expected DeadlineExceeded, got %v", err)
	}
}

func TestProcessWithDeadline(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	task := &taskqueue.Task{ID: "task-1"}
	deadline := time.Now().Add(time.Second)

	err := taskqueue.ProcessWithDeadline(ctx, task, deadline)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestProcessWithDeadline_Expired(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	task := &taskqueue.Task{ID: "task-1"}
	deadline := time.Now().Add(-time.Hour) // Past deadline

	err := taskqueue.ProcessWithDeadline(ctx, task, deadline)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Errorf("expected DeadlineExceeded, got %v", err)
	}
}

func TestProcessWithCancellation(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	task := &taskqueue.Task{ID: "task-1"}

	cancel, err := taskqueue.ProcessWithCancellation(ctx, task)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	// Call cancel to clean up
	cancel()
}

func TestProcessBatch_Success(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	err := taskqueue.ProcessBatch(ctx, tasks)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestProcessBatch_Cancelled(t *testing.T) {
	t.Parallel()

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
	}

	err := taskqueue.ProcessBatch(ctx, tasks)
	if !errors.Is(err, context.Canceled) {
		t.Errorf("expected Canceled, got %v", err)
	}
}

func TestProcessWithRetry_Success(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	task := &taskqueue.Task{ID: "task-1"}

	err := taskqueue.ProcessWithRetry(ctx, task, 3)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestProcessWithRetry_Cancelled(t *testing.T) {
	t.Parallel()

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	task := &taskqueue.Task{ID: "task-1"}

	err := taskqueue.ProcessWithRetry(ctx, task, 3)
	if !errors.Is(err, context.Canceled) {
		t.Errorf("expected Canceled, got %v", err)
	}
}

func TestContextValues(t *testing.T) {
	t.Parallel()

	ctx := context.Background()

	// Test RequestID
	ctx = taskqueue.WithRequestID(ctx, "req-123")
	requestID, ok := taskqueue.GetRequestID(ctx)
	if !ok {
		t.Error("expected request ID to be set")
	}
	if requestID != "req-123" {
		t.Errorf("expected req-123, got %s", requestID)
	}

	// Test UserID
	ctx = taskqueue.WithUserID(ctx, "user-456")
	userID, ok := taskqueue.GetUserID(ctx)
	if !ok {
		t.Error("expected user ID to be set")
	}
	if userID != "user-456" {
		t.Errorf("expected user-456, got %s", userID)
	}

	// Test TraceID
	ctx = taskqueue.WithTraceID(ctx, "trace-789")
	traceID, ok := taskqueue.GetTraceID(ctx)
	if !ok {
		t.Error("expected trace ID to be set")
	}
	if traceID != "trace-789" {
		t.Errorf("expected trace-789, got %s", traceID)
	}
}

func TestProcessWithContext(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	tasks := make([]*taskqueue.Task, 100)
	for i := range tasks {
		tasks[i] = &taskqueue.Task{ID: string(rune(i))}
	}

	err := taskqueue.ProcessWithContext(ctx, tasks)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestProcessConcurrent(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	err := taskqueue.ProcessConcurrent(ctx, tasks, 2)
	if err != nil {
		t.Errorf("expected no error, got %v", err)
	}
}

func TestWatchContext(t *testing.T) {
	t.Parallel()

	ctx, cancel := context.WithCancel(context.Background())
	done := taskqueue.WatchContext(ctx)

	cancel()

	select {
	case <-done:
		// Expected
	case <-time.After(time.Second):
		t.Error("expected done channel to close")
	}
}

func TestMergeContexts(t *testing.T) {
	t.Parallel()

	ctx1, cancel1 := context.WithCancel(context.Background())
	ctx2, cancel2 := context.WithCancel(context.Background())
	defer cancel2()

	merged, cancel := taskqueue.MergeContexts(ctx1, ctx2)
	defer cancel()

	// Cancel first context
	cancel1()

	select {
	case <-merged.Done():
		// Expected
	case <-time.After(time.Second):
		t.Error("expected merged context to be cancelled")
	}
}

func TestTimeoutOrCancel(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	timedCtx, cancel := taskqueue.TimeoutOrCancel(ctx, 100*time.Millisecond)
	defer cancel()

	select {
	case <-timedCtx.Done():
		// Expected after timeout
	case <-time.After(time.Second):
		t.Error("expected context to timeout")
	}
}

func TestCascadeTimeout(t *testing.T) {
	t.Parallel()

	ctx := context.Background()
	parentTimeout := time.Second
	childTimeout := 500 * time.Millisecond

	childCtx, cancel := taskqueue.CascadeTimeout(ctx, parentTimeout, childTimeout)
	defer cancel()

	// Child should timeout first
	select {
	case <-childCtx.Done():
		// Expected
	case <-time.After(time.Second * 2):
		t.Error("expected child context to timeout")
	}
}
