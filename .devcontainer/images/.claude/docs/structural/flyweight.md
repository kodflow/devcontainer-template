# Flyweight

> Minimiser l'utilisation memoire en partageant les donnees communes entre plusieurs objets similaires.

---

## Principe

Le pattern Flyweight permet de stocker une seule instance des donnees repetitives (etat intrinseque) et de passer l'etat variable (etat extrinseque) en parametre des operations.

```
┌─────────────────┐
│ FlyweightFactory│
│  cache: map     │────────┐
└────────┬────────┘        │
         │ get()           │
         ▼                 ▼
┌─────────────────┐   ┌─────────────┐
│   Flyweight     │   │  Flyweight  │
│ (intrinsic)     │   │ (shared)    │
└─────────────────┘   └─────────────┘
```

---

## Probleme resolu

- Grande quantite d'objets similaires en memoire
- Donnees repetees entre objets (ex: polices, textures)
- Cout memoire prohibitif
- Immutabilite des donnees partagees

---

## Solution

```go
package main

import (
    "fmt"
    "sync"
)

// TreeType est le flyweight (etat intrinseque partage).
type TreeType struct {
    Name    string
    Color   string
    Texture string
}

func (t *TreeType) Draw(x, y int) {
    fmt.Printf("Drawing %s tree at (%d, %d)\n", t.Name, x, y)
}

// TreeFactory gere le cache de flyweights.
type TreeFactory struct {
    mu    sync.RWMutex
    cache map[string]*TreeType
}

func NewTreeFactory() *TreeFactory {
    return &TreeFactory{
        cache: make(map[string]*TreeType),
    }
}

func (f *TreeFactory) GetTreeType(name, color, texture string) *TreeType {
    key := name + "_" + color + "_" + texture

    f.mu.RLock()
    if tt, ok := f.cache[key]; ok {
        f.mu.RUnlock()
        return tt
    }
    f.mu.RUnlock()

    f.mu.Lock()
    defer f.mu.Unlock()

    // Double-check
    if tt, ok := f.cache[key]; ok {
        return tt
    }

    tt := &TreeType{Name: name, Color: color, Texture: texture}
    f.cache[key] = tt
    return tt
}

// Tree contient l'etat extrinseque (unique par instance).
type Tree struct {
    X, Y     int
    TreeType *TreeType // flyweight partage
}

func NewTree(x, y int, treeType *TreeType) *Tree {
    return &Tree{X: x, Y: y, TreeType: treeType}
}

func (t *Tree) Draw() {
    t.TreeType.Draw(t.X, t.Y)
}

// Usage:
// factory := NewTreeFactory()
// oak := factory.GetTreeType("Oak", "green", "bark.png")
// tree1 := NewTree(10, 20, oak)
// tree2 := NewTree(30, 40, oak) // meme TreeType
```

---

## Exemple complet

