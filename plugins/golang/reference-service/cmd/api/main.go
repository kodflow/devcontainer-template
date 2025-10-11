// Package main provides the entry point for the TodoList API server.
//
// Purpose:
//   Initializes and starts the HTTP server for the TodoList API.
//
// Responsibilities:
//   - Initialize application dependencies
//   - Configure and start HTTP server
//   - Handle graceful shutdown
//
// Features:
//   - HTTP Server
//   - Graceful Shutdown
//
// Constraints:
//   - Must run on specified port or default 8080
//   - Must handle OS signals for shutdown
//
package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/domain/todo"
	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/repository"
)

const (
	// DefaultPort is the default HTTP server port.
	DefaultPort = "8080"

	// ShutdownTimeout is the maximum time to wait for graceful shutdown.
	ShutdownTimeout = 30 * time.Second
)

func main() {
	if err := run(); err != nil {
		log.Fatalf("Application failed: %v", err)
	}
}

func run() error {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	repo, err := repository.NewRepository(repository.Config{
		MaxTodos: todo.DefaultMaxTodoLimit,
	})
	if err != nil {
		return fmt.Errorf("failed to create repository: %w", err)
	}

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	log.Printf("TodoList API initialized with repository")
	log.Printf("Repository capacity: %d todos", todo.DefaultMaxTodoLimit)
	log.Printf("Ready to start server on port %s (not yet implemented)", DefaultPort)
	log.Println("Press Ctrl+C to shutdown...")

	<-sigChan
	log.Println("Shutdown signal received, cleaning up...")

	shutdownCtx, shutdownCancel := context.WithTimeout(ctx, ShutdownTimeout)
	defer shutdownCancel()

	<-shutdownCtx.Done()

	log.Println("Repository:", repo)
	log.Println("Application stopped gracefully")
	return nil
}
