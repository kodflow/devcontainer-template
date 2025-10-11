// Package registry provides service discovery and registration.
//
// Purpose:
//   Implements a service registry for component discovery.
//
// Responsibilities:
//   - Register services by name
//   - Lookup services by name
//   - Track registered services
//
// Features:
//   - Service Discovery
//   - Thread-safe Registry
//
// Constraints:
//   - Maximum 100 services
//   - Names must be unique
//
package registry

import (
	"sync"
)

// Registry implements thread-safe service discovery and registration.
//
// Fields:
//   - services: Map of service name to service instance
//   - mu: Read-write mutex for thread-safe concurrent access
//
// Thread Safety:
//   All methods are thread-safe using RWMutex.
//   Multiple readers can lookup simultaneously, writes are exclusive.
//
// Memory:
//   Fields ordered by size for memory alignment.
//   Services are stored as interface{} allowing any type.
type Registry struct {
	services map[string]Service
	mu       sync.RWMutex
}

// NewRegistry creates a new empty Registry ready for service registration.
//
// The registry is initialized with an empty map and requires no configuration.
// All operations are thread-safe from first use. Capacity is limited to
// MaxServices (100) concurrent registrations.
//
// Returns:
//   - *Registry: New registry instance with no initial services
//
// Example:
//   reg := NewRegistry()
//   err := reg.Register("todo-service", todoService)
//   if err != nil {
//       log.Fatal(err)
//   }
func NewRegistry() *Registry {
	return &Registry{
		services: make(map[string]Service),
	}
}

// Register adds a service to the registry with the given unique name.
//
// The service name must be unique within the registry. If a service with
// the same name already exists, ErrServiceAlreadyExists is returned.
// The registry has a maximum capacity of MaxServices (100).
// Thread-safe using write lock.
//
// Parameters:
//   - name: Unique identifier for the service (must not be empty)
//   - svc: Service instance to register (any type implementing Service)
//
// Returns:
//   - error: Possible errors:
//     - ErrServiceAlreadyExists if name is already registered
//     - ErrRegistryFull if registry is at MaxServices capacity
//
// Example:
//   repo := repository.NewRepository(config)
//   err := registry.Register("todo-repository", repo)
//   if err == ErrServiceAlreadyExists {
//       log.Println("service already registered")
//   }
func (r *Registry) Register(name string, svc Service) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if len(r.services) >= MaxServices {
		return ErrRegistryFull
	}

	if _, exists := r.services[name]; exists {
		return ErrServiceAlreadyExists
	}

	r.services[name] = svc
	return nil
}

// Lookup retrieves a service by its registered name.
//
// Returns the service instance if found. The caller must use type assertion
// to convert the returned interface{} to the expected concrete type.
// Thread-safe using read lock.
//
// Parameters:
//   - name: Service name to lookup (must match registered name exactly)
//
// Returns:
//   - Service: The registered service instance (requires type assertion)
//   - error: ErrServiceNotFound if the service doesn't exist
//
// Example:
//   svc, err := registry.Lookup("todo-repository")
//   if err != nil {
//       return nil, err
//   }
//   repo, ok := svc.(todo.Repository)
//   if !ok {
//       return nil, errors.New("service has wrong type")
//   }
//   // use repo...
func (r *Registry) Lookup(name string) (Service, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()

	svc, exists := r.services[name]
	if !exists {
		return nil, ErrServiceNotFound
	}

	return svc, nil
}

// Unregister removes a service from the registry by name.
//
// If the service doesn't exist, returns ErrServiceNotFound.
// After unregistration, the service can be registered again with the same name.
// Thread-safe using write lock.
//
// Parameters:
//   - name: Service name to remove (must match registered name exactly)
//
// Returns:
//   - error: ErrServiceNotFound if service doesn't exist
//
// Example:
//   err := registry.Unregister("old-service")
//   if err == ErrServiceNotFound {
//       log.Println("service was not registered")
//   }
func (r *Registry) Unregister(name string) error {
	r.mu.Lock()
	defer r.mu.Unlock()

	if _, exists := r.services[name]; !exists {
		return ErrServiceNotFound
	}

	delete(r.services, name)
	return nil
}

// Count returns the current number of registered services.
//
// Thread-safe using read lock. O(1) complexity.
// Useful for monitoring registry capacity and debugging.
//
// Returns:
//   - int: Number of services currently registered (0 to MaxServices)
//
// Example:
//   count := registry.Count()
//   if count >= MaxServices {
//       log.Println("registry at maximum capacity")
//   }
//   fmt.Printf("Registry: %d/%d services\n", count, MaxServices)
func (r *Registry) Count() int {
	r.mu.RLock()
	defer r.mu.RUnlock()

	return len(r.services)
}
