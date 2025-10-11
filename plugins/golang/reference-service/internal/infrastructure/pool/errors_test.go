package pool_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/pool"
)

func TestErrors(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		err     error
		wantMsg string
	}{
		{"ErrPoolClosed", pool.ErrPoolClosed, "worker pool is closed"},
		{"ErrQueueFull", pool.ErrQueueFull, "task queue is full"},
		{"ErrInvalidWorkerCount", pool.ErrInvalidWorkerCount, "worker count must be between 1 and 1000"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.err.Error() != tt.wantMsg {
				t.Errorf("error message = %q, want %q", tt.err.Error(), tt.wantMsg)
			}
		})
	}
}
