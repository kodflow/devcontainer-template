# Interpreter

> Definir une representation grammaticale pour un langage et un interpreteur pour evaluer les expressions.

---

## Principe

Le pattern Interpreter definit une grammaire pour un langage simple et utilise cette grammaire pour interpreter des expressions. Chaque regle de grammaire devient une classe.

```
┌─────────────────┐
│   Expression    │
│  Interpret(ctx) │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌───▼────────┐
│Terminal│ │NonTerminal │
│  Expr  │ │   Expr     │
└────────┘ │ (children) │
           └────────────┘
```

---

## Probleme resolu

- Evaluer des expressions dans un langage specifique
- Parser et executer des requetes, regles, ou DSL
- Definir une grammaire interpretable
- Expressions combinables recursivement

---

## Solution

```go
package main

import (
    "fmt"
    "strconv"
    "strings"
)

// Context contient les variables globales.
type Context struct {
    Variables map[string]int
}

func NewContext() *Context {
    return &Context{Variables: make(map[string]int)}
}

// Expression definit l'interface d'interpretation.
type Expression interface {
    Interpret(ctx *Context) int
}

// NumberExpression est une expression terminale.
type NumberExpression struct {
    value int
}

func NewNumberExpression(v int) *NumberExpression {
    return &NumberExpression{value: v}
}

func (n *NumberExpression) Interpret(ctx *Context) int {
    return n.value
}

// VariableExpression est une expression terminale.
type VariableExpression struct {
    name string
}

func NewVariableExpression(name string) *VariableExpression {
    return &VariableExpression{name: name}
}

func (v *VariableExpression) Interpret(ctx *Context) int {
    return ctx.Variables[v.name]
}

// AddExpression est une expression non-terminale.
type AddExpression struct {
    left, right Expression
}

func NewAddExpression(left, right Expression) *AddExpression {
    return &AddExpression{left: left, right: right}
}

func (a *AddExpression) Interpret(ctx *Context) int {
    return a.left.Interpret(ctx) + a.right.Interpret(ctx)
}

// SubtractExpression est une expression non-terminale.
type SubtractExpression struct {
    left, right Expression
}

func NewSubtractExpression(left, right Expression) *SubtractExpression {
    return &SubtractExpression{left: left, right: right}
}

func (s *SubtractExpression) Interpret(ctx *Context) int {
    return s.left.Interpret(ctx) - s.right.Interpret(ctx)
}

// Usage:
// ctx := NewContext()
// ctx.Variables["x"] = 10
// expr := NewAddExpression(NewVariableExpression("x"), NewNumberExpression(5))
// result := expr.Interpret(ctx) // 15
```

---

## Exemple complet

