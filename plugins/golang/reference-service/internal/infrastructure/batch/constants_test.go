package batch_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/batch"
)

func TestConstants(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name     string
		constant int
		want     int
	}{
		{
			name:     "DefaultBatchSize has expected value",
			constant: batch.DefaultBatchSize,
			want:     10,
		},
		{
			name:     "MaxBatchSize has expected value",
			constant: batch.MaxBatchSize,
			want:     100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			if tt.constant != tt.want {
				t.Errorf("constant value = %d, want %d", tt.constant, tt.want)
			}
		})
	}
}

func TestBatchSizeRelationship(t *testing.T) {
	t.Parallel()

	if batch.DefaultBatchSize > batch.MaxBatchSize {
		t.Error("DefaultBatchSize must be <= MaxBatchSize")
	}

	if batch.DefaultBatchSize <= 0 {
		t.Error("DefaultBatchSize must be positive")
	}

	if batch.MaxBatchSize <= 0 {
		t.Error("MaxBatchSize must be positive")
	}
}
