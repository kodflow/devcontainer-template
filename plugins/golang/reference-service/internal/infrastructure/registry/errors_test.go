package registry_test

import (
	"errors"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/registry"
)

func TestErrors(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		err  error
	}{
		{
			name: "ErrServiceNotFound exists",
			err:  registry.ErrServiceNotFound,
		},
		{
			name: "ErrServiceAlreadyExists exists",
			err:  registry.ErrServiceAlreadyExists,
		},
		{
			name: "ErrRegistryFull exists",
			err:  registry.ErrRegistryFull,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			if tt.err == nil {
				t.Fatal("error must not be nil")
			}

			errMsg := tt.err.Error()
			if errMsg == "" {
				t.Error("error message must not be empty")
			}

			t.Logf("Error message: %s", errMsg)
		})
	}
}

func TestErrorsAreDistinct(t *testing.T) {
	t.Parallel()

	allErrors := []error{
		registry.ErrServiceNotFound,
		registry.ErrServiceAlreadyExists,
		registry.ErrRegistryFull,
	}

	// Check that all errors are distinct
	for i := 0; i < len(allErrors); i++ {
		for j := i + 1; j < len(allErrors); j++ {
			if errors.Is(allErrors[i], allErrors[j]) {
				t.Errorf("errors at index %d and %d must be distinct", i, j)
			}
			if allErrors[i] == allErrors[j] {
				t.Errorf("errors at index %d and %d must have different instances", i, j)
			}
		}
	}
}
