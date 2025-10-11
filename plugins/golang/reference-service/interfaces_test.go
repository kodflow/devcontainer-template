package taskqueue_test

import (
	"context"
	"sync"
	"testing"
	"time"

	"taskqueue"
)

// MockTaskRepository is a thread-safe mock implementation
type MockTaskRepository struct {
	mu sync.RWMutex

	SaveFunc         func(ctx context.Context, task *taskqueue.Task) error
	GetByIDFunc      func(ctx context.Context, id string) (*taskqueue.Task, error)
	UpdateStatusFunc func(ctx context.Context, id string, status taskqueue.TaskStatus) error
	ListPendingFunc  func(ctx context.Context, limit int) ([]*taskqueue.Task, error)

	savedTasks   []*taskqueue.Task
	statusUpdates map[string]taskqueue.TaskStatus
}

// NewMockTaskRepository creates a new mock repository
func NewMockTaskRepository() *MockTaskRepository {
	return &MockTaskRepository{
		savedTasks:    make([]*taskqueue.Task, 0),
		statusUpdates: make(map[string]taskqueue.TaskStatus),
	}
}

// Save implements TaskRepository.Save
func (m *MockTaskRepository) Save(ctx context.Context, task *taskqueue.Task) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.SaveFunc != nil {
		return m.SaveFunc(ctx, task)
	}

	m.savedTasks = append(m.savedTasks, task)
	return nil
}

// GetByID implements TaskRepository.GetByID
func (m *MockTaskRepository) GetByID(ctx context.Context, id string) (*taskqueue.Task, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.GetByIDFunc != nil {
		return m.GetByIDFunc(ctx, id)
	}

	for _, task := range m.savedTasks {
		if task.ID == id {
			return task, nil
		}
	}

	return nil, taskqueue.ErrTaskNotFound
}

// UpdateStatus implements TaskRepository.UpdateStatus
func (m *MockTaskRepository) UpdateStatus(ctx context.Context, id string, status taskqueue.TaskStatus) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.UpdateStatusFunc != nil {
		return m.UpdateStatusFunc(ctx, id, status)
	}

	m.statusUpdates[id] = status
	return nil
}

// ListPending implements TaskRepository.ListPending
func (m *MockTaskRepository) ListPending(ctx context.Context, limit int) ([]*taskqueue.Task, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if m.ListPendingFunc != nil {
		return m.ListPendingFunc(ctx, limit)
	}

	return m.savedTasks, nil
}

// GetStatusUpdates returns recorded status updates
func (m *MockTaskRepository) GetStatusUpdates() map[string]taskqueue.TaskStatus {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make(map[string]taskqueue.TaskStatus)
	for k, v := range m.statusUpdates {
		result[k] = v
	}
	return result
}

// MockTaskExecutor is a mock task executor
type MockTaskExecutor struct {
	mu sync.RWMutex

	ExecuteFunc func(ctx context.Context, task *taskqueue.Task) (*taskqueue.TaskResult, error)

	executedTasks []*taskqueue.Task
}

// NewMockTaskExecutor creates a new mock executor
func NewMockTaskExecutor() *MockTaskExecutor {
	return &MockTaskExecutor{
		executedTasks: make([]*taskqueue.Task, 0),
	}
}

// Execute implements TaskExecutor.Execute
func (m *MockTaskExecutor) Execute(ctx context.Context, task *taskqueue.Task) (*taskqueue.TaskResult, error) {
	m.mu.Lock()
	m.executedTasks = append(m.executedTasks, task)
	m.mu.Unlock()

	if m.ExecuteFunc != nil {
		return m.ExecuteFunc(ctx, task)
	}

	return &taskqueue.TaskResult{
		TaskID:    task.ID,
		Success:   true,
		Output:    map[string]interface{}{"result": "success"},
		Timestamp: time.Now(),
	}, nil
}

// GetExecutedTasks returns executed tasks
func (m *MockTaskExecutor) GetExecutedTasks() []*taskqueue.Task {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make([]*taskqueue.Task, len(m.executedTasks))
	copy(result, m.executedTasks)
	return result
}

// MockMessagePublisher is a mock message publisher
type MockMessagePublisher struct {
	mu sync.RWMutex

	PublishFunc func(ctx context.Context, topic string, message []byte) error

	publishedMessages []PublishedMessage
}

// PublishedMessage represents a published message
type PublishedMessage struct {
	Topic   string
	Message []byte
	Time    time.Time
}

// NewMockMessagePublisher creates a new mock publisher
func NewMockMessagePublisher() *MockMessagePublisher {
	return &MockMessagePublisher{
		publishedMessages: make([]PublishedMessage, 0),
	}
}

