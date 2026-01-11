# Iterator

> Acceder aux elements d'une collection sans exposer sa structure interne.

---

## Principe

Le pattern Iterator permet de parcourir une collection sans connaitre sa
structure sous-jacente (liste, arbre, graphe).
Go utilise nativement ce pattern avec `range` et les channels.

```text
┌────────────────┐      ┌────────────────┐
│   Collection   │─────▶│    Iterator    │
│  (CreateIter)  │      │ (Next, HasNext)│
└────────────────┘      └────────────────┘
         │                      │
         ▼                      ▼
┌────────────────┐      ┌────────────────┐
│ConcreteCollect │      │ ConcreteIter   │
└────────────────┘      └────────────────┘
```

---

## Probleme resolu

- Parcourir une collection sans connaitre son implementation
- Supporter plusieurs parcours simultanes
- Fournir une interface uniforme pour differentes structures
- Separer la logique de parcours de la collection

---

## Solution

```go
package main

import "fmt"

// Iterator definit l'interface de parcours.
type Iterator[T any] interface {
    HasNext() bool
    Next() T
}

// Collection definit l'interface de collection.
type Collection[T any] interface {
    CreateIterator() Iterator[T]
}

// SliceCollection est une collection basee sur un slice.
type SliceCollection[T any] struct {
    items []T
}

func NewSliceCollection[T any](items ...T) *SliceCollection[T] {
    return &SliceCollection[T]{items: items}
}

func (c *SliceCollection[T]) CreateIterator() Iterator[T] {
    return &SliceIterator[T]{collection: c, index: 0}
}

// SliceIterator parcourt un slice.
type SliceIterator[T any] struct {
    collection *SliceCollection[T]
    index      int
}

func (i *SliceIterator[T]) HasNext() bool {
    return i.index < len(i.collection.items)
}

func (i *SliceIterator[T]) Next() T {
    if i.HasNext() {
        item := i.collection.items[i.index]
        i.index++
        return item
    }
    var zero T
    return zero
}

// Usage:
// coll := NewSliceCollection(1, 2, 3, 4, 5)
// iter := coll.CreateIterator()
// for iter.HasNext() {
//     fmt.Println(iter.Next())
// }
```

---

## Exemple complet

