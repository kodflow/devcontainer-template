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

// Service is a marker interface for any service that can be registered.
//
// Any type can be registered as a service. The registry performs no
// validation on the service type - it's the caller's responsibility
// to ensure type safety using type assertions or type switches.
//
// Example:
//   type MyService struct { ... }
//   var _ Service = (*MyService)(nil) // compile-time type check
type Service interface{}

// ServiceRegistry defines the interface for service discovery operations.
//
// Implementations must be thread-safe and maintain uniqueness constraints
// on service names. The registry uses write-through semantics - all operations
// take effect immediately.
type ServiceRegistry interface {
	// Register adds a service to the registry with the given name.
	//
	// The service name must be unique within the registry. If a service
	// with the same name exists, ErrServiceAlreadyExists is returned.
	// Thread-safe using write lock.
	//
	// Parameters:
	//   - name: Unique identifier for the service (must not be empty)
	//   - svc: Service instance to register (any type)
	//
	// Returns:
	//   - error: Possible errors:
	//     - ErrServiceAlreadyExists if name is already registered
	//     - ErrRegistryFull if registry is at MaxServices capacity
	//
	// Example:
	//   err := registry.Register("todo-repo", repoInstance)
	//   if err != nil {
	//       log.Fatal(err)
	//   }
	Register(name string, svc Service) error

	// Lookup retrieves a service by its registered name.
	//
	// Returns the service instance if found. The caller must use type
	// assertion to convert to the expected type.
	// Thread-safe using read lock.
	//
	// Parameters:
	//   - name: Service name to lookup
	//
	// Returns:
	//   - Service: The registered service instance (requires type assertion)
	//   - error: ErrServiceNotFound if the service doesn't exist
	//
	// Example:
	//   svc, err := registry.Lookup("todo-repo")
	//   if err != nil {
	//       return err
	//   }
	//   repo, ok := svc.(todo.Repository)
	//   if !ok {
	//       return errors.New("invalid service type")
	//   }
	Lookup(name string) (Service, error)

	// Unregister removes a service from the registry by name.
	//
	// If the service doesn't exist, returns ErrServiceNotFound.
	// Thread-safe using write lock.
	//
	// Parameters:
	//   - name: Service name to remove
	//
	// Returns:
	//   - error: ErrServiceNotFound if service doesn't exist
	//
	// Example:
	//   if err := registry.Unregister("old-service"); err != nil {
	//       log.Printf("unregister failed: %v", err)
	//   }
	Unregister(name string) error

	// Count returns the current number of registered services.
	//
	// Thread-safe using read lock. O(1) complexity.
	//
	// Returns:
	//   - int: Number of services currently registered (0 to MaxServices)
	//
	// Example:
	//   count := registry.Count()
	//   fmt.Printf("Registry has %d/%d services\n", count, MaxServices)
	Count() int
}
