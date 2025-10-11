// Package sync provides advanced synchronization primitives.
//
// Purpose:
//   Implements resettable synchronization constructs for advanced use cases.
//
// Responsibilities:
//   - Provide resettable Once pattern
//   - Thread-safe reset operations
//
// Features:
//   - Concurrency Control
//   - Resettable Synchronization
//
// Constraints:
//   - Reset operations must be externally synchronized
//   - Not safe for concurrent resets
//
package sync

import (
	"sync/atomic"
)

// ResettableOnce is like sync.Once but can be reset.
// Fields ordered by size.
type ResettableOnce struct {
	state uint32 // 4 bytes - atomic state flag
}

// NewResettableOnce creates a new ResettableOnce.
func NewResettableOnce() *ResettableOnce {
	return &ResettableOnce{
		state: StateUninitialized,
	}
}

// Do executes the function f once until Reset is called.
func (o *ResettableOnce) Do(f func()) {
	if atomic.LoadUint32(&o.state) == StateInitialized {
		return
	}

	if atomic.CompareAndSwapUint32(&o.state, StateUninitialized, StateInitialized) {
		f()
	}
}

// Reset resets the once so Do can be called again.
func (o *ResettableOnce) Reset() {
	atomic.StoreUint32(&o.state, StateUninitialized)
}

// IsInitialized returns true if Do has been executed.
func (o *ResettableOnce) IsInitialized() bool {
	return atomic.LoadUint32(&o.state) == StateInitialized
}
