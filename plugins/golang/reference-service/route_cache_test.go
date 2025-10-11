package taskqueue_test

import (
	"sync"
	"testing"

	"taskqueue"
)

func TestRouteCache_GetOrCompute(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewRouteCache()
	calls := 0

	compute := func() int {
		calls++
		return 42
	}

	// First call should compute
	result1 := cache.GetOrCompute("email", compute)
	if result1 != 42 {
		t.Error("expected computed value 42")
	}
	if calls != 1 {
		t.Error("expected compute to be called once")
	}

	// Second call should use cached value
	result2 := cache.GetOrCompute("email", compute)
	if result2 != 42 {
		t.Error("expected cached value 42")
	}
	if calls != 1 {
		t.Error("expected compute not to be called again")
	}
}

func TestRouteCache_Invalidate(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewRouteCache()
	calls := 0

	compute := func() int {
		calls++
		return 42
	}

	// Compute and cache
	cache.GetOrCompute("email", compute)

	// Invalidate
	cache.Invalidate("email")

	// Should recompute
	cache.GetOrCompute("email", compute)
	if calls != 2 {
		t.Errorf("expected compute to be called twice, got %d", calls)
	}
}

func TestRouteCache_InvalidateAll(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewRouteCache()

	compute := func() int { return 42 }

	// Cache multiple routes
	cache.GetOrCompute("email", compute)
	cache.GetOrCompute("sms", compute)
	cache.GetOrCompute("push", compute)

	// Invalidate all
	cache.InvalidateAll()

	// All should recompute
	calls := 0
	computeCount := func() int {
		calls++
		return 42
	}

	cache.GetOrCompute("email", computeCount)
	cache.GetOrCompute("sms", computeCount)
	cache.GetOrCompute("push", computeCount)

	if calls != 3 {
		t.Errorf("expected 3 compute calls after invalidate all, got %d", calls)
	}
}

func TestRouteCache_ConcurrentGetOrCompute(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewRouteCache()
	var calls int32
	const goroutines = 100

	var wg sync.WaitGroup
	wg.Add(goroutines)

	compute := func() int {
		calls++
		return 42
	}

	// All goroutines try to compute same route
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			result := cache.GetOrCompute("email", compute)
			if result != 42 {
				t.Error("expected result 42")
			}
		}()
	}

	wg.Wait()

	// Compute should be called at least once, but LoadOrStore ensures consistency
	if calls == 0 {
		t.Error("expected compute to be called at least once")
	}
}

func TestRouteCache_MultipleTaskTypes(t *testing.T) {
	t.Parallel()

	cache := taskqueue.NewRouteCache()

	workerForEmail := cache.GetOrCompute("email", func() int { return 1 })
	workerForSms := cache.GetOrCompute("sms", func() int { return 2 })
	workerForPush := cache.GetOrCompute("push", func() int { return 3 })

	if workerForEmail != 1 {
		t.Error("expected email route to worker 1")
	}
	if workerForSms != 2 {
		t.Error("expected sms route to worker 2")
	}
	if workerForPush != 3 {
		t.Error("expected push route to worker 3")
	}

	// Verify cached values
	if cache.GetOrCompute("email", func() int { return 999 }) != 1 {
		t.Error("expected cached email route")
	}
}
