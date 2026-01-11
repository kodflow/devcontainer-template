# DRY - Don't Repeat Yourself

> Chaque élément de connaissance doit avoir une représentation unique et non ambiguë dans un système.

**Auteurs :** Andrew Hunt & David Thomas (The Pragmatic Programmer, 1999)

## Principe

**DRY ne concerne pas seulement le code dupliqué, mais toute forme de duplication de connaissance :**

- Code
- Documentation
- Configuration
- Schémas de données
- Processus

## Exemples

### Code

```go
// ❌ WET (Write Everything Twice)
func validateEmail(email string) bool {
	matched, _ := regexp.MatchString(`^[^\s@]+@[^\s@]+\.[^\s@]+$`, email)
	return matched
}

func validateUserEmail(email string) bool {
	matched, _ := regexp.MatchString(`^[^\s@]+@[^\s@]+\.[^\s@]+$`, email) // Dupliqué
	return matched
}

// ✅ DRY
var emailRegex = regexp.MustCompile(`^[^\s@]+@[^\s@]+\.[^\s@]+$`)

func validateEmail(email string) bool {
	return emailRegex.MatchString(email)
}
```

### Configuration

```go
// ❌ WET
type Config struct {
	Development EnvironmentConfig
	Staging     EnvironmentConfig
}

type EnvironmentConfig struct {
	DatabaseHost string
	DatabasePort int  // Dupliqué partout
	DatabaseName string
}

var config = Config{
	Development: EnvironmentConfig{
		DatabaseHost: "localhost",
		DatabasePort: 5432,
		DatabaseName: "myapp_dev",
	},
	Staging: EnvironmentConfig{
		DatabaseHost: "staging.example.com",
		DatabasePort: 5432, // Dupliqué
		DatabaseName: "myapp_staging",
	},
}

// ✅ DRY
const DefaultDatabasePort = 5432

type EnvironmentConfig struct {
	DatabaseHost string
	DatabasePort int
	DatabaseName string
}

func NewEnvironmentConfig(host, name string) EnvironmentConfig {
	return EnvironmentConfig{
		DatabaseHost: host,
		DatabasePort: DefaultDatabasePort,
		DatabaseName: name,
	}
}

var config = Config{
	Development: NewEnvironmentConfig("localhost", "myapp_dev"),
	Staging:     NewEnvironmentConfig("staging.example.com", "myapp_staging"),
}
```

### Documentation

```go
// ❌ WET - Doc et code désynchronisés
// CalculateTotal calculates the total price with 20% tax
func CalculateTotal(price float64) float64 {
	return price * 1.15 // Bug: doc dit 20%, code fait 15%
}

// ✅ DRY - Single source of truth
const TaxRate = 0.20

// CalculateTotal calculates the total price with tax.
func CalculateTotal(price float64) float64 {
	return price * (1 + TaxRate)
}
```

## Quand NE PAS appliquer DRY

### Couplage accidentel

```go
// ❌ Mauvaise abstraction DRY
func processEntity(entity interface{}) error {
	// Logic très différente selon le type
	// → Mieux vaut 3 fonctions séparées
	switch e := entity.(type) {
	case *User:
		// ...
	case *Product:
		// ...
	case *Order:
		// ...
	default:
		return errors.New("unknown entity type")
	}
	return nil
}

// ✅ Duplication acceptable
func processUser(user *User) error {
	// User-specific logic
	return nil
}

func processProduct(product *Product) error {
	// Product-specific logic
	return nil
}

func processOrder(order *Order) error {
	// Order-specific logic
	return nil
}
```

### Règle des 3

> Dupliquer 2 fois est acceptable. À la 3ème, refactoriser.

Raison : Éviter les abstractions prématurées.

## Anti-pattern : WET

**WET = Write Everything Twice** (ou "Waste Everyone's Time")

Symptômes :

- Même bug à corriger à plusieurs endroits
- Changement de règle métier = modifications multiples
- "J'ai oublié de modifier l'autre endroit"

## Patterns liés

| Pattern | Relation avec DRY |
|---------|-------------------|
| Template Method | Factoriser le squelette d'algorithme |
| Strategy | Factoriser les variations d'algorithme |
| Decorator | Éviter la duplication dans les sous-classes |
| Factory | Centraliser la logique de création |

## Quand utiliser

- Quand une meme logique metier apparait a plusieurs endroits
- Lors de la centralisation de constantes ou configurations
- Pour synchroniser documentation et code (single source of truth)
- Quand un bug doit etre corrige a plusieurs endroits identiques
- Apres la 3eme occurrence d'un pattern similaire (regle des 3)

## Checklist

- [ ] Ce code existe-t-il ailleurs ?
- [ ] Cette config est-elle dupliquée ?
- [ ] La doc et le code sont-ils synchronisés ?
- [ ] Les constantes sont-elles centralisées ?

## Sources

- [The Pragmatic Programmer](https://pragprog.com/titles/tpp20/)
- [Wikipedia - DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself)
