package taskqueue_test

import (
	"log/slog"
	"sync"
	"testing"

	"taskqueue"
)

func TestServiceRegistry_Singleton(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetServiceRegistry returns global singleton

	registry1 := taskqueue.GetServiceRegistry(slog.Default())
	registry2 := taskqueue.GetServiceRegistry(slog.Default())

	if registry1 != registry2 {
		t.Error("expected GetServiceRegistry to return same instance")
	}
}

func TestServiceRegistry_RegisterAndGet(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetServiceRegistry returns global singleton

	registry := taskqueue.GetServiceRegistry(slog.Default())

	service := &taskqueue.Service{
		Name:    "test-service",
		Version: "1.0.0",
		Status:  "active",
	}

	registry.RegisterService(service)

	retrieved, exists := registry.GetService("test-service")
	if !exists {
		t.Fatal("expected service to be found")
	}
	if retrieved.Name != "test-service" {
		t.Error("expected service name to match")
	}
	if retrieved.Version != "1.0.0" {
		t.Error("expected service version to match")
	}
}

func TestServiceRegistry_ConcurrentAccess(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetServiceRegistry returns global singleton

	registry := taskqueue.GetServiceRegistry(slog.Default())
	const goroutines = 50

	var wg sync.WaitGroup
	wg.Add(goroutines)

	for i := 0; i < goroutines; i++ {
		go func(id int) {
			defer wg.Done()

			service := &taskqueue.Service{
				Name:    string(rune(id + 4000)),
				Version: "1.0.0",
				Status:  "active",
			}

			registry.RegisterService(service)
			registry.GetService(service.Name)
		}(i)
	}

	wg.Wait()
}

func TestServiceRegistry_GetNonExistent(t *testing.T) {
	// Note: Cannot use t.Parallel() because GetServiceRegistry returns global singleton

	registry := taskqueue.GetServiceRegistry(slog.Default())

	_, exists := registry.GetService("non-existent-service")
	if exists {
		t.Error("expected service to not exist")
	}
}
