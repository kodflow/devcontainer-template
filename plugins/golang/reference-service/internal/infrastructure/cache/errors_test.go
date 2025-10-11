package cache_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/cache"
)

func TestErrors(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		err     error
		wantMsg string
	}{
		{"ErrNotFound", cache.ErrNotFound, "key not found in cache"},
		{"ErrExpired", cache.ErrExpired, "cached entry has expired"},
		{"ErrCacheFull", cache.ErrCacheFull, "cache is full"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.err.Error() != tt.wantMsg {
				t.Errorf("error message = %q, want %q", tt.err.Error(), tt.wantMsg)
			}
		})
	}
}
