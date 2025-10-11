package index_test

import (
	"errors"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/index"
)

func TestErrors(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		err  error
	}{
		{
			name: "ErrIndexFull exists",
			err:  index.ErrIndexFull,
		},
		{
			name: "ErrInvalidStatus exists",
			err:  index.ErrInvalidStatus,
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

	if errors.Is(index.ErrIndexFull, index.ErrInvalidStatus) {
		t.Error("ErrIndexFull and ErrInvalidStatus must be distinct errors")
	}

	if index.ErrIndexFull == index.ErrInvalidStatus {
		t.Error("errors must have different instances")
	}
}
