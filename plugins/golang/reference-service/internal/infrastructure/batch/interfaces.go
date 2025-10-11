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

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
)

// BatchProcessor defines the interface for batch todo operations.
//
// Implementations must be thread-safe and handle batches atomically.
// If any item in the batch fails, the entire batch should fail.
type BatchProcessor interface {
	// CreateBatch creates multiple todos in a single batch operation.
	//
	// The operation processes todos sequentially. If any creation fails,
	// the operation stops immediately and returns the error.
	//
	// Parameters:
	//   - ctx: Context for cancellation and timeout control
	//   - todos: Slice of todo entities to create (must not be empty)
	//
	// Returns:
	//   - error: Possible errors:
	//     - ErrEmptyBatch if todos slice is empty
	//     - Any error from underlying repository operations
	//
	// Example:
	//   todos := []*todo.Todo{todo1, todo2, todo3}
	//   err := processor.CreateBatch(ctx, todos)
	//   if err != nil {
	//       log.Printf("batch failed: %v", err)
	//   }
	CreateBatch(ctx context.Context, todos []*todo.Todo) error
}
