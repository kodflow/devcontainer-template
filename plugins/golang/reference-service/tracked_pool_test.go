package taskqueue_test

import (
	"bytes"
	"testing"

	"taskqueue"
)

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

func TestTrackedPool_ConcurrentOperations(t *testing.T) {
	t.Parallel()

	pool := taskqueue.NewTrackedPool(func() interface{} {
		return &bytes.Buffer{}
	})

	const goroutines = 50
	const operations = 100

	done := make(chan bool, goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			for j := 0; j < operations; j++ {
				obj := pool.Get()
				if obj == nil {
					t.Error("expected non-nil object")
				}
				pool.Put(obj)
			}
			done <- true
		}()
	}

	for i := 0; i < goroutines; i++ {
		<-done
	}

	stats := pool.GetStats()
	if stats.Gets == 0 {
		t.Error("expected non-zero gets")
	}
	if stats.Puts == 0 {
		t.Error("expected non-zero puts")
	}
}
