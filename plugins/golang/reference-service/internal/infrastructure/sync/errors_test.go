package sync_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/sync"
)

func TestErrors(t *testing.T) {
	t.Parallel()

	if sync.ErrAlreadyInitialized == nil {
		t.Error("ErrAlreadyInitialized should not be nil")
	}

	wantMsg := "already initialized"
	if sync.ErrAlreadyInitialized.Error() != wantMsg {
		t.Errorf("error message = %q, want %q", sync.ErrAlreadyInitialized.Error(), wantMsg)
	}
}