```go
package main

import (
    "fmt"
    "iter"
)

// Book represente un livre.
type Book struct {
    Title  string
    Author string
    Year   int
}

// Library est une collection de livres.
type Library struct {
    books []*Book
}

func NewLibrary() *Library {
    return &Library{books: make([]*Book, 0)}
}

func (l *Library) Add(book *Book) {
    l.books = append(l.books, book)
}

// All retourne un iterateur Go 1.23+ (iter.Seq).
func (l *Library) All() iter.Seq[*Book] {
    return func(yield func(*Book) bool) {
        for _, book := range l.books {
            if !yield(book) {
                return
            }
        }
    }
}

// ByAuthor retourne un iterateur filtre par auteur.
func (l *Library) ByAuthor(author string) iter.Seq[*Book] {
    return func(yield func(*Book) bool) {
        for _, book := range l.books {
            if book.Author == author {
                if !yield(book) {
                    return
                }
            }
        }
    }
}

// ByYearRange retourne les livres dans une plage d'annees.
func (l *Library) ByYearRange(from, to int) iter.Seq[*Book] {
    return func(yield func(*Book) bool) {
        for _, book := range l.books {
            if book.Year >= from && book.Year <= to {
                if !yield(book) {
                    return
                }
            }
        }
    }
}

// Channel-based iterator (pre Go 1.23 approach)
func (l *Library) Chan() <-chan *Book {
    ch := make(chan *Book)
    go func() {
        defer close(ch)
        for _, book := range l.books {
            ch <- book
        }
    }()
    return ch
}

func main() {
    library := NewLibrary()
    library.Add(&Book{Title: "1984", Author: "George Orwell", Year: 1949})
    library.Add(&Book{Title: "Brave New World", Author: "Aldous Huxley", Year: 1932})
    library.Add(&Book{Title: "Animal Farm", Author: "George Orwell", Year: 1945})
    library.Add(&Book{Title: "Fahrenheit 451", Author: "Ray Bradbury", Year: 1953})

    // Parcourir tous les livres (Go 1.23+)
    fmt.Println("All books:")
    for book := range library.All() {
        fmt.Printf("  - %s (%d)\n", book.Title, book.Year)
    }

    // Filtrer par auteur
    fmt.Println("\nBooks by George Orwell:")
    for book := range library.ByAuthor("George Orwell") {
        fmt.Printf("  - %s (%d)\n", book.Title, book.Year)
    }

    // Filtrer par annee
    fmt.Println("\nBooks from 1940-1950:")
    for book := range library.ByYearRange(1940, 1950) {
        fmt.Printf("  - %s (%d)\n", book.Title, book.Year)
    }

    // Channel-based (pre Go 1.23)
    fmt.Println("\nUsing channel iterator:")
    for book := range library.Chan() {
        fmt.Printf("  - %s\n", book.Title)
    }
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Forward Iterator | Parcours vers l'avant | Cas standard |
| Reverse Iterator | Parcours inverse | Historique, undo |
| Filter Iterator | Filtre les elements | Requetes complexes |
| Transform Iterator | Transforme en parcourant | Map/Select |

---

## Quand utiliser

- Parcourir une collection sans exposer sa structure
- Supporter plusieurs parcours simultanes
- Fournir differentes strategies de parcours
- Decoupler les algorithmes des collections

## Quand NE PAS utiliser

- Collections simples (utiliser range directement)
- Un seul type de parcours necessaire
- Performance critique (overhead d'abstraction)

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Single Responsibility | Overhead pour collections simples |
| Open/Closed Principle | Complexite ajoutee |
| Parcours paralleles | Go a deja range et channels |
| Iterateurs lazy | |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Composite | Iterator peut parcourir les composites |
| Factory Method | Creer les iterateurs |
| Memento | L'iterateur peut sauvegarder sa position |
| Visitor | Alternative: Visitor itere, Iterator parcourt |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| iter (Go 1.23+) | iter.Seq, iter.Seq2 |
| channels | Iterateurs concurrent-safe |
| bufio.Scanner | Iterator sur lignes/tokens |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Iterator mutable | Etat partage | Creer nouvel iterateur |
| Oublier close | Resource leak (channels) | defer close() |
| Modification pendant iteration | Comportement indefini | Copie ou lock |

---

## Tests

```go
func TestSliceIterator(t *testing.T) {
    coll := NewSliceCollection(1, 2, 3)
    iter := coll.CreateIterator()

    var result []int
    for iter.HasNext() {
        result = append(result, iter.Next())
    }

    expected := []int{1, 2, 3}
    if !reflect.DeepEqual(result, expected) {
        t.Errorf("expected %v, got %v", expected, result)
    }
}

func TestLibrary_ByAuthor(t *testing.T) {
    library := NewLibrary()
    library.Add(&Book{Title: "Book1", Author: "A", Year: 2000})
    library.Add(&Book{Title: "Book2", Author: "B", Year: 2001})
    library.Add(&Book{Title: "Book3", Author: "A", Year: 2002})

    var count int
    for range library.ByAuthor("A") {
        count++
    }

    if count != 2 {
        t.Errorf("expected 2 books by A, got %d", count)
    }
}

func TestIterator_Empty(t *testing.T) {
    coll := NewSliceCollection[int]()
    iter := coll.CreateIterator()

    if iter.HasNext() {
        t.Error("expected empty iterator")
    }
}
```

---

## Sources

- [Refactoring Guru - Iterator](https://refactoring.guru/design-patterns/iterator)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Go 1.23 iter package](https://pkg.go.dev/iter)
