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

import (
	"sync"
	"time"
)

// entry represents a cached value with expiration time.
// Fields ordered by size.
type entry[V any] struct {
	expiresAt time.Time // 24 bytes
	value     V         // Variable size
}

// MemoryCache implements Cache interface with in-memory storage.
type MemoryCache[K comparable, V any] struct {
	entries map[K]entry[V]
	mu      sync.RWMutex
	limit   int
}

// Config holds configuration for creating a new MemoryCache.
type Config struct {
	MaxEntries int
}

// NewMemoryCache creates a new in-memory cache.
func NewMemoryCache[K comparable, V any](cfg Config) (*MemoryCache[K, V], error) {
	if cfg.MaxEntries <= 0 {
		cfg.MaxEntries = DefaultMaxEntries
	}

	return &MemoryCache[K, V]{
		entries: make(map[K]entry[V], cfg.MaxEntries),
		limit:   cfg.MaxEntries,
	}, nil
}

// Set stores a value with TTL.
func (c *MemoryCache[K, V]) Set(key K, value V, ttl time.Duration) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if len(c.entries) >= c.limit {
		if _, exists := c.entries[key]; !exists {
			return ErrCacheFull
		}
	}

	c.entries[key] = entry[V]{
		value:     value,
		expiresAt: time.Now().Add(ttl),
	}

	return nil
}

// Get retrieves a value by key.
func (c *MemoryCache[K, V]) Get(key K) (V, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	e, exists := c.entries[key]
	if !exists {
		var zero V
		return zero, ErrNotFound
	}

	if time.Now().After(e.expiresAt) {
		var zero V
		return zero, ErrExpired
	}

	return e.value, nil
}

// Delete removes a value by key.
func (c *MemoryCache[K, V]) Delete(key K) {
	c.mu.Lock()
	defer c.mu.Unlock()

	delete(c.entries, key)
}

// Clear removes all entries.
func (c *MemoryCache[K, V]) Clear() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.entries = make(map[K]entry[V], c.limit)
}

// Size returns the number of entries.
func (c *MemoryCache[K, V]) Size() int {
	c.mu.RLock()
	defer c.mu.RUnlock()

	return len(c.entries)
}
