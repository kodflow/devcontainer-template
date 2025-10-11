package index_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/index"
)

func TestMaxTodosPerStatus(t *testing.T) {
	t.Parallel()

	if index.MaxTodosPerStatus <= 0 {
		t.Error("MaxTodosPerStatus must be positive")
	}

	if index.MaxTodosPerStatus != 10000 {
		t.Errorf("MaxTodosPerStatus = %d, want 10000", index.MaxTodosPerStatus)
	}
}

func TestMaxTodosPerStatusIsReasonable(t *testing.T) {
	t.Parallel()

	// Verify the limit is within reasonable bounds
	if index.MaxTodosPerStatus < 100 {
		t.Error("MaxTodosPerStatus seems too low for practical use")
	}

	if index.MaxTodosPerStatus > 1000000 {
		t.Error("MaxTodosPerStatus seems unreasonably high")
	}
}
