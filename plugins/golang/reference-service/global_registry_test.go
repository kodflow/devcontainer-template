package taskqueue_test

import (
	"sync"
	"testing"

	"taskqueue"
)

func TestGlobalRegistry_Singleton(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetRegistry returns global singleton

	registry1 := taskqueue.GetRegistry()
	registry2 := taskqueue.GetRegistry()

	if registry1 != registry2 {
		t.Error("expected GetRegistry to return same instance")
	}
}

func TestGlobalRegistry_RegisterAndGet(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetRegistry returns global singleton

	registry := taskqueue.GetRegistry()

	task := &taskqueue.Task{
		ID:     "global-task-1",
		Type:   "email",
		Status: taskqueue.TaskStatusPending,
	}

	registry.Register(task)

	retrieved, exists := registry.Get("global-task-1")
	if !exists {
		t.Fatal("expected task to be found")
	}
	if retrieved.ID != "global-task-1" {
		t.Error("expected task ID to match")
	}
}

func TestGlobalRegistry_ConcurrentAccess(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetRegistry returns global singleton

	registry := taskqueue.GetRegistry()
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()

			task := &taskqueue.Task{
				ID:     string(rune(id + 1000)), // Unique IDs
				Type:   "concurrent",
				Status: taskqueue.TaskStatusPending,
			}

			registry.Register(task)
			registry.Get(task.ID)
		}(i)
	}

	wg.Wait()
}

func TestGlobalRegistry_GetNonExistent(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetRegistry returns global singleton

	registry := taskqueue.GetRegistry()

	_, exists := registry.Get("non-existent-task")
	if exists {
		t.Error("expected task to not exist")
	}
}
