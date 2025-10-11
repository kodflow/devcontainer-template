// Package pool provides worker pool implementation for concurrent task processing.
//
// Purpose:
//   Implements a bounded worker pool for executing tasks concurrently.
//
// Responsibilities:
//   - Manage pool of worker goroutines
//   - Queue and dispatch tasks to workers
//   - Track active and completed tasks
//
// Features:
//   - Concurrency Control
//   - Task Queue
//   - Worker Management
//
// Constraints:
//   - Maximum 1000 workers per pool
//   - Tasks must be non-blocking
//   - Workers execute sequentially
//
package pool

import (
	"context"
	"sync"
	"sync/atomic"
)

// WorkerPool implements Pool interface with bounded workers.
// Fields ordered by size.
type WorkerPool struct {
	tasks     chan Task
	wg        sync.WaitGroup
	mu        sync.RWMutex
	completed int64 // atomic counter
	workers   int
	closed    uint32 // atomic flag: 0=open, 1=closed
}

// Config holds configuration for creating a WorkerPool.
type Config struct {
	WorkerCount int
	QueueSize   int
}

// NewWorkerPool creates a new worker pool.
func NewWorkerPool(cfg Config) (*WorkerPool, error) {
	if cfg.WorkerCount <= 0 {
		cfg.WorkerCount = DefaultWorkerCount
	}

	if cfg.WorkerCount > MaxWorkerCount {
		return nil, ErrInvalidWorkerCount
	}

	if cfg.QueueSize <= 0 {
		cfg.QueueSize = DefaultQueueSize
	}

	pool := &WorkerPool{
		tasks:   make(chan Task, cfg.QueueSize),
		workers: cfg.WorkerCount,
		closed:  0,
	}

	pool.start()

	return pool, nil
}

func (p *WorkerPool) start() {
	for i := 0; i < p.workers; i++ {
		p.wg.Add(1)
		go p.worker()
	}
}

func (p *WorkerPool) worker() {
	defer p.wg.Done()

	for task := range p.tasks {
		ctx := context.Background()
		_ = task(ctx)
		atomic.AddInt64(&p.completed, 1)
	}
}

// Submit adds a task to the pool.
func (p *WorkerPool) Submit(ctx context.Context, task Task) error {
	if atomic.LoadUint32(&p.closed) == 1 {
		return ErrPoolClosed
	}

	select {
	case p.tasks <- task:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	default:
		return ErrQueueFull
	}
}

// Shutdown stops the pool gracefully.
func (p *WorkerPool) Shutdown(ctx context.Context) error {
	if !atomic.CompareAndSwapUint32(&p.closed, 0, 1) {
		return ErrPoolClosed
	}

	close(p.tasks)

	done := make(chan struct{})
	go func() {
		p.wg.Wait()
		close(done)
	}()

	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// ActiveWorkers returns the current worker count.
func (p *WorkerPool) ActiveWorkers() int {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return p.workers
}

// CompletedTasks returns total completed tasks.
func (p *WorkerPool) CompletedTasks() int64 {
	return atomic.LoadInt64(&p.completed)
}
