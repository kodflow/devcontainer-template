// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Once for managing multiple service lazy initializations.
//
// Responsibilities:
//   - Service dependency management with lazy initialization
//   - Thread-safe one-time initialization per service
//   - Service instance caching and retrieval
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
	"log/slog"
	"sync"
)

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
