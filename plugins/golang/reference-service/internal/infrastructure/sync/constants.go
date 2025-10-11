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

const (
	// StateUninitialized indicates the Once has not been executed.
	StateUninitialized uint32 = 0

	// StateInitialized indicates the Once has been executed.
	StateInitialized uint32 = 1
)
