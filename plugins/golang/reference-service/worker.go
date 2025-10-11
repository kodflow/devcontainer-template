// Package taskqueue worker implementation with concurrency
//
// Purpose:
//   Demonstrates concurrent task processing using goroutines, channels,
//   buffering, context cancellation, and proper resource management.
//
// Responsibilities:
//   - Concurrent task processing with worker pool
//   - Channel-based task distribution
//   - Graceful shutdown with context
//   - Error handling and retry logic
//
// Dependencies:
//   - TaskRepository for persistence
//   - TaskExecutor for task execution
//   - MessagePublisher for result publishing
//
// Features:
//   - Logging
//   - Database
//
// Constraints:
//   - Max concurrent workers configurable
//   - Graceful shutdown within timeout
//   - All goroutines must be cleaned up
//
package taskqueue

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sync"
	"time"
)

// WorkerConfig contains worker pool configuration
type WorkerConfig struct {
	Repository      TaskRepository
	Executor        TaskExecutor
	Publisher       MessagePublisher
	Logger          *slog.Logger
	Stats           *WorkerStats
	WorkerCount     int
	BufferSize      int
	ShutdownTimeout time.Duration
	ProcessTimeout  time.Duration
}

// Worker manages concurrent task processing
type Worker struct {
	repo            TaskRepository
	executor        TaskExecutor
	publisher       MessagePublisher
	logger          *slog.Logger
	stats           *WorkerStats
	workerCount     int
	taskChan        chan *Task
	resultChan      chan *TaskResult
	shutdownTimeout time.Duration
	processTimeout  time.Duration
	wg              sync.WaitGroup
	mu              sync.RWMutex
	running         bool
}

// NewWorker creates a new worker pool instance
func NewWorker(cfg WorkerConfig) (*Worker, error) {
	if err := validateWorkerConfig(&cfg); err != nil {
		return nil, err
	}
	applyWorkerDefaults(&cfg)

	return &Worker{
		repo:            cfg.Repository,
		executor:        cfg.Executor,
		publisher:       cfg.Publisher,
		logger:          cfg.Logger,
		stats:           cfg.Stats,
		workerCount:     cfg.WorkerCount,
		taskChan:        make(chan *Task, cfg.BufferSize),
		resultChan:      make(chan *TaskResult, cfg.BufferSize),
		shutdownTimeout: cfg.ShutdownTimeout,
		processTimeout:  cfg.ProcessTimeout,
		running:         false,
	}, nil
}

// validateWorkerConfig validates required configuration fields
func validateWorkerConfig(cfg *WorkerConfig) error {
	if cfg.Repository == nil {
		return errors.New("repository is required")
	}
	if cfg.Executor == nil {
		return errors.New("executor is required")
	}
	if cfg.Publisher == nil {
		return errors.New("publisher is required")
	}
	return nil
}

// applyWorkerDefaults applies default values to configuration
func applyWorkerDefaults(cfg *WorkerConfig) {
	if cfg.Logger == nil {
		cfg.Logger = slog.Default()
	}
	if cfg.Stats == nil {
		cfg.Stats = NewWorkerStats()
	}
	if cfg.WorkerCount <= 0 {
		cfg.WorkerCount = DefaultWorkerCount
	}
	if cfg.BufferSize <= 0 {
		cfg.BufferSize = DefaultBufferSize
	}
	if cfg.ShutdownTimeout == 0 {
		cfg.ShutdownTimeout = DefaultShutdownTimeout
	}
	if cfg.ProcessTimeout == 0 {
		cfg.ProcessTimeout = DefaultProcessTimeout
	}
}

// Start starts the worker pool
func (w *Worker) Start(ctx context.Context) error {
	w.mu.Lock()
	if w.running {
		w.mu.Unlock()
		return errors.New("worker already running")
	}
	w.running = true
	w.mu.Unlock()

	w.startWorkers(ctx)
	w.startResultProcessor(ctx)

	w.logger.Info("worker pool started",
		"workers", w.workerCount,
		"buffer", cap(w.taskChan))
	return nil
}

// startWorkers starts worker goroutines
func (w *Worker) startWorkers(ctx context.Context) {
	for i := 0; i < w.workerCount; i++ {
		w.wg.Add(1)
		go w.processTasksLoop(ctx, i)
	}
}

// startResultProcessor starts result processing
func (w *Worker) startResultProcessor(ctx context.Context) {
	w.wg.Add(1)
	go w.processResultsLoop(ctx)
}

// processTasksLoop processes tasks from channel
func (w *Worker) processTasksLoop(ctx context.Context, workerID int) {
	defer w.wg.Done()

	w.logger.Info("worker started", "worker_id", workerID)

	for {
		select {
		case <-ctx.Done():
			w.logger.Info("worker stopping",
				"worker_id", workerID,
				"reason", ctx.Err())
			return

		case task, ok := <-w.taskChan:
			if !ok {
				w.logger.Info("task channel closed",
					"worker_id", workerID)
				return
			}
			w.processTask(ctx, task, workerID)
		}
	}
}

