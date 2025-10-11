package repository_test

import (
	"testing"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/repository"
)

func TestDefaultConstants(t *testing.T) {
	t.Parallel()

	if repository.DefaultMaxTodos != 10000 {
		t.Errorf("DefaultMaxTodos = %d, want 10000", repository.DefaultMaxTodos)
	}

	if repository.DefaultTimeout != 5*time.Second {
		t.Errorf("DefaultTimeout = %v, want %v", repository.DefaultTimeout, 5*time.Second)
	}

	if repository.DefaultListLimit != 50 {
		t.Errorf("DefaultListLimit = %d, want 50", repository.DefaultListLimit)
	}

	if repository.MaxListLimit != 500 {
		t.Errorf("MaxListLimit = %d, want 500", repository.MaxListLimit)
	}
}

func TestConstantsArePositive(t *testing.T) {
	t.Parallel()

	if repository.DefaultMaxTodos <= 0 {
		t.Error("DefaultMaxTodos must be positive")
	}

	if repository.DefaultListLimit <= 0 {
		t.Error("DefaultListLimit must be positive")
	}

	if repository.MaxListLimit <= 0 {
		t.Error("MaxListLimit must be positive")
	}

	if repository.DefaultTimeout <= 0 {
		t.Error("DefaultTimeout must be positive")
	}
}

func TestLimitRelationship(t *testing.T) {
	t.Parallel()

	if repository.DefaultListLimit > repository.MaxListLimit {
		t.Errorf("DefaultListLimit (%d) should not exceed MaxListLimit (%d)",
			repository.DefaultListLimit, repository.MaxListLimit)
	}
}
