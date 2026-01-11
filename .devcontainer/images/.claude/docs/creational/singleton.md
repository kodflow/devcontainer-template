# Singleton Pattern

> Garantir une instance unique d'une classe avec un point d'acces global.

## Intention

S'assurer qu'une classe n'a qu'une seule instance et fournir un point
d'acces global a cette instance.

## Structure classique

```go
package main

import (
	"fmt"
	"sync"
)

// Connection represente une connexion a la base de donnees.
type Connection struct {
	host string
}

// Execute execute une requete SQL.
func (c *Connection) Execute(sql string) string {
	return fmt.Sprintf("Executing: %s on %s", sql, c.host)
}

// Database gere la connexion singleton.
type Database struct {
	connection *Connection
}

var (
	instance *Database
	once     sync.Once
)

// getInstance retourne l'instance unique (thread-safe avec sync.Once).
func getInstance() *Database {
	once.Do(func() {
		fmt.Println("Connecting to database...")
		instance = &Database{
			connection: &Connection{host: "localhost:5432"},
		}
	})
	return instance
}

// Query execute une requete SQL.
func (db *Database) Query(sql string) string {
	return db.connection.Execute(sql)
}

// Usage
func ExampleDatabase() {
	db1 := getInstance()
	db2 := getInstance()
	fmt.Println(db1 == db2) // true
}
```

## Variantes

### Singleton Thread-safe (avec sync.Once)

```go
package main

import (
	"fmt"
	"sync"
)

// ThreadSafeDatabase garantit une instance unique en environnement concurrent.
type ThreadSafeDatabase struct {
	connectionString string
}

var (
	safeInstance *ThreadSafeDatabase
	safeOnce     sync.Once
)

// GetInstance retourne l'instance unique de maniere thread-safe.
func GetInstance() *ThreadSafeDatabase {
	safeOnce.Do(func() {
		fmt.Println("Initializing database connection...")
		safeInstance = &ThreadSafeDatabase{
			connectionString: "postgres://localhost:5432/mydb",
		}
	})
	return safeInstance
}

// Query execute une requete.
func (db *ThreadSafeDatabase) Query(sql string) string {
	return fmt.Sprintf("Query on %s: %s", db.connectionString, sql)
}
```

### Singleton avec sync.OnceValue (Go 1.21+ - RECOMMENDED)

```go
package main

import (
	"fmt"
	"sync"
)

// Database represente une connexion singleton.
type Database struct {
	connectionString string
}

// NewDatabase cree une nouvelle instance de Database.
func newDatabase() *Database {
	fmt.Println("Initializing database connection...")
	return &Database{
		connectionString: "postgres://localhost:5432/mydb",
	}
}

// GetDB retourne l'instance singleton de maniere type-safe.
// sync.OnceValue (Go 1.21+) est plus concis et type-safe que sync.Once.
var GetDB = sync.OnceValue(newDatabase)

// Query execute une requete.
func (db *Database) Query(sql string) string {
	return fmt.Sprintf("Query on %s: %s", db.connectionString, sql)
}

// Usage
func ExampleOnceValue() {
	db1 := GetDB()
	db2 := GetDB()
	fmt.Println(db1 == db2) // true

	result := db1.Query("SELECT * FROM users")
	fmt.Println(result)
}
```

### Singleton avec sync.OnceValues (pour valeur + erreur)

```go
package main

import (
	"errors"
	"os"
	"sync"
)

// Config represente la configuration de l'application.
type Config struct {
	DatabaseURL string
	APIKey      string
}

// loadConfig charge la configuration depuis l'environnement.
func loadConfig() (*Config, error) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		return nil, errors.New("DATABASE_URL not set")
	}

	apiKey := os.Getenv("API_KEY")
	if apiKey == "" {
		return nil, errors.New("API_KEY not set")
	}

	return &Config{
		DatabaseURL: dbURL,
		APIKey:      apiKey,
	}, nil
}

// GetConfig retourne la configuration singleton avec gestion d'erreur.
// sync.OnceValues (Go 1.21+) permet de retourner une valeur ET une erreur.
var GetConfig = sync.OnceValues(loadConfig)

// Usage
func ExampleOnceValues() {
	config, err := GetConfig()
	if err != nil {
		panic(err)
	}

	// Les appels suivants retournent le meme resultat (cache)
	config2, _ := GetConfig()
	println(config == config2) // true
}
```

### Singleton avec initialisation paresseuse (Lazy)

```go
package main

import (
	"fmt"
	"sync"
)

// LazyLogger implemente un logger singleton avec initialisation paresseuse.
type LazyLogger struct {
	logLevel string
}

var (
	loggerInstance *LazyLogger
	loggerOnce     sync.Once
)

// GetLogger retourne l'instance du logger (initialise au premier appel).
func GetLogger() *LazyLogger {
	loggerOnce.Do(func() {
		loggerInstance = &LazyLogger{
			logLevel: "INFO",
		}
	})
	return loggerInstance
}

// Log ecrit un message de log.
func (l *LazyLogger) Log(message string) {
	fmt.Printf("[%s] %s\n", l.logLevel, message)
}
```

