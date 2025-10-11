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

import "errors"

// Service registry errors.
var (
	// ErrServiceNotFound is returned when a service lookup fails.
	//
	// Returned by:
	//   - Registry.Lookup when the service name doesn't exist
	//   - Registry.Unregister when attempting to remove non-existent service
	//
	// Resolution:
	//   - Verify the service name is correct
	//   - Check if the service has been registered
	//   - Use Registry.Count to verify registry state
	ErrServiceNotFound = errors.New("service not found")

	// ErrServiceAlreadyExists is returned when attempting to register a duplicate service name.
	//
	// Returned by:
	//   - Registry.Register when the service name is already registered
	//
	// Resolution:
	//   - Use a different service name
	//   - Unregister the existing service first
	//   - Check Registry.Lookup before registering
	ErrServiceAlreadyExists = errors.New("service already exists")

	// ErrRegistryFull is returned when the registry reaches MaxServices capacity.
	//
	// Returned by:
	//   - Registry.Register when len(services) >= MaxServices
	//
	// Resolution:
	//   - Unregister unused services to free slots
	//   - Increase MaxServices if necessary (requires code change)
	//   - Review service architecture to reduce service count
	ErrRegistryFull = errors.New("registry is full")
)
