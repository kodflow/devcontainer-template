# Composite

> Composer des objets en structures arborescentes pour representer des hierarchies partie-tout.

---

## Principe

Le pattern Composite permet aux clients de traiter des objets individuels et des compositions d'objets de maniere uniforme. Il est ideal pour les structures arborescentes comme les systemes de fichiers, les menus, ou les organisations.

```
        ┌────────────┐
        │ Component  │
        │ operation()│
        └─────┬──────┘
              │
    ┌─────────┴─────────┐
    │                   │
┌───┴───┐         ┌─────┴─────┐
│ Leaf  │         │ Composite │
└───────┘         │ children[]│
                  └───────────┘
```

---

## Probleme resolu

- Traiter uniformement objets simples et composites
- Representer des hierarchies partie-tout
- Permettre des operations recursives sur l'arbre
- Simplifier le code client (pas de distinction feuille/branche)

---

## Solution

```go
package main

import "fmt"

// Component definit l'interface commune.
type Component interface {
    GetSize() int64
    GetName() string
    Print(indent string)
}

// File est une feuille.
type File struct {
    name string
    size int64
}

func NewFile(name string, size int64) *File {
    return &File{name: name, size: size}
}

func (f *File) GetSize() int64   { return f.size }
func (f *File) GetName() string  { return f.name }
func (f *File) Print(indent string) {
    fmt.Printf("%s- %s (%d bytes)\n", indent, f.name, f.size)
}

// Directory est un composite.
type Directory struct {
    name     string
    children []Component
}

func NewDirectory(name string) *Directory {
    return &Directory{name: name, children: []Component{}}
}

func (d *Directory) Add(c Component) {
    d.children = append(d.children, c)
}

func (d *Directory) GetSize() int64 {
    var total int64
    for _, child := range d.children {
        total += child.GetSize()
    }
    return total
}

func (d *Directory) GetName() string { return d.name }

func (d *Directory) Print(indent string) {
    fmt.Printf("%s+ %s/\n", indent, d.name)
    for _, child := range d.children {
        child.Print(indent + "  ")
    }
}

// Usage:
// root := NewDirectory("root")
// root.Add(NewFile("readme.txt", 100))
// root.Add(NewDirectory("src"))
// root.Print("")
```

---

## Exemple complet

