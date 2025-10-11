package taskqueue_test

import (
	"sync"
	"sync/atomic"
	"testing"

	"taskqueue"
)

func TestResettableOnce_SingleExecution(t *testing.T) {
	t.Parallel()

	var once taskqueue.ResettableOnce
	var counter atomic.Int32

	once.Do(func() {
		counter.Add(1)
	})

	once.Do(func() {
		counter.Add(1)
	})

	if counter.Load() != 1 {
		t.Errorf("expected function to be called once, got %d", counter.Load())
	}
}

func TestResettableOnce_Reset(t *testing.T) {
	t.Parallel()

	var once taskqueue.ResettableOnce
	var counter atomic.Int32

	once.Do(func() {
		counter.Add(1)
	})

	if counter.Load() != 1 {
		t.Fatal("expected first call to execute")
	}

	once.Reset()

	once.Do(func() {
		counter.Add(1)
	})

	if counter.Load() != 2 {
		t.Errorf("expected function to be called after reset, got %d", counter.Load())
	}
}

func TestResettableOnce_ConcurrentCalls(t *testing.T) {
	t.Parallel()

	var once taskqueue.ResettableOnce
	var counter atomic.Int32
	const goroutines = 100

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			once.Do(func() {
				counter.Add(1)
			})
		}()
	}

	wg.Wait()

	if counter.Load() != 1 {
		t.Errorf("expected function to be called once despite concurrent calls, got %d", counter.Load())
	}
}

func TestResettableOnce_MultipleResets(t *testing.T) {
	t.Parallel()

	var once taskqueue.ResettableOnce
	var counter atomic.Int32

	for i := 0; i < 5; i++ {
		once.Do(func() {
			counter.Add(1)
		})
		once.Reset()
	}

	expected := int32(5)
	if counter.Load() != expected {
		t.Errorf("expected %d executions after %d resets, got %d", expected, expected, counter.Load())
	}
}
