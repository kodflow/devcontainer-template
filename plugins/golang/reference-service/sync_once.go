// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Once for thread-safe lazy initialization.
//
// Responsibilities:
//   - Singleton pattern implementation
//   - One-time initialization guarantee
//   - Thread-safe lazy loading
//
// Features:
//   - Logging
//
// Constraints:
//   - Once.Do calls function exactly once
//   - Blocks concurrent calls until completion
//   - Cannot be reset
//
package taskqueue

import (
	"context"
	"log/slog"
	"sync"
	"sync/atomic"
	"time"
)

// GlobalRegistry is a singleton task registry.
// Uses sync.Once to ensure single initialization.
type GlobalRegistry struct {
	tasks      map[string]*Task
	mu         sync.RWMutex
	logger     *slog.Logger
	initTime   time.Time
	initCalled atomic.Bool
}

var (
	registryInstance *GlobalRegistry
	registryOnce     sync.Once
)

// GetRegistry returns the singleton registry instance.
// Thread-safe: First call initializes, subsequent calls return same instance.
//
// sync.Once guarantees:
//   - Function called exactly once
//   - All goroutines wait for first call to complete
//   - Subsequent calls return immediately (no lock contention)
func GetRegistry() *GlobalRegistry {
	registryOnce.Do(func() {
		registryInstance = &GlobalRegistry{
			tasks:    make(map[string]*Task, 1000),
			logger:   slog.Default(),
			initTime: time.Now(),
		}
		registryInstance.initCalled.Store(true)
		registryInstance.logger.Info("registry initialized",
			"time", time.Now().Format(time.RFC3339))
	})
	return registryInstance
}

// Register adds task to global registry.
func (r *GlobalRegistry) Register(task *Task) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.tasks[task.ID] = task
}

// Get retrieves task from registry.
func (r *GlobalRegistry) Get(taskID string) (*Task, bool) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	task, exists := r.tasks[taskID]
	return task, exists
}

// ConnectionPool manages database connections with lazy initialization.
// Demonstrates sync.Once for expensive resource initialization.
type ConnectionPool struct {
	connections []*Connection
	initOnce    sync.Once
	initErr     error
	maxConns    int
	logger      *slog.Logger
}

// Connection represents a database connection (mock).
type Connection struct {
	ID     string
	Active bool
}

// NewConnectionPool creates a pool (initialization deferred).
func NewConnectionPool(maxConns int, logger *slog.Logger) *ConnectionPool {
	return &ConnectionPool{
		maxConns: maxConns,
		logger:   logger,
	}
}

// Init initializes connections lazily (called once).
// Expensive operation only runs on first call.
func (p *ConnectionPool) Init(ctx context.Context) error {
	p.initOnce.Do(func() {
		p.logger.Info("initializing connection pool",
			"max_connections", p.maxConns)

		// Simulate expensive initialization
		p.connections = make([]*Connection, p.maxConns)
		for i := 0; i < p.maxConns; i++ {
			select {
			case <-ctx.Done():
				p.initErr = ctx.Err()
				return
			default:
				p.connections[i] = &Connection{
					ID:     "conn-" + string(rune(i)),
					Active: true,
				}
			}
		}

		p.logger.Info("connection pool ready",
			"connections", len(p.connections))
	})

	return p.initErr
}

// GetConnection returns a connection (initializes if needed).
func (p *ConnectionPool) GetConnection(ctx context.Context) (*Connection, error) {
	if err := p.Init(ctx); err != nil {
		return nil, err
	}

	if len(p.connections) == 0 {
		return nil, ErrNoConnectionsAvailable
	}

	return p.connections[0], nil
}

// ConfigLoader loads configuration once and caches it.
// Demonstrates lazy loading with sync.Once.
type ConfigLoader struct {
	config     *WorkerConfig
	loadOnce   sync.Once
	loadErr    error
	configPath string
	logger     *slog.Logger
}

