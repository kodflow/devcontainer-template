# Creational Patterns (GoF)

Patterns de creation d'objets.

## Fichiers detailles

| Pattern | Fichier | Description |
|---------|---------|-------------|
| Builder | [builder.md](builder.md) | Construction complexe etape par etape |
| Factory Method / Abstract Factory | [factory.md](factory.md) | Delegation de creation |
| Prototype | [prototype.md](prototype.md) | Cloner des objets existants |
| Singleton | [singleton.md](singleton.md) | Instance unique + alternatives DI |

## Les 5 Patterns

### 1. Factory Method

> Deleguer la creation aux sous-classes.

Voir fichier detaille: [factory.md](factory.md)

```go
package factory

// Logger defines the logging interface.
type Logger interface {
	Log(message string)
}

// LoggerFactory creates loggers.
type LoggerFactory interface {
	CreateLogger() Logger
}

// ConsoleLogger logs to console.
type ConsoleLogger struct{}

func (c *ConsoleLogger) Log(message string) {
	fmt.Println(message)
}

// ConsoleLoggerFactory creates console loggers.
type ConsoleLoggerFactory struct{}

func (f *ConsoleLoggerFactory) CreateLogger() Logger {
	return &ConsoleLogger{}
}

// Usage
func LogMessage(factory LoggerFactory, message string) {
	logger := factory.CreateLogger()
	logger.Log(message)
}
```

**Quand :** Creation deleguee aux sous-classes.

---

### 2. Abstract Factory

> Familles d'objets lies.

Voir fichier detaille: [factory.md](factory.md)

```go
package factory

// Button defines button interface.
type Button interface {
	Render() string
}

// Input defines input interface.
type Input interface {
	Render() string
}

// UIFactory creates UI components.
type UIFactory interface {
	CreateButton() Button
	CreateInput() Input
}

// MaterialButton is a material design button.
type MaterialButton struct{}

func (b *MaterialButton) Render() string { return "<material-button/>" }

// MaterialInput is a material design input.
type MaterialInput struct{}

func (i *MaterialInput) Render() string { return "<material-input/>" }

// MaterialUIFactory creates material UI components.
type MaterialUIFactory struct{}

func (f *MaterialUIFactory) CreateButton() Button { return &MaterialButton{} }
func (f *MaterialUIFactory) CreateInput() Input   { return &MaterialInput{} }
```

**Quand :** Plusieurs familles d'objets coherents.

---

### 3. Builder

> Construction complexe etape par etape.

Voir fichier detaille: [builder.md](builder.md)

```go
package builder

// QueryBuilder builds SQL queries.
type QueryBuilder struct {
	columns []string
	table   string
	where   string
}

func NewQueryBuilder() *QueryBuilder {
	return &QueryBuilder{}
}

func (qb *QueryBuilder) Select(columns []string) *QueryBuilder {
	qb.columns = columns
	return qb
}

func (qb *QueryBuilder) From(table string) *QueryBuilder {
	qb.table = table
	return qb
}

func (qb *QueryBuilder) Where(condition string) *QueryBuilder {
	qb.where = condition
	return qb
}

func (qb *QueryBuilder) Build() string {
	return fmt.Sprintf("SELECT %s FROM %s WHERE %s",
		strings.Join(qb.columns, ", "), qb.table, qb.where)
}

// Usage
// query := NewQueryBuilder().
//     Select([]string{"id", "name"}).
//     From("users").
//     Where("active = true").
//     Build()
```

**Quand :** Objets complexes avec nombreuses options.

---

### 4. Prototype

> Cloner des objets existants.

```go
package prototype

// Prototype defines cloneable objects.
type Prototype[T any] interface {
	Clone() T
}

// Document is a cloneable document.
type Document struct {
	Title    string
	Content  string
	Metadata map[string]string
}

func (d *Document) Clone() *Document {
	// Deep copy metadata
	metaCopy := make(map[string]string, len(d.Metadata))
	for k, v := range d.Metadata {
		metaCopy[k] = v
	}

	return &Document{
		Title:    d.Title,
		Content:  d.Content,
		Metadata: metaCopy,
	}
}
```

**Quand :** Cout de creation eleve, copie plus efficace.

---

### 5. Singleton

> Instance unique globale.

Voir fichier detaille: [singleton.md](singleton.md)

```go
package singleton

import "sync"

// Database represents a database connection.
type Database struct {
	connectionString string
}

// GetDB returns the singleton database instance.
// sync.OnceValue (Go 1.21+) is type-safe and concise.
var GetDB = sync.OnceValue(func() *Database {
	return &Database{
		connectionString: "postgres://localhost:5432/mydb",
	}
})

// Usage
// db1 := GetDB()
// db2 := GetDB()
// fmt.Println(db1 == db2) // true
```

**Quand :** Une seule instance requise (attention: souvent un anti-pattern).

---

## Tableau de decision

| Besoin | Pattern |
|--------|---------|
| Deleguer creation a sous-classes | Factory Method |
| Familles d'objets coherents | Abstract Factory |
| Construction complexe/optionnelle | Builder |
| Clonage plus efficace que creation | Prototype |
| Instance unique | Singleton |

## Alternatives modernes

| Pattern | Alternative |
|---------|-------------|
| Factory | Dependency Injection |
| Singleton | DI Container (scoped) |
| Builder | Functional Options |

## Sources

- [Refactoring Guru - Creational Patterns](https://refactoring.guru/design-patterns/creational-patterns)