```go
package main

import (
    "fmt"
    "strings"
)

// Employee represente un employe dans une organisation.
type Employee interface {
    GetName() string
    GetSalary() float64
    GetSubordinates() []Employee
    Add(e Employee)
    Remove(name string)
    Print(indent int)
}

// Developer est une feuille (pas de subordonnes).
type Developer struct {
    name   string
    salary float64
}

func NewDeveloper(name string, salary float64) *Developer {
    return &Developer{name: name, salary: salary}
}

func (d *Developer) GetName() string                { return d.name }
func (d *Developer) GetSalary() float64             { return d.salary }
func (d *Developer) GetSubordinates() []Employee    { return nil }
func (d *Developer) Add(e Employee)                 {} // no-op
func (d *Developer) Remove(name string)             {} // no-op
func (d *Developer) Print(indent int) {
    fmt.Printf("%s- %s (Dev, $%.0f)\n", strings.Repeat("  ", indent), d.name, d.salary)
}

// Manager est un composite (a des subordonnes).
type Manager struct {
    name         string
    salary       float64
    subordinates []Employee
}

func NewManager(name string, salary float64) *Manager {
    return &Manager{name: name, salary: salary, subordinates: []Employee{}}
}

func (m *Manager) GetName() string    { return m.name }
func (m *Manager) GetSalary() float64 { return m.salary }
func (m *Manager) GetSubordinates() []Employee {
    return m.subordinates
}

func (m *Manager) Add(e Employee) {
    m.subordinates = append(m.subordinates, e)
}

func (m *Manager) Remove(name string) {
    for i, sub := range m.subordinates {
        if sub.GetName() == name {
            m.subordinates = append(m.subordinates[:i], m.subordinates[i+1:]...)
            return
        }
    }
}

func (m *Manager) Print(indent int) {
    fmt.Printf("%s+ %s (Manager, $%.0f)\n", strings.Repeat("  ", indent), m.name, m.salary)
    for _, sub := range m.subordinates {
        sub.Print(indent + 1)
    }
}

// GetTotalSalary calcule le salaire total recursif.
func GetTotalSalary(e Employee) float64 {
    total := e.GetSalary()
    for _, sub := range e.GetSubordinates() {
        total += GetTotalSalary(sub)
    }
    return total
}

func main() {
    // Construire la hierarchie
    ceo := NewManager("Alice (CEO)", 200000)

    techVP := NewManager("Bob (VP Tech)", 150000)
    techVP.Add(NewDeveloper("Charlie", 80000))
    techVP.Add(NewDeveloper("Diana", 85000))

    teamLead := NewManager("Eve (Team Lead)", 100000)
    teamLead.Add(NewDeveloper("Frank", 75000))
    teamLead.Add(NewDeveloper("Grace", 78000))
    techVP.Add(teamLead)

    salesVP := NewManager("Henry (VP Sales)", 140000)
    salesVP.Add(NewDeveloper("Ivy", 70000))

    ceo.Add(techVP)
    ceo.Add(salesVP)

    // Afficher l'organisation
    fmt.Println("Organization Chart:")
    ceo.Print(0)

    // Calculer le salaire total
    fmt.Printf("\nTotal Salary: $%.0f\n", GetTotalSalary(ceo))

    // Output:
    // Organization Chart:
    // + Alice (CEO) (Manager, $200000)
    //   + Bob (VP Tech) (Manager, $150000)
    //     - Charlie (Dev, $80000)
    //     - Diana (Dev, $85000)
    //     + Eve (Team Lead) (Manager, $100000)
    //       - Frank (Dev, $75000)
    //       - Grace (Dev, $78000)
    //   + Henry (VP Sales) (Manager, $140000)
    //     - Ivy (Dev, $70000)
    //
    // Total Salary: $978000
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Transparent | Methodes add/remove dans Component | Uniformite maximale |
| Safe | Methodes add/remove dans Composite | Type safety |
| Cached | Cache des calculs recursifs | Performance |

---

## Quand utiliser

- Representer des hierarchies d'objets
- Traiter uniformement feuilles et composites
- Operations recursives sur structures arborescentes
- Systemes de fichiers, menus, UI, organisations

## Quand NE PAS utiliser

- Structures plates sans hierarchie
- Peu de similarite entre feuilles et composites
- Performance critique (overhead de recursion)

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Code client simplifie | Difficile de restreindre les types |
| Ajout facile de nouveaux composants | Generalisation peut compliquer le design |
| Structure flexible | Overhead pour petites collections |
| Open/Closed Principle | |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Decorator | Ajoute comportement, Composite structure |
| Iterator | Parcourir les composites |
| Visitor | Operations sur la hierarchie |
| Flyweight | Partager les feuilles |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| html/template | Arbre de noeuds |
| go/ast | AST (Abstract Syntax Tree) |
| encoding/xml | Structure DOM |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Leaky abstraction | Exposer la difference feuille/branche | Interface uniforme |
| Deep nesting | Performance et complexite | Limiter la profondeur |
| Circular references | Boucles infinies | Validation a l'ajout |

---

## Tests

```go
func TestDirectory_GetSize(t *testing.T) {
    root := NewDirectory("root")
    root.Add(NewFile("a.txt", 100))
    root.Add(NewFile("b.txt", 200))

    sub := NewDirectory("sub")
    sub.Add(NewFile("c.txt", 300))
    root.Add(sub)

    expected := int64(600)
    if got := root.GetSize(); got != expected {
        t.Errorf("expected %d, got %d", expected, got)
    }
}

func TestManager_TotalSalary(t *testing.T) {
    boss := NewManager("Boss", 100000)
    boss.Add(NewDeveloper("Dev1", 50000))
    boss.Add(NewDeveloper("Dev2", 60000))

    expected := 210000.0
    if got := GetTotalSalary(boss); got != expected {
        t.Errorf("expected %.0f, got %.0f", expected, got)
    }
}

func TestComposite_Uniform(t *testing.T) {
    // Les deux implementent Component
    var c1 Component = NewFile("file", 100)
    var c2 Component = NewDirectory("dir")

    // Meme interface
    _ = c1.GetSize()
    _ = c2.GetSize()
}
```

---

## Sources

- [Refactoring Guru - Composite](https://refactoring.guru/design-patterns/composite)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Go AST as Composite example](https://pkg.go.dev/go/ast)
