// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates resettable sync.Once pattern for testing purposes only.
//
// Responsibilities:
//   - Resettable one-time execution pattern (testing only)
//   - Thread-safe function execution control
//   - Reset capability for test scenarios
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
	"sync"
	"sync/atomic"
)

// ResetOnce demonstrates resetting sync.Once (testing only).
// CRITICAL: Never do this in production code.
type ResettableOnce struct {
	mu   sync.Mutex
	done atomic.Bool
}

// Do executes function once (resettable for testing).
func (o *ResettableOnce) Do(f func()) {
	if o.done.Load() {
		return
	}

	o.mu.Lock()
	defer o.mu.Unlock()

	if o.done.Load() {
		return
	}

	f()
	o.done.Store(true)
}

// Reset allows Do to be called again (testing only).
func (o *ResettableOnce) Reset() {
	o.done.Store(false)
}
