# Template Method

> Definir le squelette d'un algorithme dans une methode, en deleguant certaines etapes aux sous-classes.

---

## Principe

Le pattern Template Method definit la structure d'un algorithme dans une classe de base, tout en permettant aux sous-classes de redefinir certaines etapes sans changer la structure globale.

```
┌─────────────────────┐
│  AbstractClass      │
│  ──────────────     │
│  templateMethod()   │ ─► appelle step1(), step2(), step3()
│  step1()            │
│  step2() (abstract) │
│  step3()            │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────┐
│ClassA   │ │ClassB   │
│step2()  │ │step2()  │
└─────────┘ └─────────┘
```

---

## Probleme resolu

- Code duplique dans plusieurs classes avec variations mineures
- Algorithme avec etapes fixes et etapes variables
- Inverser le controle (Hollywood Principle)
- Eviter la duplication tout en permettant la personnalisation

---

## Solution

```go
package main

import "fmt"

// DataMiner definit le template.
type DataMiner interface {
    Mine(path string)
    // Methodes a implementer
    OpenFile(path string)
    ExtractData()
    ParseData()
    AnalyzeData()
    SendReport()
    CloseFile()
}

// BaseDataMiner fournit l'implementation du template.
type BaseDataMiner struct {
    DataMiner
}

// Mine est la methode template.
func (b *BaseDataMiner) Mine(path string) {
    b.OpenFile(path)
    b.ExtractData()
    b.ParseData()
    b.AnalyzeData()
    b.SendReport()
    b.CloseFile()
}

// Implementations par defaut (hooks)
func (b *BaseDataMiner) AnalyzeData() {
    fmt.Println("Default analysis...")
}

func (b *BaseDataMiner) SendReport() {
    fmt.Println("Sending report via email...")
}

// PDFDataMiner implemente les etapes specifiques.
type PDFDataMiner struct {
    BaseDataMiner
}

func NewPDFDataMiner() *PDFDataMiner {
    m := &PDFDataMiner{}
    m.DataMiner = m
    return m
}

func (p *PDFDataMiner) OpenFile(path string) {
    fmt.Printf("Opening PDF: %s\n", path)
}

func (p *PDFDataMiner) ExtractData() {
    fmt.Println("Extracting text from PDF...")
}

func (p *PDFDataMiner) ParseData() {
    fmt.Println("Parsing PDF structure...")
}

func (p *PDFDataMiner) CloseFile() {
    fmt.Println("Closing PDF")
}
```

---

## Exemple complet

