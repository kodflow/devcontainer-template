// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Once for thread-safe singleton pattern implementation.
//
// Responsibilities:
//   - Singleton GlobalRegistry instance management
//   - Thread-safe task registration and retrieval
//   - One-time initialization guarantee for registry
//
// Features:
//   - Logging
//
// Constraints:
//   - Once.Do calls function exactly once
//   - Blocks concurrent calls until completion
//   - Cannot be reset
//
package taskqueue

import (
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
)

// GlobalRegistry is a singleton task registry.
// Uses sync.Once to ensure single initialization.
type GlobalRegistry struct {
	tasks      map[string]*Task
	mu         sync.RWMutex
	logger     *slog.Logger
	initTime   time.Time
	initCalled atomic.Bool
}

var (
	registryInstance *GlobalRegistry
	registryOnce     sync.Once
)

// GetRegistry returns the singleton registry instance.
// Thread-safe: First call initializes, subsequent calls return same instance.
//
// sync.Once guarantees:
//   - Function called exactly once
//   - All goroutines wait for first call to complete
//   - Subsequent calls return immediately (no lock contention)
func GetRegistry() *GlobalRegistry {
	registryOnce.Do(func() {
		registryInstance = &GlobalRegistry{
			tasks:    make(map[string]*Task, 1000),
			logger:   slog.Default(),
			initTime: time.Now(),
		}
		registryInstance.initCalled.Store(true)
		registryInstance.logger.Info("registry initialized",
			"time", time.Now().Format(time.RFC3339))
	})
	return registryInstance
}

// Register adds task to global registry.
func (r *GlobalRegistry) Register(task *Task) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.tasks[task.ID] = task
}

// Get retrieves task from registry.
func (r *GlobalRegistry) Get(taskID string) (*Task, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	task, exists := r.tasks[taskID]
	return task, exists
}
