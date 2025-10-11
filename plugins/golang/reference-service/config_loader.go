// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Once for lazy configuration loading and caching.
//
// Responsibilities:
//   - Configuration loading with thread-safe lazy initialization
//   - One-time configuration load guarantee
//   - Configuration caching
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
	"time"
)

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