// NewConfigLoader creates a config loader.
func NewConfigLoader(configPath string, logger *slog.Logger) *ConfigLoader {
	return &ConfigLoader{
		configPath: configPath,
		logger:     logger,
	}
}

// Load loads configuration once (thread-safe).
// Multiple goroutines calling Load will block until first completes.
func (c *ConfigLoader) Load(ctx context.Context) (*WorkerConfig, error) {
	c.loadOnce.Do(func() {
		c.logger.Info("loading configuration", "path", c.configPath)

		// Simulate expensive config loading
		select {
		case <-ctx.Done():
			c.loadErr = ctx.Err()
			return
		case <-time.After(100 * time.Millisecond):
			// Config loaded
		}

		c.config = &WorkerConfig{
			WorkerCount:     DefaultWorkerCount,
			BufferSize:      DefaultBufferSize,
			ShutdownTimeout: DefaultShutdownTimeout,
			ProcessTimeout:  DefaultProcessTimeout,
		}

		c.logger.Info("configuration loaded",
			"workers", c.config.WorkerCount,
			"buffer", c.config.BufferSize)
	})

	if c.loadErr != nil {
		return nil, c.loadErr
	}

	return c.config, nil
}

// MetricsCollector collects metrics with lazy initialization.
// Demonstrates combining sync.Once with atomic operations.
type MetricsCollector struct {
	stats      *WorkerStats
	initOnce   sync.Once
	enabled    atomic.Bool
	sampleRate float64
}

// NewMetricsCollector creates a metrics collector.
func NewMetricsCollector(sampleRate float64) *MetricsCollector {
	return &MetricsCollector{
		sampleRate: sampleRate,
	}
}

// Init initializes metrics collection once.
func (m *MetricsCollector) Init() *WorkerStats {
	m.initOnce.Do(func() {
		m.stats = NewWorkerStats()
		m.enabled.Store(true)
	})
	return m.stats
}

// Record records a metric (initializes if needed).
func (m *MetricsCollector) Record() {
	stats := m.Init()
	if m.enabled.Load() {
		stats.RecordSubmission()
	}
}

// ServiceRegistry manages multiple services with lazy initialization.
// Each service initialized once on first access.
type ServiceRegistry struct {
	executor       TaskExecutor
	executorOnce   sync.Once
	repository     TaskRepository
	repositoryOnce sync.Once
	publisher      MessagePublisher
	publisherOnce  sync.Once
	logger         *slog.Logger
}

// NewServiceRegistry creates a service registry.
func NewServiceRegistry(logger *slog.Logger) *ServiceRegistry {
	return &ServiceRegistry{
		logger: logger,
	}
}

// GetExecutor returns executor (initializes once).
func (s *ServiceRegistry) GetExecutor() TaskExecutor {
	s.executorOnce.Do(func() {
		s.logger.Info("initializing task executor")
		// s.executor = NewTaskExecutor()
	})
	return s.executor
}

// GetRepository returns repository (initializes once).
func (s *ServiceRegistry) GetRepository() TaskRepository {
	s.repositoryOnce.Do(func() {
		s.logger.Info("initializing task repository")
		// s.repository = NewTaskRepository()
	})
	return s.repository
}

// GetPublisher returns publisher (initializes once).
func (s *ServiceRegistry) GetPublisher() MessagePublisher {
	s.publisherOnce.Do(func() {
		s.logger.Info("initializing message publisher")
		// s.publisher = NewMessagePublisher()
	})
	return s.publisher
}

// ResetOnce demonstrates resetting sync.Once (testing only).
// CRITICAL: Never do this in production code.
type ResettableOnce struct {
	mu   sync.Mutex
	done atomic.Bool
}

// Do executes function once (resettable for testing).
func (o *ResettableOnce) Do(f func()) {
	if o.done.Load() {
		return
	}

	o.mu.Lock()
	defer o.mu.Unlock()

	if o.done.Load() {
		return
	}

	f()
	o.done.Store(true)
}

// Reset allows Do to be called again (testing only).
func (o *ResettableOnce) Reset() {
	o.done.Store(false)
}