### Singleton avec configuration

```go
package main

import (
	"errors"
	"sync"
)

// ConfigOptions definit les options de configuration.
type ConfigOptions struct {
	Host  string
	Port  int
	Debug bool
}

// ConfigManager gere la configuration singleton.
type ConfigManager struct {
	config ConfigOptions
}

var (
	configInstance *ConfigManager
	configOnce     sync.Once
	configMu       sync.RWMutex
	initialized    bool
)

// Initialize initialise le ConfigManager avec les options donnees.
func Initialize(options ConfigOptions) error {
	configMu.Lock()
	defer configMu.Unlock()

	if initialized {
		return errors.New("ConfigManager already initialized")
	}

	configOnce.Do(func() {
		configInstance = &ConfigManager{
			config: options,
		}
		initialized = true
	})

	return nil
}

// GetConfigManager retourne l'instance du ConfigManager.
func GetConfigManager() (*ConfigManager, error) {
	configMu.RLock()
	defer configMu.RUnlock()

	if !initialized {
		return nil, errors.New("ConfigManager not initialized")
	}
	return configInstance, nil
}

// GetHost retourne le host configure.
func (cm *ConfigManager) GetHost() string {
	return cm.config.Host
}

// GetPort retourne le port configure.
func (cm *ConfigManager) GetPort() int {
	return cm.config.Port
}

// IsDebug retourne si le mode debug est active.
func (cm *ConfigManager) IsDebug() bool {
	return cm.config.Debug
}

// Usage
func ExampleConfigManager() {
	err := Initialize(ConfigOptions{
		Host:  "localhost",
		Port:  3000,
		Debug: true,
	})
	if err != nil {
		panic(err)
	}

	config, err := GetConfigManager()
	if err != nil {
		panic(err)
	}
	println(config.GetHost()) // localhost
}
```

## Pourquoi Singleton est souvent un anti-pattern

```go
// PROBLEMES:

// 1. Etat global cache - difficile a tracer
type OrderService struct{}

func (s *OrderService) Process(order Order) error {
	// D'ou vient cette dependance? Invisible dans la signature
	db := getInstance()
	db.Query("INSERT INTO orders...")
	logger := GetLogger()
	logger.Log("Order processed")
	return nil
}

// 2. Couplage fort - difficile a tester
type UserService struct{}

func (s *UserService) GetUser(id string) (*User, error) {
	// Comment mocker Database dans les tests?
	db := getInstance()
	result := db.Query("SELECT * FROM users WHERE id=" + id)
	return &User{}, nil
}

// 3. Violation du SRP - gere son cycle de vie + sa logique
type BadSingleton struct {
	data string
}

var badInstance *BadSingleton
var badOnce sync.Once

func getBadSingleton() *BadSingleton { // Responsabilite 1: cycle de vie
	badOnce.Do(func() {
		badInstance = &BadSingleton{}
	})
	return badInstance
}

func (b *BadSingleton) ProcessData() { // Responsabilite 2: logique metier
	// ...
}

// 4. Problemes de concurrence dans les tests
// Les tests partagent la meme instance = effets de bord
```

## Alternatives modernes

### Dependency Injection (recommande)

```go
package main

import (
	"context"
	"database/sql"
	"fmt"
)

// 1. Interface pour l'abstraction
type IDatabase interface {
	Query(ctx context.Context, sql string) (string, error)
}

// 2. Implementation concrete
type Database struct {
	connectionString string
}

// NewDatabase cree une nouvelle instance de Database.
func NewDatabase(connectionString string) *Database {
	return &Database{
		connectionString: connectionString,
	}
}

func (db *Database) Query(ctx context.Context, sql string) (string, error) {
	return fmt.Sprintf("Query result for: %s", sql), nil
}

// 3. Container DI
type Container struct {
	mu       sync.RWMutex
	services map[string]interface{}
}

// NewContainer cree un nouveau container DI.
func NewContainer() *Container {
	return &Container{
		services: make(map[string]interface{}),
	}
}

// RegisterSingleton enregistre un service singleton.
func (c *Container) RegisterSingleton(token string, instance interface{}) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.services[token] = instance
}

// Resolve resout un service par son token.
func (c *Container) Resolve(token string) (interface{}, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	service, exists := c.services[token]
	if !exists {
		return nil, fmt.Errorf("service %s not found", token)
	}
	return service, nil
}

// 4. Configuration
func ExampleDI() {
	container := NewContainer()
	container.RegisterSingleton("database", NewDatabase("postgres://localhost:5432"))

	// 5. Usage - dependances explicites
	type UserService struct {
		db IDatabase
	}

	dbService, err := container.Resolve("database")
	if err != nil {
		panic(err)
	}

	userService := &UserService{
		db: dbService.(IDatabase),
	}
	_ = userService
}
```

### Module pattern (package-level variables)

