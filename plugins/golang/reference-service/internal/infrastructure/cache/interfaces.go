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

// Cache defines the interface for cache operations.
type Cache[K comparable, V any] interface {
	// Set stores a value with the given key and TTL.
	Set(key K, value V, ttl time.Duration) error

	// Get retrieves a value by key.
	Get(key K) (V, error)

	// Delete removes a value by key.
	Delete(key K)

	// Clear removes all entries from the cache.
	Clear()

	// Size returns the number of entries in the cache.
	Size() int
}
