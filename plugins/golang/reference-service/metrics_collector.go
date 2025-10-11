// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Once combined with atomic operations for metrics collection.
//
// Responsibilities:
//   - Metrics collection with lazy initialization
//   - Thread-safe metrics recording
//   - One-time initialization of statistics tracking
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

// MetricsCollector collects metrics with lazy initialization.
// Demonstrates combining sync.Once with atomic operations.
type MetricsCollector struct {
	stats      *WorkerStats
	initOnce   sync.Once
	enabled    atomic.Bool
	sampleRate float64
}

// NewMetricsCollector creates a metrics collector.
func NewMetricsCollector(sampleRate float64) *MetricsCollector {
	return &MetricsCollector{
		sampleRate: sampleRate,
	}
}

// Init initializes metrics collection once.
func (m *MetricsCollector) Init() *WorkerStats {
	m.initOnce.Do(func() {
		m.stats = NewWorkerStats()
		m.enabled.Store(true)
	})
	return m.stats
}

// Record records a metric (initializes if needed).
func (m *MetricsCollector) Record() {
	stats := m.Init()
	if m.enabled.Load() {
		stats.RecordSubmission()
	}
}
