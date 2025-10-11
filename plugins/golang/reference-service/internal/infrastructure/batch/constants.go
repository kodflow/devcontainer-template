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

// Batch size constants control the number of items processed in a single batch.
// These limits prevent memory exhaustion and ensure reasonable processing times.
const (
	// DefaultBatchSize is the default number of items processed per batch.
	// This value provides a good balance between performance and memory usage.
	// Used when no explicit batch size is configured.
	DefaultBatchSize = 10

	// MaxBatchSize is the maximum allowed items in a single batch.
	// Exceeding this limit returns ErrBatchTooLarge.
	// This prevents excessive memory allocation and timeout issues.
	MaxBatchSize = 100
)
