package registry_test

import (
	"testing"

	"github.com/anthropics/claude-code/plugins/golang/reference-service/internal/infrastructure/registry"
)

func TestRegistry_Register(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()
	err := reg.Register("test-service", "some-service")

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if reg.Count() != 1 {
		t.Errorf("expected count 1, got %d", reg.Count())
	}
}

func TestRegistry_Lookup(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()
	reg.Register("test-service", "my-value")

	svc, err := reg.Lookup("test-service")
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if svc != "my-value" {
		t.Errorf("expected 'my-value', got %v", svc)
	}
}

func TestRegistry_Unregister(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()
	reg.Register("test-service", "some-service")
	err := reg.Unregister("test-service")

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}

	if reg.Count() != 0 {
		t.Errorf("expected count 0 after unregister, got %d", reg.Count())
	}
}

func TestRegistry_LookupNotFound(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()
	_, err := reg.Lookup("nonexistent")

	if err != registry.ErrServiceNotFound {
		t.Errorf("expected ErrServiceNotFound, got %v", err)
	}
}

func TestRegistry_Register_Duplicate(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()
	reg.Register("test-service", "first")

	err := reg.Register("test-service", "second")

	if err != registry.ErrServiceAlreadyExists {
		t.Errorf("expected ErrServiceAlreadyExists, got %v", err)
	}

	// Verify original service is still there
	svc, _ := reg.Lookup("test-service")
	if svc != "first" {
		t.Errorf("expected original service 'first', got %v", svc)
	}
}

func TestRegistry_Register_MaxCapacity(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()

	// Register MaxServices (100) services
	for i := 0; i < registry.MaxServices; i++ {
		err := reg.Register("service-"+string(rune(i)), i)
		if err != nil {
			t.Fatalf("failed to register service %d: %v", i, err)
		}
	}

	// Try to register one more - should fail
	err := reg.Register("extra-service", "extra")

	if err != registry.ErrRegistryFull {
		t.Errorf("expected ErrRegistryFull, got %v", err)
	}

	if reg.Count() != registry.MaxServices {
		t.Errorf("expected count %d, got %d", registry.MaxServices, reg.Count())
	}
}

func TestRegistry_Unregister_NotFound(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()

	err := reg.Unregister("nonexistent")

	if err != registry.ErrServiceNotFound {
		t.Errorf("expected ErrServiceNotFound, got %v", err)
	}
}

func TestRegistry_Count_Empty(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()

	if reg.Count() != 0 {
		t.Errorf("expected count 0 for empty registry, got %d", reg.Count())
	}
}

func TestRegistry_TypeAssertions(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()

	// Register different types
	reg.Register("string-svc", "string value")
	reg.Register("int-svc", 42)
	reg.Register("struct-svc", struct{ Name string }{"test"})

	// Lookup and type assert string
	strSvc, _ := reg.Lookup("string-svc")
	if str, ok := strSvc.(string); !ok || str != "string value" {
		t.Error("failed to assert string service")
	}

	// Lookup and type assert int
	intSvc, _ := reg.Lookup("int-svc")
	if num, ok := intSvc.(int); !ok || num != 42 {
		t.Error("failed to assert int service")
	}

	// Lookup and type assert struct
	structSvc, _ := reg.Lookup("struct-svc")
	if s, ok := structSvc.(struct{ Name string }); !ok || s.Name != "test" {
		t.Error("failed to assert struct service")
	}
}

func TestRegistry_UnregisterAndReregister(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()

	// Register
	reg.Register("test-service", "first")

	// Unregister
	reg.Unregister("test-service")

	// Re-register with same name but different value
	err := reg.Register("test-service", "second")
	if err != nil {
		t.Fatalf("expected to re-register after unregister, got error: %v", err)
	}

	// Verify new value
	svc, _ := reg.Lookup("test-service")
	if svc != "second" {
		t.Errorf("expected 're-registered service 'second', got %v", svc)
	}
}

func TestRegistry_MultipleServices(t *testing.T) {
	t.Parallel()

	reg := registry.NewRegistry()

	services := map[string]interface{}{
		"svc1": "value1",
		"svc2": "value2",
		"svc3": "value3",
	}

	// Register all
	for name, value := range services {
		if err := reg.Register(name, value); err != nil {
			t.Fatalf("failed to register %s: %v", name, err)
		}
	}

	if reg.Count() != 3 {
		t.Errorf("expected count 3, got %d", reg.Count())
	}

	// Verify all can be looked up
	for name, expectedValue := range services {
		svc, err := reg.Lookup(name)
		if err != nil {
			t.Errorf("failed to lookup %s: %v", name, err)
		}
		if svc != expectedValue {
			t.Errorf("service %s: expected %v, got %v", name, expectedValue, svc)
		}
	}
}
