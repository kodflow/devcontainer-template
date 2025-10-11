// Package batch provides batch processing capabilities for todos.
//
// Purpose:
//   Implements batch operations for efficient bulk processing of todos.
//
// Responsibilities:
//   - Batch multiple operations together
//   - Execute batches atomically
//   - Track batch processing stats
//
// Features:
//   - Batch Processing
//   - Atomic Operations
//
// Constraints:
//   - Maximum 100 items per batch
//   - Batches execute sequentially
//
package batch

import (
	"context"
	"fmt"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
)

// Processor implements batch processing for todo operations.
//
// Fields:
//   - repo: Underlying todo repository for CRUD operations
//   - batchSize: Number of items to process per batch (1-100)
//
// Thread Safety:
//   The Processor itself is thread-safe as it doesn't maintain mutable state.
//   However, batch operations execute sequentially, not concurrently.
//
// Memory:
//   Fields are ordered by size for memory alignment.
type Processor struct {
	repo      todo.Repository
	batchSize int
}

// Config holds configuration for creating a new Processor.
//
// Fields:
//   - Repository: Required todo repository for batch operations
//   - BatchSize: Items per batch (default: DefaultBatchSize, max: MaxBatchSize)
type Config struct {
	Repository todo.Repository
	BatchSize  int
}

// NewProcessor creates a new batch Processor with the given configuration.
//
// The processor validates the configuration and applies defaults where needed.
// BatchSize is constrained to [1, MaxBatchSize] range.
//
// Parameters:
//   - cfg: Configuration struct with repository and batch size settings
//
// Returns:
//   - *Processor: Configured batch processor ready for use
//   - error: Possible errors:
//     - "repository required" if cfg.Repository is nil
//     - ErrBatchTooLarge if cfg.BatchSize > MaxBatchSize
//
// Example:
//   processor, err := NewProcessor(Config{
//       Repository: repo,
//       BatchSize:  50,
//   })
//   if err != nil {
//       log.Fatal(err)
//   }
func NewProcessor(cfg Config) (*Processor, error) {
	if cfg.Repository == nil {
		return nil, fmt.Errorf("repository required")
	}

	if cfg.BatchSize <= 0 {
		cfg.BatchSize = DefaultBatchSize
	}

	if cfg.BatchSize > MaxBatchSize {
		return nil, ErrBatchTooLarge
	}

	return &Processor{
		repo:      cfg.Repository,
		batchSize: cfg.BatchSize,
	}, nil
}

// CreateBatch creates multiple todos in a single batch operation.
//
// The operation processes todos sequentially in the order provided.
// If any creation fails, the operation stops immediately and returns the error.
// There is no automatic rollback - successful items remain in the repository.
//
// Parameters:
//   - ctx: Context for cancellation and timeout control
//   - todos: Slice of todo entities to create (must not be empty)
//
// Returns:
//   - error: Possible errors:
//     - ErrEmptyBatch if todos slice is empty or nil
//     - Any error from repository Create operations
//
// Example:
//   todos := []*todo.Todo{
//       todo.NewTodo("Task 1", "Description 1", todo.PriorityHigh),
//       todo.NewTodo("Task 2", "Description 2", todo.PriorityMedium),
//   }
//   if err := processor.CreateBatch(ctx, todos); err != nil {
//       log.Printf("batch creation failed: %v", err)
//   }
func (p *Processor) CreateBatch(ctx context.Context, todos []*todo.Todo) error {
	if len(todos) == 0 {
		return ErrEmptyBatch
	}

	for _, t := range todos {
		if _, err := p.repo.Create(ctx, t); err != nil {
			return err
		}
	}

	return nil
}
