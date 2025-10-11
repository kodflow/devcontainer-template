// Package taskqueue provides concurrent task processing with worker pools.
//
// Purpose:
//   Demonstrates sync.Once for lazy initialization of expensive resources.
//
// Responsibilities:
//   - Database connection pool management
//   - Lazy initialization of connections
//   - Thread-safe one-time pool initialization
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
)

// ConnectionPool manages database connections with lazy initialization.
// Demonstrates sync.Once for expensive resource initialization.
type ConnectionPool struct {
	connections []*Connection
	initOnce    sync.Once
	initErr     error
	maxConns    int
	logger      *slog.Logger
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
