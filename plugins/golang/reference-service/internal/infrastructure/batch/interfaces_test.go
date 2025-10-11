package batch_test

import (
	"context"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/batch"
)

// mockBatchProcessor implements batch.BatchProcessor for testing.
type mockBatchProcessor struct {
	createBatchFunc func(ctx context.Context, todos []*todo.Todo) error
}

func (m *mockBatchProcessor) CreateBatch(ctx context.Context, todos []*todo.Todo) error {
	if m.createBatchFunc != nil {
		return m.createBatchFunc(ctx, todos)
	}
	return nil
}

// Ensure Processor implements BatchProcessor interface.
var _ batch.BatchProcessor = (*batch.Processor)(nil)

// Ensure mockBatchProcessor implements BatchProcessor interface.
var _ batch.BatchProcessor = (*mockBatchProcessor)(nil)

func TestBatchProcessorInterface(t *testing.T) {
	t.Parallel()

	mock := &mockBatchProcessor{
		createBatchFunc: func(ctx context.Context, todos []*todo.Todo) error {
			return nil
		},
	}

	ctx := context.Background()
	todos := []*todo.Todo{}

	err := mock.CreateBatch(ctx, todos)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}
}

func TestProcessorImplementsInterface(t *testing.T) {
	t.Parallel()

	// This test verifies at compile time that Processor implements BatchProcessor.
	// The var _ assignment above ensures this.
	var processor batch.BatchProcessor
	if processor != nil {
		t.Error("processor should be nil initially")
	}
}
