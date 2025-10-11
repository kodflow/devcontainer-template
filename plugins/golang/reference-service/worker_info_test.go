package taskqueue_test

import (
	"testing"
	"time"

	"taskqueue"
)

func TestWorkerInfo_Creation(t *testing.T) {
	t.Parallel()

	info := taskqueue.WorkerInfo{
		ID:        1,
		StartTime: time.Now(),
	}
	info.Active.Store(true)
	info.TasksCount.Store(5)

	if info.ID != 1 {
		t.Error("expected ID to be 1")
	}
	if !info.Active.Load() {
		t.Error("expected worker to be active")
	}
	if info.TasksCount.Load() != 5 {
		t.Error("expected task count to be 5")
	}
}

func TestWorkerInfo_AtomicOperations(t *testing.T) {
	t.Parallel()

	info := taskqueue.WorkerInfo{ID: 1}

	// Test atomic bool
	info.Active.Store(true)
	if !info.Active.Load() {
		t.Error("expected active to be true")
	}

	info.Active.Store(false)
	if info.Active.Load() {
		t.Error("expected active to be false")
	}

	// Test atomic counter
	info.TasksCount.Add(1)
	info.TasksCount.Add(1)
	info.TasksCount.Add(1)

	if info.TasksCount.Load() != 3 {
		t.Errorf("expected task count to be 3, got %d", info.TasksCount.Load())
	}
}

func TestWorkerInfo_CurrentTask(t *testing.T) {
	t.Parallel()

	info := taskqueue.WorkerInfo{ID: 1}

	task := &taskqueue.Task{
		ID:     "task-1",
		Type:   "email",
		Status: taskqueue.TaskStatusProcessing,
	}

	info.CurrentTask.Store(task)

	loaded := info.CurrentTask.Load()
	if loaded == nil {
		t.Fatal("expected task to be set")
	}

	loadedTask := loaded.(*taskqueue.Task)
	if loadedTask.ID != "task-1" {
		t.Error("expected task ID to match")
	}

	// Clear task
	info.CurrentTask.Store((*taskqueue.Task)(nil))

	loaded = info.CurrentTask.Load()
	if loaded != nil {
		t.Error("expected task to be cleared")
	}
}

func TestWorkerInfo_ConcurrentUpdates(t *testing.T) {
	t.Parallel()

	info := taskqueue.WorkerInfo{ID: 1}
	const goroutines = 100

	done := make(chan bool, goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			info.TasksCount.Add(1)
			info.Active.Store(true)
			info.Active.Store(false)
			done <- true
		}()
	}

	for i := 0; i < goroutines; i++ {
		<-done
	}

	if info.TasksCount.Load() != 100 {
		t.Errorf("expected task count to be 100, got %d", info.TasksCount.Load())
	}
}
