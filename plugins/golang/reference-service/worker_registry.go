// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Map for tracking active workers with disjoint key sets.
//
// Responsibilities:
//   - Concurrent worker registration and unregistration
//   - Worker task assignment tracking
//   - Active worker counting
//
// Features:
//   - None (Pure concurrency primitives)
//
// Constraints:
//   - Optimized for disjoint key sets (each worker has unique ID)
//   - No range-over-map support (use Range method)
//   - Type assertions required (interface{} storage)
//
package taskqueue

import (
	"sync"
	"sync/atomic"
	"time"
)

// WorkerRegistry tracks active workers with sync.Map.
// Demonstrates disjoint key sets (each worker has unique ID).
type WorkerRegistry struct {
	workers sync.Map // key: workerID (int), value: *WorkerInfo
}

// NewWorkerRegistry creates a worker registry.
func NewWorkerRegistry() *WorkerRegistry {
	return &WorkerRegistry{}
}

// Register registers a worker.
func (r *WorkerRegistry) Register(workerID int) {
	info := &WorkerInfo{
		ID:        workerID,
		StartTime: time.Now(),
	}
	info.Active.Store(true)
	r.workers.Store(workerID, info)
}

// Unregister removes a worker.
func (r *WorkerRegistry) Unregister(workerID int) {
	r.workers.Delete(workerID)
}

// SetTask sets current task for worker.
func (r *WorkerRegistry) SetTask(workerID int, task *Task) {
	value, ok := r.workers.Load(workerID)
	if !ok {
		return
	}

	info := value.(*WorkerInfo)
	info.CurrentTask.Store(task)
	info.TasksCount.Add(1)
}

// ClearTask clears current task for worker.
func (r *WorkerRegistry) ClearTask(workerID int) {
	value, ok := r.workers.Load(workerID)
	if !ok {
		return
	}

	info := value.(*WorkerInfo)
	info.CurrentTask.Store((*Task)(nil))
}

// GetInfo returns worker info.
func (r *WorkerRegistry) GetInfo(workerID int) (*WorkerInfo, bool) {
	value, ok := r.workers.Load(workerID)
	if !ok {
		return nil, false
	}
	return value.(*WorkerInfo), true
}

// ActiveCount returns number of active workers.
func (r *WorkerRegistry) ActiveCount() int {
	count := 0
	r.workers.Range(func(_, value interface{}) bool {
		info := value.(*WorkerInfo)
		if info.Active.Load() {
			count++
		}
		return true
	})
	return count
}
