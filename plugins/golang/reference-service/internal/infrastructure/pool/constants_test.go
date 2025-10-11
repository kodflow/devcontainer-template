package pool_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/pool"
)

func TestConstants(t *testing.T) {
	t.Parallel()

	if pool.DefaultWorkerCount != 10 {
		t.Errorf("DefaultWorkerCount = %d, want 10", pool.DefaultWorkerCount)
	}

	if pool.MaxWorkerCount != 1000 {
		t.Errorf("MaxWorkerCount = %d, want 1000", pool.MaxWorkerCount)
	}

	if pool.DefaultQueueSize != 100 {
		t.Errorf("DefaultQueueSize = %d, want 100", pool.DefaultQueueSize)
	}
}
