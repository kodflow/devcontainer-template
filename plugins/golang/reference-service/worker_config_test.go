package taskqueue_test

import (
	"log/slog"
	"testing"
	"time"

	"taskqueue"
)

func TestWorkerConfig_AllFields(t *testing.T) {
	t.Parallel()

	mockRepo := &MockTaskRepository{}
	mockExec := &MockTaskExecutor{}
	mockPub := &MockMessagePublisher{}
	logger := slog.Default()

	cfg := taskqueue.WorkerConfig{
		Repository:      mockRepo,
		Executor:        mockExec,
		Publisher:       mockPub,
		Logger:          logger,
		ShutdownTimeout: 30 * time.Second,
		ProcessTimeout:  60 * time.Second,
		WorkerCount:     5,
		BufferSize:      100,
	}

	if cfg.Repository == nil {
		t.Error("expected repository to be set")
	}

	if cfg.Executor == nil {
		t.Error("expected executor to be set")
	}

	if cfg.Publisher == nil {
		t.Error("expected publisher to be set")
	}

	if cfg.Logger == nil {
		t.Error("expected logger to be set")
	}

	if cfg.ShutdownTimeout != 30*time.Second {
		t.Errorf("expected shutdown timeout 30s, got %v", cfg.ShutdownTimeout)
	}

	if cfg.ProcessTimeout != 60*time.Second {
		t.Errorf("expected process timeout 60s, got %v", cfg.ProcessTimeout)
	}

	if cfg.WorkerCount != 5 {
		t.Errorf("expected worker count 5, got %d", cfg.WorkerCount)
	}

	if cfg.BufferSize != 100 {
		t.Errorf("expected buffer size 100, got %d", cfg.BufferSize)
	}
}

func TestWorkerConfig_ZeroValue(t *testing.T) {
	t.Parallel()

	var cfg taskqueue.WorkerConfig

	if cfg.Repository != nil {
		t.Error("expected nil repository")
	}

	if cfg.Executor != nil {
		t.Error("expected nil executor")
	}

	if cfg.Publisher != nil {
		t.Error("expected nil publisher")
	}

	if cfg.Logger != nil {
		t.Error("expected nil logger")
	}

	if cfg.ShutdownTimeout != 0 {
		t.Errorf("expected zero shutdown timeout, got %v", cfg.ShutdownTimeout)
	}

	if cfg.ProcessTimeout != 0 {
		t.Errorf("expected zero process timeout, got %v", cfg.ProcessTimeout)
	}

	if cfg.WorkerCount != 0 {
		t.Errorf("expected zero worker count, got %d", cfg.WorkerCount)
	}

	if cfg.BufferSize != 0 {
		t.Errorf("expected zero buffer size, got %d", cfg.BufferSize)
	}
}

func TestWorkerConfig_PartialConfiguration(t *testing.T) {
	t.Parallel()

	mockRepo := &MockTaskRepository{}

	cfg := taskqueue.WorkerConfig{
		Repository:  mockRepo,
		WorkerCount: 3,
	}

	if cfg.Repository == nil {
		t.Error("expected repository to be set")
	}

	if cfg.WorkerCount != 3 {
		t.Errorf("expected worker count 3, got %d", cfg.WorkerCount)
	}

	// Other fields should be zero values
	if cfg.Executor != nil {
		t.Error("expected nil executor")
	}

	if cfg.BufferSize != 0 {
		t.Errorf("expected zero buffer size, got %d", cfg.BufferSize)
	}
}
