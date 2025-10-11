package registry_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/registry"
)

func TestMaxServices(t *testing.T) {
	t.Parallel()

	if registry.MaxServices <= 0 {
		t.Error("MaxServices must be positive")
	}

	if registry.MaxServices != 100 {
		t.Errorf("MaxServices = %d, want 100", registry.MaxServices)
	}
}

func TestMaxServicesIsReasonable(t *testing.T) {
	t.Parallel()

	// Verify the limit is within reasonable bounds
	if registry.MaxServices < 10 {
		t.Error("MaxServices seems too low for practical use")
	}

	if registry.MaxServices > 10000 {
		t.Error("MaxServices seems unreasonably high")
	}
}
