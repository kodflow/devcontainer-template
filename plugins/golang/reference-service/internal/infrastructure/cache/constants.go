// Package cache provides an in-memory cache implementation with TTL support.
//
// Purpose:
//   Implements a thread-safe generic cache with time-to-live expiration.
//
// Responsibilities:
//   - Store and retrieve cached values
//   - Automatic expiration based on TTL
//   - Thread-safe operations
//
// Features:
//   - Cache
//   - Concurrency Control
//   - TTL Expiration
//
// Constraints:
//   - Limited by available memory
//   - No persistent storage
//   - Maximum 10000 entries per cache instance
//
package cache

import "time"

const (
	// DefaultTTL is the default time-to-live for cache entries.
	DefaultTTL = 5 * time.Minute

	// DefaultMaxEntries is the maximum number of entries allowed.
	DefaultMaxEntries = 10000

	// DefaultCleanupInterval is how often expired entries are removed.
	DefaultCleanupInterval = 1 * time.Minute
)