```go
package main

import (
    "fmt"
    "sync"
)

// CharacterStyle est le flyweight pour le formatage de texte.
type CharacterStyle struct {
    FontFamily string
    FontSize   int
    Bold       bool
    Italic     bool
    Color      string
}

func (s *CharacterStyle) String() string {
    return fmt.Sprintf("%s-%d-%v-%v-%s", s.FontFamily, s.FontSize, s.Bold, s.Italic, s.Color)
}

// StyleFactory gere le cache de styles.
type StyleFactory struct {
    mu     sync.RWMutex
    styles map[string]*CharacterStyle
}

func NewStyleFactory() *StyleFactory {
    return &StyleFactory{
        styles: make(map[string]*CharacterStyle),
    }
}

func (f *StyleFactory) GetStyle(family string, size int, bold, italic bool, color string) *CharacterStyle {
    key := fmt.Sprintf("%s-%d-%v-%v-%s", family, size, bold, italic, color)

    f.mu.RLock()
    if style, ok := f.styles[key]; ok {
        f.mu.RUnlock()
        return style
    }
    f.mu.RUnlock()

    f.mu.Lock()
    defer f.mu.Unlock()

    if style, ok := f.styles[key]; ok {
        return style
    }

    style := &CharacterStyle{
        FontFamily: family,
        FontSize:   size,
        Bold:       bold,
        Italic:     italic,
        Color:      color,
    }
    f.styles[key] = style
    return style
}

func (f *StyleFactory) Count() int {
    f.mu.RLock()
    defer f.mu.RUnlock()
    return len(f.styles)
}

// Character represente un caractere avec son style (etat extrinseque: rune, position).
type Character struct {
    Char     rune
    Position int
    Style    *CharacterStyle // flyweight
}

// Document utilise les flyweights.
type Document struct {
    characters []*Character
    factory    *StyleFactory
}

func NewDocument(factory *StyleFactory) *Document {
    return &Document{
        characters: make([]*Character, 0),
        factory:    factory,
    }
}

func (d *Document) AddCharacter(char rune, family string, size int, bold, italic bool, color string) {
    style := d.factory.GetStyle(family, size, bold, italic, color)
    position := len(d.characters)
    d.characters = append(d.characters, &Character{
        Char:     char,
        Position: position,
        Style:    style,
    })
}

func (d *Document) Render() {
    for _, c := range d.characters {
        fmt.Printf("%c", c.Char)
    }
    fmt.Println()
}

func (d *Document) Stats() {
    fmt.Printf("Characters: %d, Unique styles: %d\n", len(d.characters), d.factory.Count())
}

func main() {
    factory := NewStyleFactory()
    doc := NewDocument(factory)

    // Ajouter du texte avec differents styles
    text := "Hello, World!"
    for i, char := range text {
        if i < 6 {
            // "Hello," en bold
            doc.AddCharacter(char, "Arial", 12, true, false, "black")
        } else {
            // " World!" en normal
            doc.AddCharacter(char, "Arial", 12, false, false, "black")
        }
    }

    // Ajouter plus de texte
    for _, char := range " This is a test." {
        doc.AddCharacter(char, "Arial", 12, false, false, "black")
    }

    doc.Render()
    doc.Stats()

    // Output:
    // Hello, World! This is a test.
    // Characters: 29, Unique styles: 2
    // (Seulement 2 styles partages pour 29 caracteres!)
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Simple Flyweight | Un seul type de flyweight | Cas basique |
| Unshared Flyweight | Certains objets non partages | Cas speciaux |
| Composite Flyweight | Flyweights dans structures composites | Hierarchies |

---

## Quand utiliser

- Enorme quantite d'objets similaires
- Cout memoire significatif
- Etat extrinseque peut etre calcule/passe
- Identite des objets non importante

## Quand NE PAS utiliser

- Peu d'objets a creer
- Objets tres differents les uns des autres
- Etat extrinseque difficile a externaliser
- Besoin d'identite unique par objet

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Economies de memoire significatives | Complexite accrue |
| Performance amelioree | Cout CPU pour calcul etat extrinseque |
| Moins de GC pressure | Code moins intuitif |
| | Thread safety necessaire pour factory |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Singleton | Factory est souvent singleton |
| Composite | Feuilles comme flyweights |
| State/Strategy | Les objets State peuvent etre flyweights |
| Factory | Utilise pour gerer le cache |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| sync.Pool | Pool d'objets reutilisables |
| string interning | Partage de strings identiques |
| image/color | Couleurs predefinies partagees |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Flyweight mutable | Corruption etat partage | Immutabilite stricte |
| Sur-optimisation | Complexite pour peu de gain | Mesurer avant d'optimiser |
| Oublier thread safety | Race conditions | sync.RWMutex ou sync.Map |

---

## Tests

```go
func TestTreeFactory_SharedInstance(t *testing.T) {
    factory := NewTreeFactory()

    oak1 := factory.GetTreeType("Oak", "green", "bark.png")
    oak2 := factory.GetTreeType("Oak", "green", "bark.png")

    if oak1 != oak2 {
        t.Error("expected same instance for identical parameters")
    }
}

func TestTreeFactory_DifferentInstances(t *testing.T) {
    factory := NewTreeFactory()

    oak := factory.GetTreeType("Oak", "green", "bark.png")
    pine := factory.GetTreeType("Pine", "green", "pine.png")

    if oak == pine {
        t.Error("expected different instances for different parameters")
    }
}

func TestStyleFactory_Count(t *testing.T) {
    factory := NewStyleFactory()

    factory.GetStyle("Arial", 12, false, false, "black")
    factory.GetStyle("Arial", 12, false, false, "black") // duplicate
    factory.GetStyle("Arial", 14, false, false, "black") // different size

    if factory.Count() != 2 {
        t.Errorf("expected 2 unique styles, got %d", factory.Count())
    }
}

func BenchmarkWithFlyweight(b *testing.B) {
    factory := NewStyleFactory()
    doc := NewDocument(factory)

    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        doc.AddCharacter('a', "Arial", 12, false, false, "black")
    }
}
```

---

## Sources

- [Refactoring Guru - Flyweight](https://refactoring.guru/design-patterns/flyweight)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Go sync.Pool](https://pkg.go.dev/sync#Pool)
