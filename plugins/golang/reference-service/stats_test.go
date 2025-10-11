// Package taskqueue_test statistics tests with concurrent access
//
// Purpose:
//   Tests for atomic statistics tracking.
//
// Responsibilities:
//   - Verify atomic operations correctness
//   - Test concurrent access safety
//   - Validate counter accuracy under load
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Must pass with -race flag
//   - Test high concurrency scenarios
//
package taskqueue_test

import (
	"sync"
	"testing"
	"time"

	"taskqueue"
)

func TestWorkerStats_Creation(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	if stats == nil {
		t.Fatal("expected non-nil stats")
	}

	if !stats.IsRunning() {
		t.Error("expected stats to be running after creation")
	}

	if stats.GetSubmitted() != 0 {
		t.Errorf("expected 0 submitted, got %d", stats.GetSubmitted())
	}
}

func TestWorkerStats_RecordSubmission(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	stats.RecordSubmission()

	if got := stats.GetSubmitted(); got != 1 {
		t.Errorf("expected 1 submission, got %d", got)
	}

	stats.RecordSubmission()
	stats.RecordSubmission()

	if got := stats.GetSubmitted(); got != 3 {
		t.Errorf("expected 3 submissions, got %d", got)
	}
}

func TestWorkerStats_RecordProcessed(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	stats.RecordProcessed(100 * time.Millisecond)

	if got := stats.GetProcessed(); got != 1 {
		t.Errorf("expected 1 processed, got %d", got)
	}

	if avg := stats.GetAverageProcessTime(); avg != 100*time.Millisecond {
		t.Errorf("expected 100ms average, got %v", avg)
	}
}

func TestWorkerStats_RecordFailed(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	stats.RecordFailed()

	if got := stats.GetFailed(); got != 1 {
		t.Errorf("expected 1 failed, got %d", got)
	}
}

func TestWorkerStats_RecordRetry(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	stats.RecordRetry()
	stats.RecordRetry()

	if got := stats.GetRetried(); got != 2 {
		t.Errorf("expected 2 retries, got %d", got)
	}
}

func TestWorkerStats_ActiveWorkers(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()

	stats.IncrementActive()
	if got := stats.GetActive(); got != 1 {
		t.Errorf("expected 1 active, got %d", got)
	}

	stats.IncrementActive()
	stats.IncrementActive()
	if got := stats.GetActive(); got != 3 {
		t.Errorf("expected 3 active, got %d", got)
	}

	stats.DecrementActive()
	if got := stats.GetActive(); got != 2 {
		t.Errorf("expected 2 active after decrement, got %d", got)
	}
}

func TestWorkerStats_AverageProcessTime(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()

	// No tasks processed yet
	if avg := stats.GetAverageProcessTime(); avg != 0 {
		t.Errorf("expected 0 average with no tasks, got %v", avg)
	}

	stats.RecordProcessed(100 * time.Millisecond)
	stats.RecordProcessed(200 * time.Millisecond)
	stats.RecordProcessed(300 * time.Millisecond)

	expected := 200 * time.Millisecond // (100+200+300)/3
	got := stats.GetAverageProcessTime()

	if got != expected {
		t.Errorf("expected %v average, got %v", expected, got)
	}
}

func TestWorkerStats_SuccessRate(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()

	// No tasks submitted yet
	if rate := stats.GetSuccessRate(); rate != 0 {
		t.Errorf("expected 0%% success rate with no tasks, got %.2f%%", rate)
	}

	// Submit 10, process 8
	for i := 0; i < 10; i++ {
		stats.RecordSubmission()
	}
	for i := 0; i < 8; i++ {
		stats.RecordProcessed(10 * time.Millisecond)
	}

	expected := 80.0 // 8/10 * 100
	got := stats.GetSuccessRate()

	if got != expected {
		t.Errorf("expected %.2f%% success rate, got %.2f%%", expected, got)
	}
}

func TestWorkerStats_Reset(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()

	stats.RecordSubmission()
	stats.RecordProcessed(100 * time.Millisecond)
	stats.RecordFailed()
	stats.IncrementActive()

	stats.Reset()

	if stats.GetSubmitted() != 0 {
		t.Error("expected submitted to be 0 after reset")
	}
	if stats.GetProcessed() != 0 {
		t.Error("expected processed to be 0 after reset")
	}
	if stats.GetFailed() != 0 {
		t.Error("expected failed to be 0 after reset")
	}
	if stats.GetActive() != 0 {
		t.Error("expected active to be 0 after reset")
	}
}

func TestWorkerStats_Stop(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()

	if !stats.IsRunning() {
		t.Error("expected stats to be running initially")
	}

	stats.Stop()

	if stats.IsRunning() {
		t.Error("expected stats to be stopped after Stop()")
	}
}