```go
package database

import (
	"context"
	"fmt"
	"sync"
)

var (
	connection *Connection
	once       sync.Once
)

// Connection represente une connexion a la base de donnees.
type Connection struct {
	host string
}

// init initialise la connexion au demarrage du package.
func init() {
	once.Do(func() {
		connection = &Connection{
			host: "localhost:5432",
		}
	})
}

// Query execute une requete SQL (acces direct a la connexion singleton).
func Query(ctx context.Context, sql string) (string, error) {
	return fmt.Sprintf("Executing: %s", sql), nil
}

// Close ferme la connexion.
func Close() error {
	// Implementation de fermeture
	return nil
}

// Usage - le package est naturellement singleton
// import "yourproject/database"
// result, err := database.Query(ctx, "SELECT * FROM users")
```

### Factory avec scope

```go
package main

import (
	"sync"
)

// Scope definit la portee d'un service.
type Scope string

const (
	ScopeSingleton Scope = "singleton"
	ScopeTransient Scope = "transient"
	ScopeScoped    Scope = "scoped"
)

// ServiceFactory gere la creation de services avec differents scopes.
type ServiceFactory struct {
	mu        sync.RWMutex
	instances map[string]interface{}
}

// NewServiceFactory cree une nouvelle factory.
func NewServiceFactory() *ServiceFactory {
	return &ServiceFactory{
		instances: make(map[string]interface{}),
	}
}

// Singleton retourne ou cree une instance singleton.
func (f *ServiceFactory) Singleton(key string, factory func() interface{}) interface{} {
	f.mu.Lock()
	defer f.mu.Unlock()

	if instance, exists := f.instances[key]; exists {
		return instance
	}

	instance := factory()
	f.instances[key] = instance
	return instance
}

// Transient cree toujours une nouvelle instance.
func (f *ServiceFactory) Transient(factory func() interface{}) interface{} {
	return factory()
}

// Scoped retourne une instance limitee a un scope donne.
func (f *ServiceFactory) Scoped(scope, key string, factory func() interface{}) interface{} {
	scopeKey := fmt.Sprintf("%s:%s", scope, key)
	f.mu.Lock()
	defer f.mu.Unlock()

	if instance, exists := f.instances[scopeKey]; exists {
		return instance
	}

	instance := factory()
	f.instances[scopeKey] = instance
	return instance
}
```

## Tests unitaires

```go
package main

import (
	"context"
	"sync"
	"testing"
)

// Test du Singleton classique
func TestDatabase_Singleton(t *testing.T) {
	// Reset necessaire entre les tests (utiliser build tags ou interfaces)
	once = sync.Once{}
	instance = nil

	db1 := getInstance()
	db2 := getInstance()

	if db1 != db2 {
		t.Error("expected same instance")
	}
}

// Test avec DI (facile)
type mockDatabase struct{}

func (m *mockDatabase) Query(ctx context.Context, sql string) (string, error) {
	return "mock result", nil
}

func TestUserService_WithDI(t *testing.T) {
	type UserService struct {
		db IDatabase
	}

	mockDB := &mockDatabase{}
	service := &UserService{db: mockDB}

	result, err := service.db.Query(context.Background(), "SELECT * FROM users")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if result != "mock result" {
		t.Errorf("expected 'mock result', got %s", result)
	}
}

// Test du module pattern
func TestDatabaseModule_Query(t *testing.T) {
	ctx := context.Background()
	result, err := Query(ctx, "SELECT 1")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == "" {
		t.Error("expected non-empty result")
	}
}

// Test de thread-safety
func TestGetInstance_Concurrent(t *testing.T) {
	once = sync.Once{}
	instance = nil

	var wg sync.WaitGroup
	instances := make([]*Database, 100)

	for i := 0; i < 100; i++ {
		idx := i // Capture for closure
		wg.Go(func() { // Go 1.25: handles Add/Done internally
			instances[idx] = getInstance()
		})
	}

	wg.Wait()

	// Toutes les instances doivent etre identiques
	for i := 1; i < len(instances); i++ {
		if instances[i] != instances[0] {
			t.Error("expected all instances to be the same")
		}
	}
}
```

## Quand utiliser (vraiment)

- Ressources partagees couteuses (pool de connexions)
- Configuration globale de l'application
- Cache applicatif
- Logger (mais preferer DI)

## Quand eviter

- Quand la testabilite est importante
- Quand plusieurs configurations sont possibles
- Dans les bibliotheques (imposer un singleton aux utilisateurs)
- Quand l'etat global cree du couplage

## Decision : Singleton vs DI

| Critere | Singleton | DI Container |
|---------|-----------|--------------|
| Simplicite initiale | Oui | Non |
| Testabilite | Difficile | Facile |
| Flexibilite | Faible | Elevee |
| Couplage | Fort | Faible |
| Configuration | Statique | Dynamique |

## Patterns lies

- **Factory** : Controle la creation du Singleton
- **Facade** : Souvent implemente comme Singleton
- **Service Locator** : Alternative au DI (mais anti-pattern similaire)

## Sources

- [Refactoring Guru - Singleton](https://refactoring.guru/design-patterns/singleton)
- [Mark Seemann - Service Locator is an Anti-Pattern](https://blog.ploeh.dk/2010/02/03/ServiceLocatorisanAnti-Pattern/)