```go
package main

import (
    "fmt"
    "regexp"
    "strconv"
    "strings"
)

// BoolContext contient les faits connus.
type BoolContext struct {
    Facts map[string]bool
}

func NewBoolContext() *BoolContext {
    return &BoolContext{Facts: make(map[string]bool)}
}

// BoolExpression definit une expression booleenne.
type BoolExpression interface {
    Interpret(ctx *BoolContext) bool
    String() string
}

// TrueExpression est toujours vraie.
type TrueExpression struct{}

func (t *TrueExpression) Interpret(ctx *BoolContext) bool { return true }
func (t *TrueExpression) String() string                  { return "TRUE" }

// FalseExpression est toujours fausse.
type FalseExpression struct{}

func (f *FalseExpression) Interpret(ctx *BoolContext) bool { return false }
func (f *FalseExpression) String() string                  { return "FALSE" }

// FactExpression verifie un fait.
type FactExpression struct {
    name string
}

func NewFactExpression(name string) *FactExpression {
    return &FactExpression{name: name}
}

func (f *FactExpression) Interpret(ctx *BoolContext) bool {
    return ctx.Facts[f.name]
}

func (f *FactExpression) String() string {
    return f.name
}

// AndExpression est un AND logique.
type AndExpression struct {
    left, right BoolExpression
}

func NewAndExpression(left, right BoolExpression) *AndExpression {
    return &AndExpression{left: left, right: right}
}

func (a *AndExpression) Interpret(ctx *BoolContext) bool {
    return a.left.Interpret(ctx) && a.right.Interpret(ctx)
}

func (a *AndExpression) String() string {
    return fmt.Sprintf("(%s AND %s)", a.left.String(), a.right.String())
}

// OrExpression est un OR logique.
type OrExpression struct {
    left, right BoolExpression
}

func NewOrExpression(left, right BoolExpression) *OrExpression {
    return &OrExpression{left: left, right: right}
}

func (o *OrExpression) Interpret(ctx *BoolContext) bool {
    return o.left.Interpret(ctx) || o.right.Interpret(ctx)
}

func (o *OrExpression) String() string {
    return fmt.Sprintf("(%s OR %s)", o.left.String(), o.right.String())
}

// NotExpression est un NOT logique.
type NotExpression struct {
    expr BoolExpression
}

func NewNotExpression(expr BoolExpression) *NotExpression {
    return &NotExpression{expr: expr}
}

func (n *NotExpression) Interpret(ctx *BoolContext) bool {
    return !n.expr.Interpret(ctx)
}

func (n *NotExpression) String() string {
    return fmt.Sprintf("NOT %s", n.expr.String())
}

// RuleEngine applique des regles.
type RuleEngine struct {
    rules map[string]BoolExpression
}

func NewRuleEngine() *RuleEngine {
    return &RuleEngine{rules: make(map[string]BoolExpression)}
}

func (r *RuleEngine) AddRule(name string, expr BoolExpression) {
    r.rules[name] = expr
}

func (r *RuleEngine) Evaluate(name string, ctx *BoolContext) bool {
    if rule, ok := r.rules[name]; ok {
        return rule.Interpret(ctx)
    }
    return false
}

func (r *RuleEngine) EvaluateAll(ctx *BoolContext) map[string]bool {
    results := make(map[string]bool)
    for name, rule := range r.rules {
        results[name] = rule.Interpret(ctx)
    }
    return results
}

// Parser simple pour les expressions.
func ParseSimple(expr string) BoolExpression {
    expr = strings.TrimSpace(expr)

    // NOT
    if strings.HasPrefix(expr, "NOT ") {
        return NewNotExpression(ParseSimple(expr[4:]))
    }

    // AND
    if idx := strings.Index(expr, " AND "); idx > 0 {
        return NewAndExpression(
            ParseSimple(expr[:idx]),
            ParseSimple(expr[idx+5:]),
        )
    }

    // OR
    if idx := strings.Index(expr, " OR "); idx > 0 {
        return NewOrExpression(
            ParseSimple(expr[:idx]),
            ParseSimple(expr[idx+4:]),
        )
    }

    // TRUE/FALSE
    if expr == "TRUE" {
        return &TrueExpression{}
    }
    if expr == "FALSE" {
        return &FalseExpression{}
    }

    // Fait
    return NewFactExpression(expr)
}

func main() {
    // Contexte avec des faits
    ctx := NewBoolContext()
    ctx.Facts["is_admin"] = true
    ctx.Facts["is_logged_in"] = true
    ctx.Facts["has_permission"] = false
    ctx.Facts["is_owner"] = true

    // Construire des regles
    engine := NewRuleEngine()

    // Regle: peut editer si admin OU (connecte ET proprietaire)
    canEdit := NewOrExpression(
        NewFactExpression("is_admin"),
        NewAndExpression(
            NewFactExpression("is_logged_in"),
            NewFactExpression("is_owner"),
        ),
    )
    engine.AddRule("can_edit", canEdit)

    // Regle: peut supprimer si admin ET a permission
    canDelete := NewAndExpression(
        NewFactExpression("is_admin"),
        NewFactExpression("has_permission"),
    )
    engine.AddRule("can_delete", canDelete)

    // Regle: lecture publique
    canRead := &TrueExpression{}
    engine.AddRule("can_read", canRead)

    // Evaluer les regles
    fmt.Println("Rule Evaluation:")
    results := engine.EvaluateAll(ctx)
    for name, result := range results {
        fmt.Printf("  %s: %v\n", name, result)
    }

    // Parser une expression simple
    fmt.Println("\nParsed Expression:")
    parsed := ParseSimple("is_admin AND is_logged_in")
    fmt.Printf("  %s = %v\n", parsed.String(), parsed.Interpret(ctx))

    // Output:
    // Rule Evaluation:
    //   can_edit: true
    //   can_delete: false
    //   can_read: true
    // Parsed Expression:
    //   (is_admin AND is_logged_in) = true
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Tree Interpreter | Arbre d'expressions | Langages simples |
| Stack-Based | Machine a pile | Bytecode |
| Visitor-Based | Visiteur sur AST | Langages complexes |

---

## Quand utiliser

- Grammaire simple et bien definie
- Expressions recursivement combinables
- DSL (Domain Specific Language)
- Regles metier configurables

## Quand NE PAS utiliser

- Grammaire complexe (utiliser un parser generator)
- Performance critique
- Langage qui evolue frequemment

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Facile a etendre | Grammaires complexes difficiles |
| Grammaire explicite | Performance limitee |
| Expressions combinables | Beaucoup de classes |
| | Maintenance si grammaire change |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Composite | Structure arborescente des expressions |
| Visitor | Alternative pour interpreter |
| Flyweight | Partager les expressions terminales |
| Iterator | Parcourir les tokens |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| regexp | Expressions regulieres |
| text/template | Templates Go |
| go/parser | Parser Go |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Grammaire trop complexe | Maintenance difficile | Parser generator |
| Recursion infinie | Stack overflow | Validation de la grammaire |
| Contexte mutable partage | Race conditions | Contexte immutable |

---

## Tests

```go
func TestNumberExpression(t *testing.T) {
    expr := NewNumberExpression(42)
    ctx := NewContext()

    if expr.Interpret(ctx) != 42 {
        t.Error("expected 42")
    }
}

