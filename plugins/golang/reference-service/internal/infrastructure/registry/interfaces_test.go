package registry_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/registry"
)

// mockServiceRegistry implements registry.ServiceRegistry for testing.
type mockServiceRegistry struct {
	registerFunc   func(name string, svc registry.Service) error
	lookupFunc     func(name string) (registry.Service, error)
	unregisterFunc func(name string) error
	countFunc      func() int
}

func (m *mockServiceRegistry) Register(name string, svc registry.Service) error {
	if m.registerFunc != nil {
		return m.registerFunc(name, svc)
	}
	return nil
}

func (m *mockServiceRegistry) Lookup(name string) (registry.Service, error) {
	if m.lookupFunc != nil {
		return m.lookupFunc(name)
	}
	return nil, registry.ErrServiceNotFound
}

func (m *mockServiceRegistry) Unregister(name string) error {
	if m.unregisterFunc != nil {
		return m.unregisterFunc(name)
	}
	return nil
}

func (m *mockServiceRegistry) Count() int {
	if m.countFunc != nil {
		return m.countFunc()
	}
	return 0
}

// Ensure Registry implements ServiceRegistry interface.
var _ registry.ServiceRegistry = (*registry.Registry)(nil)

// Ensure mockServiceRegistry implements ServiceRegistry interface.
var _ registry.ServiceRegistry = (*mockServiceRegistry)(nil)

func TestServiceRegistryInterface(t *testing.T) {
	t.Parallel()

	mock := &mockServiceRegistry{
		registerFunc: func(name string, svc registry.Service) error {
			return nil
		},
		countFunc: func() int {
			return 1
		},
	}

	err := mock.Register("test-service", "test-impl")
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}

	count := mock.Count()
	if count != 1 {
		t.Errorf("count = %d, want 1", count)
	}
}

func TestRegistryImplementsInterface(t *testing.T) {
	t.Parallel()

	// This test verifies at compile time that Registry implements ServiceRegistry.
	// The var _ assignment above ensures this.
	var reg registry.ServiceRegistry
	if reg != nil {
		t.Error("registry should be nil initially")
	}
}

func TestServiceInterface(t *testing.T) {
	t.Parallel()

	// Test that any type can be a Service
	var _ registry.Service = "string service"
	var _ registry.Service = 123
	var _ registry.Service = struct{ Name string }{"test"}

	// Verify we can store different types
	services := []registry.Service{
		"string",
		42,
		struct{ Value int }{100},
	}

	if len(services) != 3 {
		t.Errorf("expected 3 services, got %d", len(services))
	}
}
