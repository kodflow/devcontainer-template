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

// MaxServices defines the maximum number of services that can be registered.
//
// This limit prevents unbounded memory growth and ensures the registry
// remains manageable. When this limit is reached, new registrations
// will fail with ErrRegistryFull.
//
// Used by:
//   - Registry.Register to enforce capacity limits
//   - Application initialization to validate service counts
const MaxServices = 100
