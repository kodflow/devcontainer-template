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

import "errors"

var (
	// ErrAlreadyInitialized indicates Do was called when already initialized.
	ErrAlreadyInitialized = errors.New("already initialized")
)
