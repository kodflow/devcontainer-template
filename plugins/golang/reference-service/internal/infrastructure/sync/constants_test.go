package sync_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/sync"
)

func TestStateConstants(t *testing.T) {
	t.Parallel()

	if sync.StateUninitialized != 0 {
		t.Errorf("StateUninitialized = %d, want 0", sync.StateUninitialized)
	}

	if sync.StateInitialized != 1 {
		t.Errorf("StateInitialized = %d, want 1", sync.StateInitialized)
	}
}