func TestWorkerStats_GetSnapshot(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()

	stats.RecordSubmission()
	stats.RecordSubmission()
	stats.RecordProcessed(100 * time.Millisecond)
	stats.RecordFailed()
	stats.IncrementActive()

	snapshot := stats.GetSnapshot()

	if snapshot.TasksSubmitted != 2 {
		t.Errorf("expected 2 submitted, got %d", snapshot.TasksSubmitted)
	}
	if snapshot.TasksProcessed != 1 {
		t.Errorf("expected 1 processed, got %d", snapshot.TasksProcessed)
	}
	if snapshot.TasksFailed != 1 {
		t.Errorf("expected 1 failed, got %d", snapshot.TasksFailed)
	}
	if snapshot.ActiveWorkers != 1 {
		t.Errorf("expected 1 active, got %d", snapshot.ActiveWorkers)
	}
}

// TestWorkerStats_ConcurrentSubmissions tests race-free concurrent submissions
func TestWorkerStats_ConcurrentSubmissions(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	const goroutines = 100
	const operationsPerGoroutine = 1000

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < operationsPerGoroutine; j++ {
				stats.RecordSubmission()
			}
		}()
	}

	wg.Wait()

	expected := uint64(goroutines * operationsPerGoroutine)
	got := stats.GetSubmitted()

	if got != expected {
		t.Errorf("expected %d submissions, got %d (lost %d updates)",
			expected, got, expected-got)
	}
}

// TestWorkerStats_ConcurrentMixedOperations tests all operations concurrently
func TestWorkerStats_ConcurrentMixedOperations(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	const goroutines = 50
	const opsPerGoroutine = 500

	var wg sync.WaitGroup
	wg.Add(goroutines * 4) // 4 types of operations

	// Concurrent submissions
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < opsPerGoroutine; j++ {
				stats.RecordSubmission()
			}
		}()
	}

	// Concurrent processed
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < opsPerGoroutine; j++ {
				stats.RecordProcessed(10 * time.Millisecond)
			}
		}()
	}

	// Concurrent failures
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < opsPerGoroutine; j++ {
				stats.RecordFailed()
			}
		}()
	}

	// Concurrent retries
	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < opsPerGoroutine; j++ {
				stats.RecordRetry()
			}
		}()
	}

	wg.Wait()

	expected := uint64(goroutines * opsPerGoroutine)

	if got := stats.GetSubmitted(); got != expected {
		t.Errorf("submissions: expected %d, got %d", expected, got)
	}
	if got := stats.GetProcessed(); got != expected {
		t.Errorf("processed: expected %d, got %d", expected, got)
	}
	if got := stats.GetFailed(); got != expected {
		t.Errorf("failed: expected %d, got %d", expected, got)
	}
	if got := stats.GetRetried(); got != expected {
		t.Errorf("retried: expected %d, got %d", expected, got)
	}
}

// TestWorkerStats_ConcurrentActiveWorkers tests increment/decrement races
func TestWorkerStats_ConcurrentActiveWorkers(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	const goroutines = 100
	const cycles = 1000

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < cycles; j++ {
				stats.IncrementActive()
				stats.DecrementActive()
			}
		}()
	}

	wg.Wait()

	// After all increments and decrements, should be 0
	if got := stats.GetActive(); got != 0 {
		t.Errorf("expected 0 active workers, got %d", got)
	}
}

// TestWorkerStats_ConcurrentReads tests concurrent reads don't race with writes
func TestWorkerStats_ConcurrentReads(t *testing.T) {
	t.Parallel()

	stats := taskqueue.NewWorkerStats()
	const writers = 10
	const readers = 50
	const operations = 1000

	var wg sync.WaitGroup
	wg.Add(writers + readers)

	// Writers
	for i := 0; i < writers; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < operations; j++ {
				stats.RecordSubmission()
				stats.RecordProcessed(5 * time.Millisecond)
			}
		}()
	}

	// Readers
	for i := 0; i < readers; i++ {
		go func() {
			defer wg.Done()
			for j := 0; j < operations; j++ {
				_ = stats.GetSubmitted()
				_ = stats.GetProcessed()
				_ = stats.GetAverageProcessTime()
				_ = stats.GetSuccessRate()
				_ = stats.GetSnapshot()
			}
		}()
	}

	wg.Wait()

	// No race conditions should occur (test with -race flag)
}

// BenchmarkWorkerStats_RecordSubmission benchmarks atomic increment
func BenchmarkWorkerStats_RecordSubmission(b *testing.B) {
	stats := taskqueue.NewWorkerStats()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		stats.RecordSubmission()
	}
}

// BenchmarkWorkerStats_RecordProcessed benchmarks processed with duration
func BenchmarkWorkerStats_RecordProcessed(b *testing.B) {
	stats := taskqueue.NewWorkerStats()
	duration := 10 * time.Millisecond

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		stats.RecordProcessed(duration)
	}
}

// BenchmarkWorkerStats_GetSnapshot benchmarks snapshot creation
func BenchmarkWorkerStats_GetSnapshot(b *testing.B) {
	stats := taskqueue.NewWorkerStats()

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = stats.GetSnapshot()
	}
}

// BenchmarkWorkerStats_ParallelSubmissions benchmarks parallel submissions
func BenchmarkWorkerStats_ParallelSubmissions(b *testing.B) {
	stats := taskqueue.NewWorkerStats()

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			stats.RecordSubmission()
		}
	})
}
