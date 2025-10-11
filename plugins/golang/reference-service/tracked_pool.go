// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   sync.Pool wrapper with statistics tracking.
//
// Responsibilities:
//   - Wrap sync.Pool with metrics
//   - Track hit ratios
//   - Monitor pool effectiveness
//
// Features:
//   - None
//
// Constraints:
//   - Development/debugging tool only
//   - Adds overhead to pool operations
//
package taskqueue

import (
	"sync"
	"sync/atomic"
)

// TrackedPool wraps sync.Pool with statistics.
// Use in development to verify pool is effective.
type TrackedPool struct {
	pool  sync.Pool
	stats PoolStats
}

// NewTrackedPool creates a pool with statistics tracking.
func NewTrackedPool(newFunc func() interface{}) *TrackedPool {
	tp := &TrackedPool{}
	tp.pool.New = func() interface{} {
		tp.stats.News.Add(1)
		return newFunc()
	}
	return tp
}

// Get retrieves object from pool with tracking.
func (tp *TrackedPool) Get() interface{} {
	tp.stats.Gets.Add(1)
	obj := tp.pool.Get()

	// If object came from pool (not newly created), count as hit
	if tp.stats.Puts.Load() > 0 {
		tp.stats.Hits.Add(1)
	}

	return obj
}

// Put returns object to pool with tracking.
func (tp *TrackedPool) Put(obj interface{}) {
	tp.stats.Puts.Add(1)
	tp.pool.Put(obj)
}

// GetStats returns current pool statistics.
func (tp *TrackedPool) GetStats() PoolStats {
	stats := PoolStats{
		Gets: atomic.Uint64{},
		Puts: atomic.Uint64{},
		News: atomic.Uint64{},
		Hits: atomic.Uint64{},
	}

	gets := tp.stats.Gets.Load()
	hits := tp.stats.Hits.Load()

	if gets > 0 {
		stats.Ratio = float64(hits) / float64(gets) * 100
	}

	return stats
}
