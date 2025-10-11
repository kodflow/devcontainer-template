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

import "errors"

var (
	// ErrNotFound indicates the key was not found in the cache.
	ErrNotFound = errors.New("key not found in cache")

	// ErrExpired indicates the cached entry has expired.
	ErrExpired = errors.New("cached entry has expired")

	// ErrCacheFull indicates the cache has reached maximum capacity.
	ErrCacheFull = errors.New("cache is full")
)
