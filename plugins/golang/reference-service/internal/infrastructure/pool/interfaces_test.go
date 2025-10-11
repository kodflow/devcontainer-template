package pool_test

import "context"

// mockPool is a mock implementation of Pool for testing.
type mockPool struct {
	submitFunc          func(ctx context.Context, task func(context.Context) error) error
	shutdownFunc        func(ctx context.Context) error
	activeWorkersFunc   func() int
	completedTasksFunc  func() int64
}

func (m *mockPool) Submit(ctx context.Context, task func(context.Context) error) error {
	if m.submitFunc != nil {
		return m.submitFunc(ctx, task)
	}
	return nil
}

func (m *mockPool) Shutdown(ctx context.Context) error {
	if m.shutdownFunc != nil {
		return m.shutdownFunc(ctx)
	}
	return nil
}

func (m *mockPool) ActiveWorkers() int {
	if m.activeWorkersFunc != nil {
		return m.activeWorkersFunc()
	}
	return 0
}

func (m *mockPool) CompletedTasks() int64 {
	if m.completedTasksFunc != nil {
		return m.completedTasksFunc()
	}
	return 0
}
