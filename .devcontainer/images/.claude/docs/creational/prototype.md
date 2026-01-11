# Prototype

> Creer de nouveaux objets en clonant une instance existante plutot qu'en l'instanciant.

---

## Principe

Le pattern Prototype permet de copier des objets existants sans dependre
de leurs classes. Utile quand la creation d'un objet est couteuse.

```text
┌─────────────┐         ┌─────────────┐
│  Prototype  │◄────────│   Client    │
│  (Clone())  │         └─────────────┘
└─────────────┘
       ▲
       │
┌──────┴──────┐
│  Concrete   │
│  Prototype  │
└─────────────┘
```

---

## Probleme resolu

- Creation d'objets complexes avec de nombreux parametres
- Duplication d'objets sans connaitre leur classe concrete
- Eviter les hierarchies de factories paralleles
- Performance: cloner plutot que reconstruire

---

## Solution

```go
package main

import "fmt"

// Cloner definit l'interface de clonage.
type Cloner interface {
    Clone() Cloner
}

// Document represente un document clonable.
type Document struct {
    Title    string
    Content  string
    Author   string
    Metadata map[string]string
}

// Clone cree une copie profonde du document.
func (d *Document) Clone() Cloner {
    // Copie profonde de la map
    metaCopy := make(map[string]string, len(d.Metadata))
    for k, v := range d.Metadata {
        metaCopy[k] = v
    }

    return &Document{
        Title:    d.Title,
        Content:  d.Content,
        Author:   d.Author,
        Metadata: metaCopy,
    }
}

// Usage:
// template := &Document{Title: "Template", Content: "..."}
// copy := template.Clone().(*Document)
// copy.Title = "New Document"
```

---

## Exemple complet

```go
package main

import (
    "encoding/json"
    "fmt"
)

// Shape definit une forme clonable.
type Shape interface {
    Clone() Shape
    GetInfo() string
}

// Rectangle implemente Shape.
type Rectangle struct {
    Width  float64
    Height float64
    Color  string
}

func (r *Rectangle) Clone() Shape {
    return &Rectangle{
        Width:  r.Width,
        Height: r.Height,
        Color:  r.Color,
    }
}

func (r *Rectangle) GetInfo() string {
    return fmt.Sprintf("Rectangle %.2fx%.2f (%s)", r.Width, r.Height, r.Color)
}

// Circle implemente Shape.
type Circle struct {
    Radius float64
    Color  string
}

func (c *Circle) Clone() Shape {
    return &Circle{
        Radius: c.Radius,
        Color:  c.Color,
    }
}

func (c *Circle) GetInfo() string {
    return fmt.Sprintf("Circle r=%.2f (%s)", c.Radius, c.Color)
}

// ShapeRegistry gere un cache de prototypes.
type ShapeRegistry struct {
    shapes map[string]Shape
}

func NewShapeRegistry() *ShapeRegistry {
    return &ShapeRegistry{
        shapes: make(map[string]Shape),
    }
}

func (r *ShapeRegistry) Register(name string, shape Shape) {
    r.shapes[name] = shape
}

func (r *ShapeRegistry) Get(name string) (Shape, bool) {
    if shape, ok := r.shapes[name]; ok {
        return shape.Clone(), true
    }
    return nil, false
}

func main() {
    // 1. Creer un registre de prototypes
    registry := NewShapeRegistry()

    // 2. Enregistrer des prototypes
    registry.Register("red-rect", &Rectangle{Width: 10, Height: 5, Color: "red"})
    registry.Register("blue-circle", &Circle{Radius: 3, Color: "blue"})

    // 3. Cloner depuis le registre
    shape1, _ := registry.Get("red-rect")
    shape2, _ := registry.Get("red-rect")
    shape3, _ := registry.Get("blue-circle")

    // 4. Modifier les clones independamment
    shape1.(*Rectangle).Width = 20

    fmt.Println(shape1.GetInfo()) // Rectangle 20.00x5.00 (red)
    fmt.Println(shape2.GetInfo()) // Rectangle 10.00x5.00 (red) - original dimensions
    fmt.Println(shape3.GetInfo()) // Circle r=3.00 (blue)
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Shallow Copy | Copie les references | Objets immutables |
| Deep Copy | Copie recursive | Objets avec etat mutable |
| Registry | Cache de prototypes | Templates reutilisables |
| Serialization | Clone via JSON/Gob | Objets complexes |

---

## Quand utiliser

- La creation d'objets est couteuse (DB, reseau, calculs)
- Besoin de copies independantes d'objets complexes
- Eviter une explosion de sous-classes de factories
- Systeme de templates/presets

## Quand NE PAS utiliser

- Objets simples avec peu de champs
- Pas besoin de copies (passage par valeur suffit)
- Graphes d'objets avec references circulaires complexes

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Evite le couplage aux classes | Cloner objets complexes difficile |
| Elimine le code d'init repetitif | Gestion des refs circulaires |
| Alternative aux factories | Deep copy peut etre couteux |
| Produit des objets preconfigures | |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Factory Method | Alternative: Factory cree, Prototype clone |
| Abstract Factory | Peut utiliser Prototype pour creer les produits |
| Memento | Similaire: sauvegarde d'etat vs copie complete |
| Composite | Les composites peuvent etre clones recursivement |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| Go standard | `encoding/gob` pour deep copy |
| copier | `github.com/jinzhu/copier` |
| deepcopy | `github.com/mohae/deepcopy` |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Shallow copy accidentel | Mutation partagee | Deep copy explicite |
| Clone() retourne interface{} | Perte type safety | Retourner type concret |
| Oublier champs prives | Clone incomplet | Serialization/reflexion |

---

## Tests

```go
func TestDocument_Clone(t *testing.T) {
    original := &Document{
        Title:    "Original",
        Content:  "Content",
        Author:   "Author",
        Metadata: map[string]string{"key": "value"},
    }

    clone := original.Clone().(*Document)

    // Verifier copie
    if clone.Title != original.Title {
        t.Errorf("expected %s, got %s", original.Title, clone.Title)
    }

    // Verifier independance
    clone.Title = "Modified"
    clone.Metadata["key"] = "modified"

    if original.Title == clone.Title {
        t.Error("clone should be independent")
    }
    if original.Metadata["key"] == clone.Metadata["key"] {
        t.Error("metadata should be deep copied")
    }
}

func TestShapeRegistry(t *testing.T) {
    registry := NewShapeRegistry()
    registry.Register("test", &Rectangle{Width: 10, Height: 5, Color: "red"})

    shape1, ok1 := registry.Get("test")
    shape2, ok2 := registry.Get("test")

    if !ok1 || !ok2 {
        t.Fatal("expected shapes from registry")
    }

    // Modifier un clone
    shape1.(*Rectangle).Width = 20

    // L'autre clone doit etre inchange
    if shape2.(*Rectangle).Width != 10 {
        t.Error("clones should be independent")
    }
}
```

---

## Sources

- [Refactoring Guru - Prototype](https://refactoring.guru/design-patterns/prototype)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Go Patterns - Prototype](https://github.com/tmrts/go-patterns)
