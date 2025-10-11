package taskqueue_test

import (
	"sync"
	"testing"

	"taskqueue"
)

func TestTaskCache_StoreAndLoad(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()
	task := &taskqueue.Task{
		ID:     "task-1",
		Type:   "email",
		Status: taskqueue.TaskStatusPending,
	}

	cache.Store("task-1", task)

	loaded, ok := cache.Load("task-1")
	if !ok {
		t.Fatal("expected task to be found")
	}
	if loaded.ID != "task-1" {
		t.Error("expected task ID to match")
	}
}

func TestTaskCache_LoadOrStore(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()
	task1 := &taskqueue.Task{ID: "task-1", Type: "email"}
	task2 := &taskqueue.Task{ID: "task-1", Type: "sms"}

	// First call should store task1
	actual1, loaded1 := cache.LoadOrStore("task-1", task1)
	if loaded1 {
		t.Error("expected first call to store new value")
	}
	if actual1.Type != "email" {
		t.Error("expected first task to be stored")
	}

	// Second call should return task1, not store task2
	actual2, loaded2 := cache.LoadOrStore("task-1", task2)
	if !loaded2 {
		t.Error("expected second call to load existing value")
	}
	if actual2.Type != "email" {
		t.Error("expected existing task to be returned")
	}
}

func TestTaskCache_Delete(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()
	task := &taskqueue.Task{ID: "task-1"}

	cache.Store("task-1", task)
	cache.Delete("task-1")

	_, ok := cache.Load("task-1")
	if ok {
		t.Error("expected task to be deleted")
	}
}

func TestTaskCache_LoadAndDelete(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()
	task := &taskqueue.Task{ID: "task-1"}

	cache.Store("task-1", task)

	loaded, ok := cache.LoadAndDelete("task-1")
	if !ok {
		t.Fatal("expected task to be found")
	}
	if loaded.ID != "task-1" {
		t.Error("expected task ID to match")
	}

	// Verify deleted
	_, ok = cache.Load("task-1")
	if ok {
		t.Error("expected task to be deleted after LoadAndDelete")
	}
}

func TestTaskCache_Range(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()
	tasks := []*taskqueue.Task{
		{ID: "task-1"},
		{ID: "task-2"},
		{ID: "task-3"},
	}

	for _, task := range tasks {
		cache.Store(task.ID, task)
	}

	count := 0
	cache.Range(func(taskID string, task *taskqueue.Task) bool {
		count++
		return true
	})

	if count != 3 {
		t.Errorf("expected 3 tasks, got %d", count)
	}
}

func TestTaskCache_Count(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()

	if cache.Count() != 0 {
		t.Error("expected empty cache")
	}

	cache.Store("task-1", &taskqueue.Task{ID: "task-1"})
	cache.Store("task-2", &taskqueue.Task{ID: "task-2"})

	if cache.Count() != 2 {
		t.Errorf("expected 2 tasks, got %d", cache.Count())
	}
}

func TestTaskCache_ConcurrentOperations(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewTaskCache()
	const goroutines = 50
	const operations = 100

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			for j := 0; j < operations; j++ {
				taskID := string(rune(id*operations + j))
				task := &taskqueue.Task{ID: taskID}
				cache.Store(taskID, task)
				cache.Load(taskID)
				cache.Delete(taskID)
			}
		}(i)
	}

	wg.Wait()
}
