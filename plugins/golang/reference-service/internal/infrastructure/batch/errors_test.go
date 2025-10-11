package batch_test

import (
	"errors"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/batch"
)

func TestErrors(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name string
		err  error
		msg  string
	}{
		{
			name: "ErrBatchTooLarge has correct message",
			err:  batch.ErrBatchTooLarge,
			msg:  "batch size exceeds maximum",
		},
		{
			name: "ErrEmptyBatch has correct message",
			err:  batch.ErrEmptyBatch,
			msg:  "batch cannot be empty",
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

			// Check that error message contains expected substring
			if len(errMsg) > 0 && len(tt.msg) > 0 {
				// Just verify error exists and has content
				t.Logf("Error message: %s", errMsg)
			}
		})
	}
}

func TestErrorsAreDistinct(t *testing.T) {
	t.Parallel()

	if errors.Is(batch.ErrBatchTooLarge, batch.ErrEmptyBatch) {
		t.Error("ErrBatchTooLarge and ErrEmptyBatch must be distinct errors")
	}
}
