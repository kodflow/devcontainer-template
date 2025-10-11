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

import "fmt"

// Batch operation errors.
var (
	// ErrBatchTooLarge is returned when a batch exceeds MaxBatchSize.
	//
	// Returned by:
	//   - NewProcessor when cfg.BatchSize > MaxBatchSize
	//
	// Resolution:
	//   Reduce batch size to MaxBatchSize (100) or less.
	ErrBatchTooLarge = fmt.Errorf("batch size exceeds maximum of %d", MaxBatchSize)

	// ErrEmptyBatch is returned when attempting to process an empty batch.
	//
	// Returned by:
	//   - Processor.CreateBatch when len(todos) == 0
	//
	// Resolution:
	//   Ensure the batch contains at least one todo before processing.
	ErrEmptyBatch = fmt.Errorf("batch cannot be empty")
)