// processTask processes a single task
func (w *Worker) processTask(ctx context.Context, task *Task, workerID int) {
	start := time.Now()
	w.stats.IncrementActive()
	defer w.stats.DecrementActive()

	processCtx, cancel := context.WithTimeout(ctx, w.processTimeout)
	defer cancel()

	w.logger.Info("processing task",
		"worker_id", workerID,
		"task_id", task.ID,
		"task_type", task.Type)

	result, err := w.executeTask(processCtx, task)
	if err != nil {
		w.handleTaskError(ctx, task, err)
		return
	}

	duration := time.Since(start)
	result.Duration = duration
	w.stats.RecordProcessed(duration)
	w.sendResult(ctx, result)
}

// executeTask executes task with status updates
func (w *Worker) executeTask(ctx context.Context, task *Task) (*TaskResult, error) {
	if err := w.updateTaskStatus(ctx, task.ID, TaskStatusProcessing); err != nil {
		return nil, fmt.Errorf("update status: %w", err)
	}

	result, err := w.executor.Execute(ctx, task)
	if err != nil {
		if updateErr := w.updateTaskStatus(ctx, task.ID, TaskStatusFailed); updateErr != nil {
			w.logger.Error("failed to update task status", "error", updateErr)
		}
		return nil, fmt.Errorf("execute task: %w", err)
	}

	if err := w.updateTaskStatus(ctx, task.ID, TaskStatusCompleted); err != nil {
		return nil, fmt.Errorf("update completed status: %w", err)
	}

	return result, nil
}

// handleTaskError handles task execution error
func (w *Worker) handleTaskError(ctx context.Context, task *Task, err error) {
	w.stats.RecordFailed()

	w.logger.Error("task execution failed",
		"task_id", task.ID,
		"error", err,
		"retries", task.Retries)

	if task.Retries > 0 {
		w.stats.RecordRetry()
	}

	result := &TaskResult{
		TaskID:    task.ID,
		Success:   false,
		Error:     err.Error(),
		Timestamp: time.Now(),
	}

	w.sendResult(ctx, result)
}

// updateTaskStatus updates task status
func (w *Worker) updateTaskStatus(ctx context.Context, taskID string, status TaskStatus) error {
	if err := w.repo.UpdateStatus(ctx, taskID, status); err != nil {
		return fmt.Errorf("update status: %w", err)
	}
	return nil
}

// sendResult sends result to result channel
func (w *Worker) sendResult(ctx context.Context, result *TaskResult) {
	select {
	case <-ctx.Done():
		w.logger.Warn("context cancelled, dropping result",
			"task_id", result.TaskID)
	case w.resultChan <- result:
		// Result sent successfully
	default:
		w.logger.Error("result channel full, dropping result",
			"task_id", result.TaskID)
	}
}

// processResultsLoop processes results from channel
func (w *Worker) processResultsLoop(ctx context.Context) {
	defer w.wg.Done()

	for {
		select {
		case <-ctx.Done():
			w.logger.Info("result processor stopping")
			return

		case result, ok := <-w.resultChan:
			if !ok {
				w.logger.Info("result channel closed")
				return
			}
			w.publishResult(ctx, result)
		}
	}
}

// publishResult publishes task result
func (w *Worker) publishResult(ctx context.Context, result *TaskResult) {
	topic := "task.results"
	message := formatResultMessage(result)

	if err := w.publisher.Publish(ctx, topic, message); err != nil {
		w.logger.Error("failed to publish result",
			"task_id", result.TaskID,
			"error", err)
		return
	}

	w.logger.Info("result published",
		"task_id", result.TaskID,
		"success", result.Success)
}

// SubmitTask submits a task for processing
func (w *Worker) SubmitTask(ctx context.Context, task *Task) error {
	w.mu.RLock()
	running := w.running
	w.mu.RUnlock()

	if !running {
		return errors.New("worker not running")
	}

	w.stats.RecordSubmission()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case w.taskChan <- task:
		return nil
	default:
		return errors.New("task queue full")
	}
}

// Shutdown gracefully shuts down worker pool
func (w *Worker) Shutdown(ctx context.Context) error {
	w.mu.Lock()
	if !w.running {
		w.mu.Unlock()
		return errors.New("worker not running")
	}
	w.running = false
	w.mu.Unlock()

	w.logger.Info("shutting down worker pool")

	close(w.taskChan)

	shutdownCtx, cancel := context.WithTimeout(ctx, w.shutdownTimeout)
	defer cancel()

	done := make(chan struct{})
	go func() {
		w.wg.Wait()
		close(w.resultChan)
		close(done)
	}()

	select {
	case <-done:
		w.stats.Stop()
		w.logger.Info("worker pool shutdown complete",
			"total_submitted", w.stats.GetSubmitted(),
			"total_processed", w.stats.GetProcessed(),
			"total_failed", w.stats.GetFailed())
		return nil
	case <-shutdownCtx.Done():
		return fmt.Errorf("shutdown timeout: %w", shutdownCtx.Err())
	}
}

// IsRunning returns whether worker is running
func (w *Worker) IsRunning() bool {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return w.running
}

// GetStats returns current worker statistics
func (w *Worker) GetStats() StatsSnapshot {
	return w.stats.GetSnapshot()
}

// formatResultMessage formats result as message
func formatResultMessage(result *TaskResult) []byte {
	return []byte(fmt.Sprintf(`{"task_id":"%s","success":%t}`,
		result.TaskID, result.Success))
}
