package taskqueue_test

import (
	"testing"

	"taskqueue"
)

func TestPoolStats_AtomicOperations(t *testing.T) {
	t.Parallel()

	var stats taskqueue.PoolStats

	// Test atomic increments
	stats.Gets.Add(1)
	stats.Puts.Add(1)
	stats.News.Add(1)
	stats.Hits.Add(1)

	if stats.Gets.Load() != 1 {
		t.Error("expected Gets to be 1")
	}
	if stats.Puts.Load() != 1 {
		t.Error("expected Puts to be 1")
	}
	if stats.News.Load() != 1 {
		t.Error("expected News to be 1")
	}
	if stats.Hits.Load() != 1 {
		t.Error("expected Hits to be 1")
	}
}

func TestPoolStats_ConcurrentIncrements(t *testing.T) {
	t.Parallel()

	var stats taskqueue.PoolStats
	const goroutines = 100
	const increments = 1000

	done := make(chan bool, goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			for j := 0; j < increments; j++ {
				stats.Gets.Add(1)
				stats.Puts.Add(1)
			}
			done <- true
		}()
	}

	for i := 0; i < goroutines; i++ {
		<-done
	}

	expected := uint64(goroutines * increments)
	if stats.Gets.Load() != expected {
		t.Errorf("expected Gets to be %d, got %d", expected, stats.Gets.Load())
	}
	if stats.Puts.Load() != expected {
		t.Errorf("expected Puts to be %d, got %d", expected, stats.Puts.Load())
	}
}
