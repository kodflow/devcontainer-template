# KISS - Keep It Simple, Stupid

> La simplicité doit être un objectif clé dans la conception.

**Origine :** Kelly Johnson, ingénieur Lockheed (années 1960)

## Principe

La complexité est l'ennemi de la fiabilité. Le code simple est :

- Plus facile à lire
- Plus facile à maintenir
- Plus facile à tester
- Moins sujet aux bugs

## Exemples

### Logique conditionnelle

```go
// ❌ Complexe
func GetDiscount(user *User) float64 {
	if user.IsPremium {
		if user.Years > 5 {
			if user.Orders > 100 {
				return 0.25
			} else {
				return 0.20
			}
		} else {
			return 0.15
		}
	} else {
		if user.Orders > 50 {
			return 0.10
		} else {
			return 0.05
		}
	}
}

// ✅ Simple - Guard clauses
func GetDiscount(user *User) float64 {
	if user.IsPremium && user.Years > 5 && user.Orders > 100 {
		return 0.25
	}
	if user.IsPremium && user.Years > 5 {
		return 0.20
	}
	if user.IsPremium {
		return 0.15
	}
	if user.Orders > 50 {
		return 0.10
	}
	return 0.05
}

// ✅✅ Encore plus simple avec une table
type DiscountRule struct {
	Condition func(*User) bool
	Discount  float64
}

var DiscountRules = []DiscountRule{
	{func(u *User) bool { return u.IsPremium && u.Years > 5 && u.Orders > 100 }, 0.25},
	{func(u *User) bool { return u.IsPremium && u.Years > 5 }, 0.20},
	{func(u *User) bool { return u.IsPremium }, 0.15},
	{func(u *User) bool { return u.Orders > 50 }, 0.10},
}

func GetDiscount(user *User) float64 {
	for _, rule := range DiscountRules {
		if rule.Condition(user) {
			return rule.Discount
		}
	}
	return 0.05
}
```

### Architecture

```
❌ Complexe (prématuré)
┌─────────┐    ┌─────────┐    ┌─────────┐
│ Gateway │───▶│ Service │───▶│   DB    │
└─────────┘    └─────────┘    └─────────┘
      │              │              │
      ▼              ▼              ▼
┌─────────┐    ┌─────────┐    ┌─────────┐
│  Cache  │    │  Queue  │    │ Replica │
└─────────┘    └─────────┘    └─────────┘

✅ Simple (pour commencer)
┌─────────┐    ┌─────────┐
│   App   │───▶│   DB    │
└─────────┘    └─────────┘
```

### Fonctions

```go
// ❌ Fonction trop "intelligente"
type ProcessOptions struct {
	Validate  bool
	Transform bool
	Cache     bool
	Log       bool
	Retry     int
}

func ProcessData(data interface{}, options *ProcessOptions) (interface{}, error) {
	// 100 lignes de code avec tous les cas
	if options == nil {
		options = &ProcessOptions{}
	}
	// ... complexité
	return nil, nil
}

// ✅ Fonctions simples et composables
func ValidateData(data interface{}) error {
	// Simple validation
	return nil
}

func TransformData(data interface{}) (interface{}, error) {
	// Simple transformation
	return data, nil
}

func CacheData(data interface{}) error {
	// Simple caching
	return nil
}

// Composition claire
func ProcessDataSimple(data interface{}) (interface{}, error) {
	if err := ValidateData(data); err != nil {
		return nil, fmt.Errorf("validation failed: %w", err)
	}
	
	transformed, err := TransformData(data)
	if err != nil {
		return nil, fmt.Errorf("transformation failed: %w", err)
	}
	
	if err := CacheData(transformed); err != nil {
		return nil, fmt.Errorf("caching failed: %w", err)
	}
	
	return transformed, nil
}
```

## Signaux de complexité

| Signal | Action |
|--------|--------|
| Fonction > 20 lignes | Diviser |
| Plus de 3 niveaux d'indentation | Extraire |
| Commentaire "c'est compliqué" | Simplifier |
| Difficile à expliquer | Repenser |
| Beaucoup de paramètres (>3) | Créer une struct config |

## Quand la complexité est nécessaire

KISS ne veut pas dire "pas de complexité". Parfois elle est justifiée :

- Optimisation de performance prouvée par benchmarks
- Exigences métier réellement complexes
- Contraintes techniques inévitables

Dans ces cas, **documenter le pourquoi**.

## Relation avec autres principes

| Principe | Relation |
|----------|----------|
| YAGNI | Ne pas ajouter de complexité inutile |
| DRY | Mais pas au prix de la lisibilité |
| SOLID | Peut ajouter de la complexité structurelle |

## Checklist

- [ ] Quelqu'un peut-il comprendre en 5 minutes ?
- [ ] Peut-on expliquer sans dire "c'est compliqué" ?
- [ ] Y a-t-il une solution plus simple ?
- [ ] Cette abstraction est-elle vraiment nécessaire ?

## Quand utiliser

- Lors de la conception initiale d'un module ou d'une fonctionnalite
- Quand le code devient difficile a expliquer ou a comprendre
- Lors de revues de code pour identifier la complexite accidentelle
- Avant d'ajouter une abstraction ou un niveau d'indirection
- Quand on refactorise du code legacy trop complexe

## Patterns liés

- [YAGNI](./YAGNI.md) - Complementaire : eviter la complexite inutile
- [DRY](./DRY.md) - Attention a ne pas sur-abstraire au nom de DRY
- [Defensive Programming](./defensive.md) - Guard clauses simplifient les conditions

## Sources

- [Wikipedia - KISS](https://en.wikipedia.org/wiki/KISS_principle)
- [Simple Made Easy - Rich Hickey](https://www.infoq.com/presentations/Simple-Made-Easy/)
