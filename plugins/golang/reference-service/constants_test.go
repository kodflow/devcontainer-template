// Package taskqueue_test constants validation tests
//
// Purpose:
//   Tests for package constants and default values.
//
// Responsibilities:
//   - Verify constant values
//   - Verify bitwise flag values
//   - Ensure no magic numbers
//
// Features:
//   - None (Test code only)
//
// Constraints:
//   - Test all constants
//
package taskqueue_test

import (
	"testing"
	"time"

	"taskqueue"
)

func TestConstants_Defaults(t *testing.T) {
	t.Parallel()

	if taskqueue.DefaultWorkerCount != 5 {
		t.Errorf("expected DefaultWorkerCount 5, got %d", taskqueue.DefaultWorkerCount)
	}

	if taskqueue.DefaultBufferSize != 100 {
		t.Errorf("expected DefaultBufferSize 100, got %d", taskqueue.DefaultBufferSize)
	}

	if taskqueue.DefaultShutdownTimeout != 30*time.Second {
		t.Errorf("expected DefaultShutdownTimeout 30s, got %v", taskqueue.DefaultShutdownTimeout)
	}

	if taskqueue.DefaultProcessTimeout != 60*time.Second {
		t.Errorf("expected DefaultProcessTimeout 60s, got %v", taskqueue.DefaultProcessTimeout)
	}

	if taskqueue.MaxRetryLimit != 10 {
		t.Errorf("expected MaxRetryLimit 10, got %d", taskqueue.MaxRetryLimit)
	}
}

func TestConstants_BitwiseFlags(t *testing.T) {
	t.Parallel()

	// Test bitwise flag values
	if taskqueue.TaskFlagNone != 0 {
		t.Errorf("expected TaskFlagNone 0, got %d", taskqueue.TaskFlagNone)
	}

	if taskqueue.TaskFlagUrgent != 1 {
		t.Errorf("expected TaskFlagUrgent 1 (1<<0), got %d", taskqueue.TaskFlagUrgent)
	}

	if taskqueue.TaskFlagRetryable != 2 {
		t.Errorf("expected TaskFlagRetryable 2 (1<<1), got %d", taskqueue.TaskFlagRetryable)
	}

	if taskqueue.TaskFlagLogged != 4 {
		t.Errorf("expected TaskFlagLogged 4 (1<<2), got %d", taskqueue.TaskFlagLogged)
	}

	if taskqueue.TaskFlagMetrics != 8 {
		t.Errorf("expected TaskFlagMetrics 8 (1<<3), got %d", taskqueue.TaskFlagMetrics)
	}
}

func TestConstants_BitwiseFlagCombinations(t *testing.T) {
	t.Parallel()

	// Test default combination
	defaultFlags := taskqueue.TaskFlagDefault
	expectedDefault := taskqueue.TaskFlagRetryable | taskqueue.TaskFlagLogged

	if defaultFlags != expectedDefault {
		t.Errorf("expected TaskFlagDefault %d, got %d", expectedDefault, defaultFlags)
	}

	// Test all combination
	allFlags := taskqueue.TaskFlagAll
	expectedAll := taskqueue.TaskFlagUrgent | taskqueue.TaskFlagRetryable | taskqueue.TaskFlagLogged | taskqueue.TaskFlagMetrics

	if allFlags != expectedAll {
		t.Errorf("expected TaskFlagAll %d, got %d", expectedAll, allFlags)
	}
}

func TestConstants_BitwiseFlagOperations(t *testing.T) {
	t.Parallel()

	// Test that flags are distinct powers of 2
	flags := []uint8{
		taskqueue.TaskFlagUrgent,
		taskqueue.TaskFlagRetryable,
		taskqueue.TaskFlagLogged,
		taskqueue.TaskFlagMetrics,
	}

	for i, flag1 := range flags {
		for j, flag2 := range flags {
			if i != j {
				// Different flags should not overlap
				if flag1&flag2 != 0 {
					t.Errorf("flags %d and %d overlap: %d & %d = %d",
						flag1, flag2, flag1, flag2, flag1&flag2)
				}
			}
		}
	}
}

func TestConstants_BitwiseFlagPowersOfTwo(t *testing.T) {
	t.Parallel()

	// Each flag should be a power of 2
	powerOfTwo := func(n uint8) bool {
		return n != 0 && (n&(n-1)) == 0
	}

	flags := map[string]uint8{
		"TaskFlagUrgent":    taskqueue.TaskFlagUrgent,
		"TaskFlagRetryable": taskqueue.TaskFlagRetryable,
		"TaskFlagLogged":    taskqueue.TaskFlagLogged,
		"TaskFlagMetrics":   taskqueue.TaskFlagMetrics,
	}

	for name, flag := range flags {
		if !powerOfTwo(flag) {
			t.Errorf("%s (%d) is not a power of 2", name, flag)
		}
	}
}
