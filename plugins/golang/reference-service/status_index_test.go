package taskqueue_test

import (
	"sync"
	"testing"

	"taskqueue"
)

func TestStatusIndex_IncrementAndGet(t *testing.T) {
	t.Parallel()

	index := taskqueue.NewStatusIndex()

	index.Increment(taskqueue.TaskStatusPending)
	index.Increment(taskqueue.TaskStatusPending)
	index.Increment(taskqueue.TaskStatusProcessing)

	if index.Get(taskqueue.TaskStatusPending) != 2 {
		t.Error("expected 2 pending tasks")
	}
	if index.Get(taskqueue.TaskStatusProcessing) != 1 {
		t.Error("expected 1 processing task")
	}
	if index.Get(taskqueue.TaskStatusCompleted) != 0 {
		t.Error("expected 0 completed tasks")
	}
}

func TestStatusIndex_Decrement(t *testing.T) {
	t.Parallel()

	index := taskqueue.NewStatusIndex()

	index.Increment(taskqueue.TaskStatusPending)
	index.Increment(taskqueue.TaskStatusPending)
	index.Increment(taskqueue.TaskStatusPending)

	index.Decrement(taskqueue.TaskStatusPending)

	if index.Get(taskqueue.TaskStatusPending) != 2 {
		t.Error("expected 2 pending tasks after decrement")
	}
}

func TestStatusIndex_GetAll(t *testing.T) {
	t.Parallel()

	index := taskqueue.NewStatusIndex()

	index.Increment(taskqueue.TaskStatusPending)
	index.Increment(taskqueue.TaskStatusPending)
	index.Increment(taskqueue.TaskStatusProcessing)
	index.Increment(taskqueue.TaskStatusCompleted)

	counts := index.GetAll()

	if counts[taskqueue.TaskStatusPending] != 2 {
		t.Error("expected 2 pending tasks")
	}
	if counts[taskqueue.TaskStatusProcessing] != 1 {
		t.Error("expected 1 processing task")
	}
	if counts[taskqueue.TaskStatusCompleted] != 1 {
		t.Error("expected 1 completed task")
	}
}

func TestStatusIndex_ConcurrentIncrements(t *testing.T) {
	t.Parallel()

	index := taskqueue.NewStatusIndex()
	const goroutines = 100
	const increments = 1000

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < increments; j++ {
				index.Increment(taskqueue.TaskStatusPending)
			}
		}()
	}

	wg.Wait()

	expected := uint64(goroutines * increments)
	if index.Get(taskqueue.TaskStatusPending) != expected {
		t.Errorf("expected %d pending tasks, got %d", expected, index.Get(taskqueue.TaskStatusPending))
	}
}

func TestStatusIndex_ConcurrentMixedOperations(t *testing.T) {
	t.Parallel()

	index := taskqueue.NewStatusIndex()
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines * 2)

	// Half increment
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < 100; j++ {
				index.Increment(taskqueue.TaskStatusPending)
			}
		}()
	}

	// Half decrement
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < 50; j++ {
				index.Decrement(taskqueue.TaskStatusPending)
			}
		}()
	}

	wg.Wait()

	// Should be (100 * 50) - (50 * 50) = 2500
	expected := uint64(2500)
	if index.Get(taskqueue.TaskStatusPending) != expected {
		t.Errorf("expected %d, got %d", expected, index.Get(taskqueue.TaskStatusPending))
	}
}