// Publish implements MessagePublisher.Publish
func (m *MockMessagePublisher) Publish(ctx context.Context, topic string, message []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.PublishFunc != nil {
		return m.PublishFunc(ctx, topic, message)
	}

	m.publishedMessages = append(m.publishedMessages, PublishedMessage{
		Topic:   topic,
		Message: message,
		Time:    time.Now(),
	})

	return nil
}

// GetPublishedMessages returns published messages
func (m *MockMessagePublisher) GetPublishedMessages() []PublishedMessage {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make([]PublishedMessage, len(m.publishedMessages))
	copy(result, m.publishedMessages)
	return result
}

// MockMetricsCollector is a mock metrics collector
type MockMetricsCollector struct {
	mu sync.RWMutex

	IncrementCounterFunc func(ctx context.Context, name string, value int64)
	RecordDurationFunc   func(ctx context.Context, name string, duration time.Duration)

	counters  map[string]int64
	durations map[string][]time.Duration
}

// NewMockMetricsCollector creates a new mock metrics collector
func NewMockMetricsCollector() *MockMetricsCollector {
	return &MockMetricsCollector{
		counters:  make(map[string]int64),
		durations: make(map[string][]time.Duration),
	}
}

// IncrementCounter implements MetricsCollector.IncrementCounter
func (m *MockMetricsCollector) IncrementCounter(ctx context.Context, name string, value int64) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.IncrementCounterFunc != nil {
		m.IncrementCounterFunc(ctx, name, value)
		return
	}

	m.counters[name] += value
}

// RecordDuration implements MetricsCollector.RecordDuration
func (m *MockMetricsCollector) RecordDuration(ctx context.Context, name string, duration time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.RecordDurationFunc != nil {
		m.RecordDurationFunc(ctx, name, duration)
		return
	}

	m.durations[name] = append(m.durations[name], duration)
}

// GetCounter returns counter value
func (m *MockMetricsCollector) GetCounter(name string) int64 {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.counters[name]
}

// GetDurations returns recorded durations
func (m *MockMetricsCollector) GetDurations(name string) []time.Duration {
	m.mu.RLock()
	defer m.mu.RUnlock()

	result := make([]time.Duration, len(m.durations[name]))
	copy(result, m.durations[name])
	return result
}

// BuildTestTask creates a test task with default values
func BuildTestTask(t *testing.T, opts ...func(*taskqueue.Task)) *taskqueue.Task {
	t.Helper()

	task := &taskqueue.Task{
		ID:         "test-task-123",
		Type:       "test",
		Data:       map[string]interface{}{"key": "value"},
		Status:     taskqueue.TaskStatusPending,
		Retries:    0,
		MaxRetries: 3,
		CreatedAt:  time.Now(),
		UpdatedAt:  time.Now(),
	}

	for _, opt := range opts {
		opt(task)
	}

	return task
}

// WithTaskID sets custom task ID
func WithTaskID(id string) func(*taskqueue.Task) {
	return func(t *taskqueue.Task) {
		t.ID = id
	}
}

// WithTaskType sets custom task type
func WithTaskType(taskType string) func(*taskqueue.Task) {
	return func(t *taskqueue.Task) {
		t.Type = taskType
	}
}

// WithTaskStatus sets custom task status
func WithTaskStatus(status taskqueue.TaskStatus) func(*taskqueue.Task) {
	return func(t *taskqueue.Task) {
		t.Status = status
	}
}

// WithTaskData sets custom task data
func WithTaskData(data map[string]interface{}) func(*taskqueue.Task) {
	return func(t *taskqueue.Task) {
		t.Data = data
	}
}

// BuildTestCreateRequest creates a test create request
func BuildTestCreateRequest(t *testing.T, opts ...func(*taskqueue.CreateTaskRequest)) taskqueue.CreateTaskRequest {
	t.Helper()

	req := taskqueue.CreateTaskRequest{
		Type:       "test",
		Data:       map[string]interface{}{"test": "data"},
		MaxRetries: 3,
	}

	for _, opt := range opts {
		opt(&req)
	}

	return req
}

// WithRequestType sets custom request type
func WithRequestType(taskType string) func(*taskqueue.CreateTaskRequest) {
	return func(r *taskqueue.CreateTaskRequest) {
		r.Type = taskType
	}
}

// AssertTaskStatus asserts task status
func AssertTaskStatus(t *testing.T, task *taskqueue.Task, expected taskqueue.TaskStatus) {
	t.Helper()

	if task.Status != expected {
		t.Errorf("expected status %s, got %s", expected, task.Status)
	}
}

// AssertNoError asserts no error occurred
func AssertNoError(t *testing.T, err error) {
	t.Helper()

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

// AssertError asserts error occurred
func AssertError(t *testing.T, err error, expectedMsg string) {
	t.Helper()

	if err == nil {
		t.Fatal("expected error but got nil")
	}

	if err.Error() != expectedMsg {
		t.Errorf("expected error '%s', got '%s'", expectedMsg, err.Error())
	}
}
