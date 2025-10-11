package pool_test

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/pool"
)

func TestNewWorkerPool_Success(t *testing.T) {
	t.Parallel()

	p, err := pool.NewWorkerPool(pool.Config{WorkerCount: 5, QueueSize: 10})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if p == nil {
		t.Fatal("expected pool to be created")
	}

	p.Shutdown(context.Background())
}

func TestWorkerPool_Submit_Success(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})
	defer p.Shutdown(context.Background())

	var executed int32
	task := func(ctx context.Context) error {
		atomic.AddInt32(&executed, 1)
		return nil
	}

	err := p.Submit(context.Background(), task)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	time.Sleep(50 * time.Millisecond)

	if atomic.LoadInt32(&executed) != 1 {
		t.Errorf("expected task to be executed once")
	}
}

func TestWorkerPool_CompletedTasks(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})
	defer p.Shutdown(context.Background())

	task := func(ctx context.Context) error {
		return nil
	}

	for i := 0; i < 5; i++ {
		p.Submit(context.Background(), task)
	}

	time.Sleep(100 * time.Millisecond)

	completed := p.CompletedTasks()
	if completed != 5 {
		t.Errorf("expected 5 completed tasks, got %d", completed)
	}
}

func TestWorkerPool_Shutdown(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})

	err := p.Shutdown(context.Background())
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	err = p.Submit(context.Background(), func(ctx context.Context) error { return nil })
	if err != pool.ErrPoolClosed {
		t.Errorf("expected ErrPoolClosed after shutdown, got %v", err)
	}
}

func TestWorkerPool_ActiveWorkers(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 7, QueueSize: 10})
	defer p.Shutdown(context.Background())

	if p.ActiveWorkers() != 7 {
		t.Errorf("expected 7 active workers, got %d", p.ActiveWorkers())
	}
}

func TestNewWorkerPool_DefaultWorkerCount(t *testing.T) {
	t.Parallel()

	// Test with WorkerCount = 0 (should use default)
	p, err := pool.NewWorkerPool(pool.Config{WorkerCount: 0, QueueSize: 10})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	defer p.Shutdown(context.Background())

	if p == nil {
		t.Fatal("expected pool to be created with default worker count")
	}

	// Should have DefaultWorkerCount workers
	if p.ActiveWorkers() <= 0 {
		t.Error("expected positive worker count with default config")
	}
}

func TestNewWorkerPool_NegativeWorkerCount(t *testing.T) {
	t.Parallel()

	// Test with negative WorkerCount (should use default)
	p, err := pool.NewWorkerPool(pool.Config{WorkerCount: -5, QueueSize: 10})
	if err != nil {
		t.Fatalf("expected no error (should use default), got %v", err)
	}
	defer p.Shutdown(context.Background())

	if p == nil {
		t.Fatal("expected pool to be created with default worker count")
	}
}

func TestNewWorkerPool_ExceedsMaxWorkerCount(t *testing.T) {
	t.Parallel()

	// Test with WorkerCount > MaxWorkerCount
	_, err := pool.NewWorkerPool(pool.Config{WorkerCount: 1001, QueueSize: 10})

	if err != pool.ErrInvalidWorkerCount {
		t.Errorf("expected ErrInvalidWorkerCount, got %v", err)
	}
}

func TestNewWorkerPool_DefaultQueueSize(t *testing.T) {
	t.Parallel()

	// Test with QueueSize = 0 (should use default)
	p, err := pool.NewWorkerPool(pool.Config{WorkerCount: 5, QueueSize: 0})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	defer p.Shutdown(context.Background())

	if p == nil {
		t.Fatal("expected pool to be created with default queue size")
	}
}

func TestNewWorkerPool_NegativeQueueSize(t *testing.T) {
	t.Parallel()

	// Test with negative QueueSize (should use default)
	p, err := pool.NewWorkerPool(pool.Config{WorkerCount: 5, QueueSize: -10})
	if err != nil {
		t.Fatalf("expected no error (should use default), got %v", err)
	}
	defer p.Shutdown(context.Background())

	if p == nil {
		t.Fatal("expected pool to be created with default queue size")
	}
}

func TestWorkerPool_Submit_ContextCancellation(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 1, QueueSize: 1})
	defer p.Shutdown(context.Background())

	// Fill the queue
	p.Submit(context.Background(), func(ctx context.Context) error {
		time.Sleep(100 * time.Millisecond)
		return nil
	})

	// Try to submit with cancelled context
	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	err := p.Submit(ctx, func(ctx context.Context) error { return nil })
	if err != context.Canceled {
		t.Errorf("expected context.Canceled, got %v", err)
	}
}

func TestWorkerPool_Submit_QueueFull(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 1, QueueSize: 2})
	defer p.Shutdown(context.Background())

	// Fill the queue with slow tasks
	slowTask := func(ctx context.Context) error {
		time.Sleep(200 * time.Millisecond)
		return nil
	}

	// Submit tasks to fill queue
	p.Submit(context.Background(), slowTask)
	p.Submit(context.Background(), slowTask)

	// Try to submit when queue is full (non-blocking)
	err := p.Submit(context.Background(), slowTask)
	if err != pool.ErrQueueFull {
		t.Errorf("expected ErrQueueFull, got %v", err)
	}
}

