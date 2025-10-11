package taskqueue_test

import (
	"sync"
	"testing"

	"taskqueue"
)

func TestWorkerRegistry_RegisterAndUnregister(t *testing.T) {
	t.Parallel()

	registry := taskqueue.NewWorkerRegistry()

	registry.Register(1)

	info, ok := registry.GetInfo(1)
	if !ok {
		t.Fatal("expected worker to be registered")
	}
	if info.ID != 1 {
		t.Error("expected worker ID to match")
	}
	if !info.Active.Load() {
		t.Error("expected worker to be active")
	}

	registry.Unregister(1)

	_, ok = registry.GetInfo(1)
	if ok {
		t.Error("expected worker to be unregistered")
	}
}

func TestWorkerRegistry_SetAndClearTask(t *testing.T) {
	t.Parallel()

	registry := taskqueue.NewWorkerRegistry()
	registry.Register(1)

	task := &taskqueue.Task{
		ID:     "task-1",
		Type:   "email",
		Status: taskqueue.TaskStatusProcessing,
	}

	registry.SetTask(1, task)

	info, _ := registry.GetInfo(1)
	if info.TasksCount.Load() != 1 {
		t.Error("expected task count to be 1")
	}

	currentTask := info.CurrentTask.Load()
	if currentTask == nil {
		t.Fatal("expected current task to be set")
	}
	if currentTask.(*taskqueue.Task).ID != "task-1" {
		t.Error("expected task ID to match")
	}

	registry.ClearTask(1)

	currentTask = info.CurrentTask.Load()
	if currentTask != nil {
		t.Error("expected current task to be cleared")
	}
}

func TestWorkerRegistry_ActiveCount(t *testing.T) {
	t.Parallel()

	registry := taskqueue.NewWorkerRegistry()

	registry.Register(1)
	registry.Register(2)
	registry.Register(3)

	if registry.ActiveCount() != 3 {
		t.Errorf("expected 3 active workers, got %d", registry.ActiveCount())
	}

	// Deactivate one worker
	info, _ := registry.GetInfo(2)
	info.Active.Store(false)

	if registry.ActiveCount() != 2 {
		t.Errorf("expected 2 active workers, got %d", registry.ActiveCount())
	}
}

func TestWorkerRegistry_ConcurrentOperations(t *testing.T) {
	t.Parallel()

	registry := taskqueue.NewWorkerRegistry()
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			registry.Register(id)
			task := &taskqueue.Task{ID: "task"}
			registry.SetTask(id, task)
			registry.ClearTask(id)
			registry.GetInfo(id)
			registry.Unregister(id)
		}(i)
	}

	wg.Wait()
}
