package taskqueue_test

import (
	"log/slog"
	"sync"
	"testing"

	"taskqueue"
)

func TestMetricsCollector_Singleton(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetMetricsCollector returns global singleton

	collector1 := taskqueue.GetMetricsCollector(slog.Default())
	collector2 := taskqueue.GetMetricsCollector(slog.Default())

	if collector1 != collector2 {
		t.Error("expected GetMetricsCollector to return same instance")
	}
}

func TestMetricsCollector_RecordAndGetMetric(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetMetricsCollector returns global singleton

	collector := taskqueue.GetMetricsCollector(slog.Default())

	collector.RecordMetric("test_metric", 42.0)

	value, exists := collector.GetMetric("test_metric")
	if !exists {
		t.Fatal("expected metric to exist")
	}
	if value != 42.0 {
		t.Errorf("expected value 42.0, got %f", value)
	}
}

func TestMetricsCollector_ConcurrentRecording(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetMetricsCollector returns global singleton

	collector := taskqueue.GetMetricsCollector(slog.Default())
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()
			metricName := string(rune(id + 3000))
			collector.RecordMetric(metricName, float64(id))
		}(i)
	}

	wg.Wait()
}

func TestMetricsCollector_GetNonExistent(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetMetricsCollector returns global singleton

	collector := taskqueue.GetMetricsCollector(slog.Default())

	_, exists := collector.GetMetric("non_existent_metric")
	if exists {
		t.Error("expected metric to not exist")
	}
}