func TestWorkerPool_Submit_AfterShutdown(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})

	// Shutdown the pool
	err := p.Shutdown(context.Background())
	if err != nil {
		t.Fatalf("expected no error on shutdown, got %v", err)
	}

	// Try to submit after shutdown
	err = p.Submit(context.Background(), func(ctx context.Context) error { return nil })
	if err != pool.ErrPoolClosed {
		t.Errorf("expected ErrPoolClosed, got %v", err)
	}
}

func TestWorkerPool_Shutdown_Twice(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})

	// First shutdown
	err := p.Shutdown(context.Background())
	if err != nil {
		t.Fatalf("expected no error on first shutdown, got %v", err)
	}

	// Second shutdown should fail
	err = p.Shutdown(context.Background())
	if err != pool.ErrPoolClosed {
		t.Errorf("expected ErrPoolClosed on second shutdown, got %v", err)
	}
}

func TestWorkerPool_Shutdown_WithContextTimeout(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})

	// Submit long-running tasks
	for i := 0; i < 5; i++ {
		p.Submit(context.Background(), func(ctx context.Context) error {
			time.Sleep(500 * time.Millisecond)
			return nil
		})
	}

	// Try to shutdown with short timeout
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()

	err := p.Shutdown(ctx)
	if err != context.DeadlineExceeded {
		t.Errorf("expected context.DeadlineExceeded, got %v", err)
	}
}

func TestWorkerPool_Shutdown_WaitsForTasks(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})

	var executed int32
	task := func(ctx context.Context) error {
		time.Sleep(50 * time.Millisecond)
		atomic.AddInt32(&executed, 1)
		return nil
	}

	// Submit tasks
	for i := 0; i < 5; i++ {
		p.Submit(context.Background(), task)
	}

	// Shutdown should wait for all tasks to complete
	err := p.Shutdown(context.Background())
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	// All tasks should have executed
	if atomic.LoadInt32(&executed) != 5 {
		t.Errorf("expected 5 tasks executed, got %d", atomic.LoadInt32(&executed))
	}
}

func TestWorkerPool_CompletedTasks_InitiallyZero(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})
	defer p.Shutdown(context.Background())

	if p.CompletedTasks() != 0 {
		t.Errorf("expected 0 completed tasks initially, got %d", p.CompletedTasks())
	}
}

func TestWorkerPool_ConcurrentSubmits(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 10, QueueSize: 100})
	defer p.Shutdown(context.Background())

	var executed int32
	task := func(ctx context.Context) error {
		atomic.AddInt32(&executed, 1)
		return nil
	}

	// Submit tasks concurrently from multiple goroutines
	var wg sync.WaitGroup
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for j := 0; j < 10; j++ {
				p.Submit(context.Background(), task)
			}
		}()
	}

	wg.Wait()
	time.Sleep(200 * time.Millisecond)

	if atomic.LoadInt32(&executed) != 100 {
		t.Errorf("expected 100 tasks executed, got %d", atomic.LoadInt32(&executed))
	}
}

func TestWorkerPool_TaskWithError(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 2, QueueSize: 10})
	defer p.Shutdown(context.Background())

	// Task that returns an error (currently ignored by worker)
	task := func(ctx context.Context) error {
		return context.Canceled
	}

	err := p.Submit(context.Background(), task)
	if err != nil {
		t.Fatalf("expected no error on submit, got %v", err)
	}

	time.Sleep(50 * time.Millisecond)

	// Verify task was counted as completed even with error
	if p.CompletedTasks() != 1 {
		t.Errorf("expected 1 completed task (error is ignored), got %d", p.CompletedTasks())
	}
}

func TestWorkerPool_MultipleWorkers_ProcessConcurrently(t *testing.T) {
	t.Parallel()

	p, _ := pool.NewWorkerPool(pool.Config{WorkerCount: 5, QueueSize: 50})
	defer p.Shutdown(context.Background())

	var maxConcurrent int32
	var currentConcurrent int32

	task := func(ctx context.Context) error {
		current := atomic.AddInt32(&currentConcurrent, 1)

		// Update max concurrent
		for {
			max := atomic.LoadInt32(&maxConcurrent)
			if current <= max || atomic.CompareAndSwapInt32(&maxConcurrent, max, current) {
				break
			}
		}

		time.Sleep(50 * time.Millisecond)
		atomic.AddInt32(&currentConcurrent, -1)
		return nil
	}

	// Submit tasks
	for i := 0; i < 20; i++ {
		p.Submit(context.Background(), task)
	}

	time.Sleep(300 * time.Millisecond)

	// Verify multiple workers executed concurrently
	max := atomic.LoadInt32(&maxConcurrent)
	if max < 2 {
		t.Errorf("expected at least 2 concurrent workers, got %d", max)
	}
}
