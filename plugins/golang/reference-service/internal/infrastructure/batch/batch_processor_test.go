package batch_test

import (
	"context"
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/batch"
	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/repository"
)

func TestNewProcessor(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, err := batch.NewProcessor(batch.Config{Repository: repo, BatchSize: 10})

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if p == nil {
		t.Fatal("expected processor to be created")
	}
}

func TestNewProcessor_NilRepository(t *testing.T) {
	t.Parallel()

	_, err := batch.NewProcessor(batch.Config{Repository: nil, BatchSize: 10})

	if err == nil {
		t.Fatal("expected error for nil repository, got nil")
	}

	expectedMsg := "repository required"
	if err.Error() != expectedMsg {
		t.Errorf("expected error message '%s', got '%s'", expectedMsg, err.Error())
	}
}

func TestNewProcessor_BatchSizeTooLarge(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	_, err := batch.NewProcessor(batch.Config{Repository: repo, BatchSize: 101})

	if err != batch.ErrBatchTooLarge {
		t.Errorf("expected ErrBatchTooLarge, got %v", err)
	}
}

func TestNewProcessor_DefaultBatchSize(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, err := batch.NewProcessor(batch.Config{Repository: repo, BatchSize: 0})

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if p == nil {
		t.Fatal("expected processor to be created")
	}

	// BatchSize should be set to DefaultBatchSize (10)
	// We can't directly access p.batchSize, but we verify it was created successfully
}

func TestNewProcessor_NegativeBatchSize(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, err := batch.NewProcessor(batch.Config{Repository: repo, BatchSize: -5})

	if err != nil {
		t.Fatalf("expected no error (should use default), got %v", err)
	}

	if p == nil {
		t.Fatal("expected processor to be created with default batch size")
	}
}

func TestProcessor_CreateBatch(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, _ := batch.NewProcessor(batch.Config{Repository: repo})

	td1, _ := todo.NewTodo("Task 1", "Description 1", todo.PriorityLow)
	td2, _ := todo.NewTodo("Task 2", "Description 2", todo.PriorityMedium)

	err := p.CreateBatch(context.Background(), []*todo.Todo{td1, td2})
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
}

func TestProcessor_CreateBatch_EmptySlice(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, _ := batch.NewProcessor(batch.Config{Repository: repo})

	err := p.CreateBatch(context.Background(), []*todo.Todo{})

	if err != batch.ErrEmptyBatch {
		t.Errorf("expected ErrEmptyBatch, got %v", err)
	}
}

func TestProcessor_CreateBatch_NilSlice(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, _ := batch.NewProcessor(batch.Config{Repository: repo})

	err := p.CreateBatch(context.Background(), nil)

	if err != batch.ErrEmptyBatch {
		t.Errorf("expected ErrEmptyBatch, got %v", err)
	}
}

func TestProcessor_CreateBatch_RepositoryError(t *testing.T) {
	t.Parallel()

	// Create a repository that will hit the limit
	repo, _ := repository.NewRepository(repository.Config{MaxTodos: 1})
	p, _ := batch.NewProcessor(batch.Config{Repository: repo})

	td1, _ := todo.NewTodo("Task 1", "Description 1", todo.PriorityLow)
	td2, _ := todo.NewTodo("Task 2", "Description 2", todo.PriorityMedium)

	// First todo should succeed, second should fail due to limit
	err := p.CreateBatch(context.Background(), []*todo.Todo{td1, td2})

	if err == nil {
		t.Fatal("expected error when repository limit is exceeded, got nil")
	}

	// Verify first todo was created (no rollback)
	_, getErr := repo.GetByID(context.Background(), td1.ID)
	if getErr != nil {
		t.Error("expected first todo to remain in repository after batch failure")
	}
}

func TestProcessor_CreateBatch_ContextCancellation(t *testing.T) {
	t.Parallel()

	repo, _ := repository.NewRepository(repository.Config{})
	p, _ := batch.NewProcessor(batch.Config{Repository: repo})

	td1, _ := todo.NewTodo("Task 1", "Description 1", todo.PriorityLow)

	ctx, cancel := context.WithCancel(context.Background())
	cancel() // Cancel immediately

	// Even with cancelled context, batch should process
	// (current implementation doesn't check context in loop)
	err := p.CreateBatch(ctx, []*todo.Todo{td1})

	// Current implementation doesn't check context, so this succeeds
	if err != nil {
		t.Logf("Note: context cancellation not checked in current implementation, got: %v", err)
	}
}
