// Package taskqueue worker configuration
//
// Purpose:
//   Defines configuration structure for worker pool.
//
// Responsibilities:
//   - Worker configuration struct
//   - Configuration validation
//   - Default values application
//
// Features:
//   - None
//
// Constraints:
//   - Fields ordered by size for memory alignment
//
package taskqueue

import (
	"log/slog"
	"time"
)

// WorkerConfig contains worker pool configuration
// Fields ordered by size for optimal memory alignment
type WorkerConfig struct {
	// 8-byte aligned (interfaces/pointers)
	Repository TaskRepository   // 8 bytes (pointer)
	Executor   TaskExecutor     // 8 bytes (pointer)
	Publisher  MessagePublisher // 8 bytes (pointer)
	Logger     *slog.Logger     // 8 bytes (pointer)

	// 8-byte time.Duration
	ShutdownTimeout time.Duration // 8 bytes
	ProcessTimeout  time.Duration // 8 bytes

	// 4-byte int
	WorkerCount int // 8 bytes on 64-bit
	BufferSize  int // 8 bytes on 64-bit
}
