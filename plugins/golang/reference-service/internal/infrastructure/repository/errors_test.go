package repository_test

import (
	"errors"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/repository"
)

func TestErrorMessages(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name    string
		err     error
		wantMsg string
	}{
		{
			name:    "ErrNilConfig",
			err:     repository.ErrNilConfig,
			wantMsg: "repository config cannot be nil",
		},
		{
			name:    "ErrInvalidLimit",
			err:     repository.ErrInvalidLimit,
			wantMsg: "limit exceeds maximum allowed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.err.Error() != tt.wantMsg {
				t.Errorf("error message = %q, want %q", tt.err.Error(), tt.wantMsg)
			}
		})
	}
}

func TestErrorsAreDistinct(t *testing.T) {
	t.Parallel()

	allErrors := []error{
		repository.ErrNilConfig,
		repository.ErrInvalidLimit,
	}

	for i, err1 := range allErrors {
		for j, err2 := range allErrors {
			if i != j && errors.Is(err1, err2) {
				t.Errorf("errors at index %d and %d are not distinct", i, j)
			}
		}
	}
}

func TestErrorsAreNotNil(t *testing.T) {
	t.Parallel()

	if repository.ErrNilConfig == nil {
		t.Error("ErrNilConfig should not be nil")
	}

	if repository.ErrInvalidLimit == nil {
		t.Error("ErrInvalidLimit should not be nil")
	}
}