func TestVariableExpression(t *testing.T) {
    ctx := NewContext()
    ctx.Variables["x"] = 10

    expr := NewVariableExpression("x")
    if expr.Interpret(ctx) != 10 {
        t.Error("expected 10")
    }
}

func TestAddExpression(t *testing.T) {
    ctx := NewContext()
    expr := NewAddExpression(
        NewNumberExpression(5),
        NewNumberExpression(3),
    )

    if expr.Interpret(ctx) != 8 {
        t.Error("expected 8")
    }
}

func TestBoolAndExpression(t *testing.T) {
    ctx := NewBoolContext()
    ctx.Facts["a"] = true
    ctx.Facts["b"] = false

    expr := NewAndExpression(
        NewFactExpression("a"),
        NewFactExpression("b"),
    )

    if expr.Interpret(ctx) != false {
        t.Error("expected false (true AND false)")
    }
}

func TestBoolOrExpression(t *testing.T) {
    ctx := NewBoolContext()
    ctx.Facts["a"] = true
    ctx.Facts["b"] = false

    expr := NewOrExpression(
        NewFactExpression("a"),
        NewFactExpression("b"),
    )

    if expr.Interpret(ctx) != true {
        t.Error("expected true (true OR false)")
    }
}

func TestRuleEngine(t *testing.T) {
    ctx := NewBoolContext()
    ctx.Facts["is_admin"] = true

    engine := NewRuleEngine()
    engine.AddRule("test", NewFactExpression("is_admin"))

    if !engine.Evaluate("test", ctx) {
        t.Error("expected rule to pass")
    }
}
```

---

## Sources

- [Refactoring Guru - Interpreter](https://refactoring.guru/design-patterns/interpreter)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Crafting Interpreters](https://craftinginterpreters.com/)
