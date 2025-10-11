package cache_test

import (
	"testing"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/cache"
)

func TestConstants(t *testing.T) {
	t.Parallel()

	if cache.DefaultTTL != 5*time.Minute {
		t.Errorf("DefaultTTL = %v, want %v", cache.DefaultTTL, 5*time.Minute)
	}

	if cache.DefaultMaxEntries != 10000 {
		t.Errorf("DefaultMaxEntries = %d, want 10000", cache.DefaultMaxEntries)
	}

	if cache.DefaultCleanupInterval != 1*time.Minute {
		t.Errorf("DefaultCleanupInterval = %v, want %v", cache.DefaultCleanupInterval, 1*time.Minute)
	}
}
