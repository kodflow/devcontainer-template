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

// Resettable defines the interface for resettable synchronization primitives.
type Resettable interface {
	// Reset resets the state to allow re-execution.
	Reset()

	// IsInitialized returns true if Do has been executed.
	IsInitialized() bool
}
