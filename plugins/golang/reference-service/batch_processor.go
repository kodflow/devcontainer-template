// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Batch processing with pooled buffers.
//
// Responsibilities:
//   - Process multiple tasks efficiently
//   - Reuse encoding buffers
//
// Features:
//   - None
//
// Constraints:
//   - Must reuse buffers across batch
//
package taskqueue

// BatchProcessor processes tasks in batches using pooled buffers.
// Demonstrates high-throughput processing with minimal allocations.
type BatchProcessor struct {
	encoder *TaskEncoder
}

// NewBatchProcessor creates a batch processor.
func NewBatchProcessor() *BatchProcessor {
	return &BatchProcessor{
		encoder: NewTaskEncoder(),
	}
}

// ProcessBatch encodes multiple tasks efficiently.
// Reuses same buffer for all tasks in batch.
func (b *BatchProcessor) ProcessBatch(tasks []*Task) ([][]byte, error) {
	results := make([][]byte, 0, len(tasks))

	for _, task := range tasks {
		encoded, err := b.encoder.Encode(task)
		if err != nil {
			return nil, err
		}
		results = append(results, encoded)
	}

	return results, nil
}
