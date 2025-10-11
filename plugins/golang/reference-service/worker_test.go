package taskqueue_test

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"taskqueue"
)

func TestNewWorker_Success(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	cfg := taskqueue.WorkerConfig{
		Repository: repo,
		Executor:   executor,
		Publisher:  publisher,
	}

	worker, err := taskqueue.NewWorker(cfg)

	AssertNoError(t, err)

	if worker == nil {
		t.Fatal("expected non-nil worker")
	}
}

func TestNewWorker_MissingRepository(t *testing.T) {
	t.Parallel()

	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	cfg := taskqueue.WorkerConfig{
		Repository: nil,
		Executor:   executor,
		Publisher:  publisher,
	}

	worker, err := taskqueue.NewWorker(cfg)

	AssertError(t, err, "repository is required")

	if worker != nil {
		t.Error("expected nil worker")
	}
}

func TestNewWorker_MissingExecutor(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	publisher := NewMockMessagePublisher()

	cfg := taskqueue.WorkerConfig{
		Repository: repo,
		Executor:   nil,
		Publisher:  publisher,
	}

	worker, err := taskqueue.NewWorker(cfg)

	AssertError(t, err, "executor is required")

	if worker != nil {
		t.Error("expected nil worker")
	}
}

func TestNewWorker_MissingPublisher(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()

	cfg := taskqueue.WorkerConfig{
		Repository: repo,
		Executor:   executor,
		Publisher:  nil,
	}

	worker, err := taskqueue.NewWorker(cfg)

	AssertError(t, err, "publisher is required")

	if worker != nil {
		t.Error("expected nil worker")
	}
}

func TestNewWorker_DefaultValues(t *testing.T) {
	t.Parallel()

	cfg := taskqueue.WorkerConfig{
		Repository: NewMockTaskRepository(),
		Executor:   NewMockTaskExecutor(),
		Publisher:  NewMockMessagePublisher(),
	}

	worker, err := taskqueue.NewWorker(cfg)

	AssertNoError(t, err)

	if worker == nil {
		t.Fatal("expected non-nil worker")
	}
}

func TestWorker_StartAndShutdown(t *testing.T) {
	t.Parallel()

	worker := createTestWorker(t)

	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)

	if !worker.IsRunning() {
		t.Error("expected worker to be running")
	}

	err = worker.Shutdown(ctx)
	AssertNoError(t, err)

	if worker.IsRunning() {
		t.Error("expected worker to be stopped")
	}
}

func TestWorker_StartTwice(t *testing.T) {
	t.Parallel()

	worker := createTestWorker(t)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)

	err = worker.Start(ctx)
	AssertError(t, err, "worker already running")

	_ = worker.Shutdown(ctx)
}

func TestWorker_ShutdownNotRunning(t *testing.T) {
	t.Parallel()

	worker := createTestWorker(t)
	ctx := context.Background()

	err := worker.Shutdown(ctx)
	AssertError(t, err, "worker not running")
}

func TestWorker_SubmitTask_Success(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	worker := createTestWorkerWithDeps(t, repo, executor, publisher)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)
	defer func() {
		_ = worker.Shutdown(ctx)
	}()

	task := BuildTestTask(t, WithTaskID("task-1"))

	err = worker.SubmitTask(ctx, task)
	AssertNoError(t, err)

	time.Sleep(100 * time.Millisecond)

	executedTasks := executor.GetExecutedTasks()
	if len(executedTasks) != 1 {
		t.Fatalf("expected 1 executed task, got %d", len(executedTasks))
	}

	if executedTasks[0].ID != "task-1" {
		t.Errorf("expected task-1, got %s", executedTasks[0].ID)
	}
}

func TestWorker_SubmitTask_NotRunning(t *testing.T) {
	t.Parallel()

	worker := createTestWorker(t)
	ctx := context.Background()

	task := BuildTestTask(t)

	err := worker.SubmitTask(ctx, task)
	AssertError(t, err, "worker not running")
}

func TestWorker_SubmitTask_ContextCancelled(t *testing.T) {
	t.Parallel()

	worker := createTestWorker(t)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)
	defer func() {
		_ = worker.Shutdown(ctx)
	}()

	cancelledCtx, cancel := context.WithCancel(ctx)
	cancel()

	task := BuildTestTask(t)

	err = worker.SubmitTask(cancelledCtx, task)

	if !errors.Is(err, context.Canceled) {
		t.Errorf("expected context.Canceled, got %v", err)
	}
}