```go
package main

import (
    "fmt"
    "strings"
)

// GameAI definit le template pour l'IA du jeu.
type GameAI interface {
    Turn()
    // Etapes abstraites
    CollectResources()
    BuildStructures()
    BuildUnits()
    Attack()
    // Hook
    CanAttack() bool
}

// BaseGameAI fournit le template.
type BaseGameAI struct {
    name string
    GameAI
}

func (b *BaseGameAI) Turn() {
    fmt.Printf("\n=== %s's Turn ===\n", b.name)
    b.CollectResources()
    b.BuildStructures()
    b.BuildUnits()
    if b.CanAttack() {
        b.Attack()
    } else {
        fmt.Println("Not ready to attack yet")
    }
}

// Hook par defaut
func (b *BaseGameAI) CanAttack() bool {
    return true
}

// OrcsAI implemente une strategie agressive.
type OrcsAI struct {
    BaseGameAI
    warriors int
}

func NewOrcsAI() *OrcsAI {
    ai := &OrcsAI{warriors: 0}
    ai.name = "Orcs"
    ai.GameAI = ai
    return ai
}

func (o *OrcsAI) CollectResources() {
    fmt.Println("Orcs: Pillaging nearby villages for gold")
}

func (o *OrcsAI) BuildStructures() {
    fmt.Println("Orcs: Building war camps")
}

func (o *OrcsAI) BuildUnits() {
    o.warriors += 5
    fmt.Printf("Orcs: Training warriors (total: %d)\n", o.warriors)
}

func (o *OrcsAI) Attack() {
    fmt.Println("Orcs: WAAAGH! Charging with all warriors!")
}

func (o *OrcsAI) CanAttack() bool {
    return o.warriors >= 10
}

// HumansAI implemente une strategie defensive.
type HumansAI struct {
    BaseGameAI
    knights int
    walls   int
}

func NewHumansAI() *HumansAI {
    ai := &HumansAI{knights: 0, walls: 0}
    ai.name = "Humans"
    ai.GameAI = ai
    return ai
}

func (h *HumansAI) CollectResources() {
    fmt.Println("Humans: Farming and mining")
}

func (h *HumansAI) BuildStructures() {
    h.walls++
    fmt.Printf("Humans: Building walls (level: %d)\n", h.walls)
}

func (h *HumansAI) BuildUnits() {
    h.knights += 2
    fmt.Printf("Humans: Training knights (total: %d)\n", h.knights)
}

func (h *HumansAI) Attack() {
    fmt.Println("Humans: Launching organized cavalry charge!")
}

func (h *HumansAI) CanAttack() bool {
    return h.walls >= 2 && h.knights >= 4
}

// DocumentProcessor avec hooks.
type DocumentProcessor interface {
    Process(content string) string
    // Template steps
    PreProcess(content string) string
    MainProcess(content string) string
    PostProcess(content string) string
    // Hooks
    ShouldLog() bool
}

type BaseDocumentProcessor struct {
    DocumentProcessor
}

func (b *BaseDocumentProcessor) Process(content string) string {
    if b.ShouldLog() {
        fmt.Println("Processing document...")
    }
    result := b.PreProcess(content)
    result = b.MainProcess(result)
    result = b.PostProcess(result)
    if b.ShouldLog() {
        fmt.Println("Done!")
    }
    return result
}

// Hook par defaut
func (b *BaseDocumentProcessor) ShouldLog() bool {
    return false
}

func (b *BaseDocumentProcessor) PreProcess(content string) string {
    return strings.TrimSpace(content)
}

func (b *BaseDocumentProcessor) PostProcess(content string) string {
    return content
}

// MarkdownProcessor implemente le traitement Markdown.
type MarkdownProcessor struct {
    BaseDocumentProcessor
    verbose bool
}

func NewMarkdownProcessor(verbose bool) *MarkdownProcessor {
    p := &MarkdownProcessor{verbose: verbose}
    p.DocumentProcessor = p
    return p
}

func (m *MarkdownProcessor) MainProcess(content string) string {
    // Simuler la conversion Markdown -> HTML
    result := strings.ReplaceAll(content, "# ", "<h1>")
    result = strings.ReplaceAll(result, "\n", "</h1>\n")
    return result
}

func (m *MarkdownProcessor) ShouldLog() bool {
    return m.verbose
}

func main() {
    // Exemple 1: Game AI
    orcs := NewOrcsAI()
    humans := NewHumansAI()

    // Simuler plusieurs tours
    for i := 0; i < 3; i++ {
        orcs.Turn()
        humans.Turn()
    }

    // Exemple 2: Document Processor
    fmt.Println("\n=== Document Processing ===")
    processor := NewMarkdownProcessor(true)
    result := processor.Process("# Hello World\n# Second Title")
    fmt.Println("Result:", result)

    // Output shows template method controlling the flow
    // while subclasses customize specific steps
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Abstract Steps | Etapes obligatoires | Comportement requis |
| Default Steps | Implementations par defaut | Comportement optionnel |
| Hooks | Points d'extension | Personnalisation fine |

---

## Quand utiliser

- Algorithme avec structure fixe et etapes variables
- Eviter la duplication de code
- Points d'extension controles pour sous-classes
- Inversion de controle ("Don't call us, we'll call you")

## Quand NE PAS utiliser

- Algorithme entierement different par classe
- Une seule implementation prevue
- Trop de variations rendent le template complexe

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Elimine la duplication | Heritage requis (moins flexible) |
| Points d'extension clairs | Peut violer Liskov si mal concu |
| Inversion de controle | Maintenance si template change |
| | Nombre limite d'etapes par template |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Strategy | Strategy utilise composition, Template heritage |
| Factory Method | Souvent une etape du Template |
| Hook | Extension du Template Method |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| http.Handler | ServeHTTP comme template |
| sort.Interface | Len, Less, Swap comme etapes |
| testing.T | Run comme template |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Too many steps | Complexite | Limiter a 5-7 etapes |
| Forced override | Rigidite | Utiliser des hooks |
| Deep hierarchy | Fragilite | Preferer composition |

---

## Tests

```go
func TestOrcsAI_AttackWhenReady(t *testing.T) {
    orcs := NewOrcsAI()

    // Pas assez de guerriers
    if orcs.CanAttack() {
        t.Error("orcs should not attack with 0 warriors")
    }

    // Accumuler des guerriers
    for i := 0; i < 2; i++ {
        orcs.Turn()
    }

    // Maintenant prets
    if !orcs.CanAttack() {
        t.Error("orcs should be ready to attack")
    }
}

func TestHumansAI_DefensiveStrategy(t *testing.T) {
    humans := NewHumansAI()

    // Premiere phase: construction
    humans.Turn()

    if humans.walls != 1 {
        t.Errorf("expected 1 wall, got %d", humans.walls)
    }
    if humans.knights != 2 {
        t.Errorf("expected 2 knights, got %d", humans.knights)
    }
}

func TestMarkdownProcessor(t *testing.T) {
    processor := NewMarkdownProcessor(false)
    result := processor.Process("# Test")

    if !strings.Contains(result, "<h1>") {
        t.Error("expected HTML h1 tag")
    }
}
```

---

## Sources

- [Refactoring Guru - Template Method](https://refactoring.guru/design-patterns/template-method)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Hollywood Principle](https://en.wikipedia.org/wiki/Hollywood_principle)