func TestWorker_ConcurrentTaskSubmission(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	worker := createTestWorkerWithDeps(t, repo, executor, publisher)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)
	defer func() {
		_ = worker.Shutdown(ctx)
	}()

	const numTasks = 50
	var wg sync.WaitGroup

	for i := 0; i < numTasks; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()

			task := BuildTestTask(t, WithTaskID(string(rune(id))))
			err := worker.SubmitTask(ctx, task)

			if err != nil && err.Error() != "task queue full" {
				t.Errorf("unexpected error: %v", err)
			}
		}(i)
	}

	wg.Wait()

	time.Sleep(500 * time.Millisecond)

	executedTasks := executor.GetExecutedTasks()
	if len(executedTasks) == 0 {
		t.Error("expected some tasks to be executed")
	}
}

func TestWorker_TaskProcessing_Success(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	worker := createTestWorkerWithDeps(t, repo, executor, publisher)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)
	defer func() {
		_ = worker.Shutdown(ctx)
	}()

	task := BuildTestTask(t, WithTaskID("task-success"))

	err = worker.SubmitTask(ctx, task)
	AssertNoError(t, err)

	time.Sleep(200 * time.Millisecond)

	statusUpdates := repo.GetStatusUpdates()
	if statusUpdates["task-success"] != taskqueue.TaskStatusCompleted {
		t.Errorf("expected completed status, got %s",
			statusUpdates["task-success"])
	}

	messages := publisher.GetPublishedMessages()
	if len(messages) != 1 {
		t.Fatalf("expected 1 published message, got %d", len(messages))
	}
}

func TestWorker_TaskProcessing_Failure(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	executor.ExecuteFunc = func(ctx context.Context, task *taskqueue.Task) (*taskqueue.TaskResult, error) {
		return nil, errors.New("execution failed")
	}

	worker := createTestWorkerWithDeps(t, repo, executor, publisher)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)
	defer func() {
		_ = worker.Shutdown(ctx)
	}()

	task := BuildTestTask(t, WithTaskID("task-fail"))

	err = worker.SubmitTask(ctx, task)
	AssertNoError(t, err)

	time.Sleep(200 * time.Millisecond)

	statusUpdates := repo.GetStatusUpdates()
	if statusUpdates["task-fail"] != taskqueue.TaskStatusFailed {
		t.Errorf("expected failed status, got %s",
			statusUpdates["task-fail"])
	}
}

func TestWorker_GracefulShutdown(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	executor.ExecuteFunc = func(ctx context.Context, task *taskqueue.Task) (*taskqueue.TaskResult, error) {
		time.Sleep(50 * time.Millisecond)
		return &taskqueue.TaskResult{
			TaskID:  task.ID,
			Success: true,
		}, nil
	}

	worker := createTestWorkerWithDeps(t, repo, executor, publisher)
	ctx := context.Background()

	err := worker.Start(ctx)
	AssertNoError(t, err)

	for i := 0; i < 5; i++ {
		task := BuildTestTask(t)
		_ = worker.SubmitTask(ctx, task)
	}

	shutdownCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	err = worker.Shutdown(shutdownCtx)
	AssertNoError(t, err)
}

func TestWorker_ShutdownTimeout(t *testing.T) {
	t.Parallel()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	executor.ExecuteFunc = func(ctx context.Context, task *taskqueue.Task) (*taskqueue.TaskResult, error) {
		time.Sleep(10 * time.Second)
		return &taskqueue.TaskResult{TaskID: task.ID, Success: true}, nil
	}

	cfg := taskqueue.WorkerConfig{
		Repository:      repo,
		Executor:        executor,
		Publisher:       publisher,
		WorkerCount:     1,
		BufferSize:      1,
		ShutdownTimeout: 100 * time.Millisecond,
	}

	worker, err := taskqueue.NewWorker(cfg)
	AssertNoError(t, err)

	ctx := context.Background()

	err = worker.Start(ctx)
	AssertNoError(t, err)

	task := BuildTestTask(t)
	_ = worker.SubmitTask(ctx, task)

	time.Sleep(50 * time.Millisecond)

	err = worker.Shutdown(ctx)

	if err == nil {
		t.Error("expected shutdown timeout error")
	}
}

// Helper function to create test worker
func createTestWorker(t *testing.T) *taskqueue.Worker {
	t.Helper()

	repo := NewMockTaskRepository()
	executor := NewMockTaskExecutor()
	publisher := NewMockMessagePublisher()

	return createTestWorkerWithDeps(t, repo, executor, publisher)
}

// Helper function to create worker with specific dependencies
func createTestWorkerWithDeps(
	t *testing.T,
	repo taskqueue.TaskRepository,
	executor taskqueue.TaskExecutor,
	publisher taskqueue.MessagePublisher,
) *taskqueue.Worker {
	t.Helper()

	cfg := taskqueue.WorkerConfig{
		Repository:      repo,
		Executor:        executor,
		Publisher:       publisher,
		WorkerCount:     2,
		BufferSize:      10,
		ShutdownTimeout: 2 * time.Second,
		ProcessTimeout:  1 * time.Second,
	}

	worker, err := taskqueue.NewWorker(cfg)
	AssertNoError(t, err)

	return worker
}
