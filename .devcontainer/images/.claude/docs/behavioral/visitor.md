# Visitor

> Separer un algorithme des objets sur lesquels il opere, permettant d'ajouter de nouvelles operations sans modifier les classes.

---

## Principe

Le pattern Visitor permet de definir de nouvelles operations sur une structure d'objets sans modifier les classes de ces objets. Le visiteur "visite" chaque element et effectue son operation.

```
┌────────────┐      ┌────────────┐
│  Element   │◄─────│  Visitor   │
│ Accept(v)  │      │ VisitA()   │
└─────┬──────┘      │ VisitB()   │
      │             └─────┬──────┘
┌─────┴─────┐             │
│           │       ┌─────┴─────┐
▼           ▼       ▼           ▼
ElementA  ElementB  VisitorX  VisitorY
```

---

## Probleme resolu

- Ajouter des operations a une hierarchie de classes sans les modifier
- Separer les algorithmes de la structure de donnees
- Regrouper les operations liees dans une classe
- Eviter de polluer les classes avec des operations non essentielles

---

## Solution

```go
package main

import "fmt"

// Visitor definit les operations pour chaque type d'element.
type Visitor interface {
	VisitCircle(c *Circle)
	VisitRectangle(r *Rectangle)
	VisitTriangle(t *Triangle)
}

// Shape definit l'interface acceptant un visiteur.
type Shape interface {
	Accept(v Visitor)
}

// Circle est un element concret.
type Circle struct {
	Radius float64
}

func (c *Circle) Accept(v Visitor) {
	v.VisitCircle(c)
}

// Rectangle est un element concret.
type Rectangle struct {
	Width, Height float64
}

func (r *Rectangle) Accept(v Visitor) {
	v.VisitRectangle(r)
}

// Triangle est un element concret.
type Triangle struct {
	Base, Height float64
}

func (t *Triangle) Accept(v Visitor) {
	v.VisitTriangle(t)
}

// AreaCalculator est un visiteur concret.
type AreaCalculator struct {
	TotalArea float64
}

func (a *AreaCalculator) VisitCircle(c *Circle) {
	area := 3.14159 * c.Radius * c.Radius
	a.TotalArea += area
	fmt.Printf("Circle area: %.2f\n", area)
}

func (a *AreaCalculator) VisitRectangle(r *Rectangle) {
	area := r.Width * r.Height
	a.TotalArea += area
	fmt.Printf("Rectangle area: %.2f\n", area)
}

func (a *AreaCalculator) VisitTriangle(t *Triangle) {
	area := 0.5 * t.Base * t.Height
	a.TotalArea += area
	fmt.Printf("Triangle area: %.2f\n", area)
}

// Usage:
// shapes := []Shape{&Circle{5}, &Rectangle{4, 3}, &Triangle{6, 4}}
// calc := &AreaCalculator{}
// for _, s := range shapes { s.Accept(calc) }
```

---

## Exemple complet

```go
package main

import (
	"fmt"
	"strings"
)

// Node represente un noeud d'AST.
type Node interface {
	Accept(v NodeVisitor)
}

// NodeVisitor definit les operations sur l'AST.
type NodeVisitor interface {
	VisitNumber(n *NumberNode)
	VisitBinaryOp(b *BinaryOpNode)
	VisitVariable(v *VariableNode)
	VisitFunction(f *FunctionNode)
}

// NumberNode represente un nombre.
type NumberNode struct {
	Value float64
}

func (n *NumberNode) Accept(v NodeVisitor) {
	v.VisitNumber(n)
}

// BinaryOpNode represente une operation binaire.
type BinaryOpNode struct {
	Left, Right Node
	Operator    string
}

func (b *BinaryOpNode) Accept(v NodeVisitor) {
	v.VisitBinaryOp(b)
}

// VariableNode represente une variable.
type VariableNode struct {
	Name string
}

func (vn *VariableNode) Accept(v NodeVisitor) {
	v.VisitVariable(vn)
}

// FunctionNode represente un appel de fonction.
type FunctionNode struct {
	Name string
	Args []Node
}

func (f *FunctionNode) Accept(v NodeVisitor) {
	v.VisitFunction(f)
}

// PrintVisitor affiche l'AST.
type PrintVisitor struct {
	indent int
	output strings.Builder
}

func (p *PrintVisitor) VisitNumber(n *NumberNode) {
	p.write(fmt.Sprintf("Number(%.2f)", n.Value))
}

func (p *PrintVisitor) VisitBinaryOp(b *BinaryOpNode) {
	p.write(fmt.Sprintf("BinaryOp(%s)", b.Operator))
	p.indent++
	p.write("Left:")
	p.indent++
	b.Left.Accept(p)
	p.indent--
	p.write("Right:")
	p.indent++
	b.Right.Accept(p)
	p.indent -= 2
}

func (p *PrintVisitor) VisitVariable(v *VariableNode) {
	p.write(fmt.Sprintf("Variable(%s)", v.Name))
}

func (p *PrintVisitor) VisitFunction(f *FunctionNode) {
	p.write(fmt.Sprintf("Function(%s)", f.Name))
	p.indent++
	for i, arg := range f.Args {
		p.write(fmt.Sprintf("Arg[%d]:", i))
		p.indent++
		arg.Accept(p)
		p.indent--
	}
	p.indent--
}

func (p *PrintVisitor) write(s string) {
	p.output.WriteString(strings.Repeat("  ", p.indent))
	p.output.WriteString(s)
	p.output.WriteString("\n")
}

func (p *PrintVisitor) String() string {
	return p.output.String()
}

// EvalVisitor evalue l'expression.
type EvalVisitor struct {
	Variables map[string]float64
	stack     []float64
}

func NewEvalVisitor(vars map[string]float64) *EvalVisitor {
	return &EvalVisitor{
		Variables: vars,
		stack:     make([]float64, 0),
	}
}

func (e *EvalVisitor) push(v float64) {
	e.stack = append(e.stack, v)
}

func (e *EvalVisitor) pop() float64 {
	n := len(e.stack) - 1
	v := e.stack[n]
	e.stack = e.stack[:n]
	return v
}

func (e *EvalVisitor) Result() float64 {
	if len(e.stack) > 0 {
		return e.stack[len(e.stack)-1]
	}
	return 0
}

func (e *EvalVisitor) VisitNumber(n *NumberNode) {
	e.push(n.Value)
}

func (e *EvalVisitor) VisitBinaryOp(b *BinaryOpNode) {
	b.Left.Accept(e)
	b.Right.Accept(e)
	right := e.pop()
	left := e.pop()

	var result float64
	switch b.Operator {
	case "+":
		result = left + right
	case "-":
		result = left - right
	case "*":
		result = left * right
	case "/":
		result = left / right
	}
	e.push(result)
}

func (e *EvalVisitor) VisitVariable(v *VariableNode) {
	if val, ok := e.Variables[v.Name]; ok {
		e.push(val)
	} else {
		e.push(0)
	}
}

func (e *EvalVisitor) VisitFunction(f *FunctionNode) {
	// Evaluer les arguments
	args := make([]float64, len(f.Args))
	for i, arg := range f.Args {
		arg.Accept(e)
		args[i] = e.pop()
	}

	// Fonctions built-in
	var result float64
	switch f.Name {
	case "max":
		result = args[0]
		for _, a := range args[1:] {
			if a > result {
				result = a
			}
		}
	case "min":
		result = args[0]
		for _, a := range args[1:] {
			if a < result {
				result = a
			}
		}
	case "sum":
		for _, a := range args {
			result += a
		}
	}
	e.push(result)
}

func main() {
	// Construire l'AST: max(x, y * 2) + 10
	ast := &BinaryOpNode{
		Operator: "+",
		Left: &FunctionNode{
			Name: "max",
			Args: []Node{
				&VariableNode{Name: "x"},
				&BinaryOpNode{
					Operator: "*",
					Left:     &VariableNode{Name: "y"},
					Right:    &NumberNode{Value: 2},
				},
			},
		},
		Right: &NumberNode{Value: 10},
	}

	// Visiteur 1: Afficher
	printer := &PrintVisitor{}
	ast.Accept(printer)
	fmt.Println("AST Structure:")
	fmt.Println(printer)

	// Visiteur 2: Evaluer
	vars := map[string]float64{"x": 5, "y": 3}
	eval := NewEvalVisitor(vars)
	ast.Accept(eval)
	fmt.Printf("Result (x=5, y=3): %.2f\n", eval.Result())
	// max(5, 3*2) + 10 = max(5, 6) + 10 = 6 + 10 = 16
}
```

---

## Variantes

| Variante | Description | Cas d'usage |
|----------|-------------|-------------|
| Classic Visitor | Double dispatch | Structures stables |
| Acyclic Visitor | Evite dependances cycliques | Hierarchies complexes |
| Hierarchical Visitor | Visite avec contexte parent | Arbres |

---

## Quand utiliser

- Operations multiples sur une structure d'objets
- Ajouter des operations sans modifier les classes
- Regrouper des operations liees
- Structure stable, operations variables

## Quand NE PAS utiliser

- Hierarchie de classes qui change souvent
- Peu d'operations differentes
- Double dispatch non necessaire

---

## Avantages / Inconvenients

| Avantages | Inconvenients |
|-----------|---------------|
| Open/Closed pour operations | Difficile d'ajouter de nouveaux elements |
| Single Responsibility | Peut violer l'encapsulation |
| Accumulation d'etat facile | Double dispatch complexe |
| Operations regroupees | |

---

## Patterns lies

| Pattern | Relation |
|---------|----------|
| Composite | Visitor peut parcourir les composites |
| Iterator | Alternative pour parcourir |
| Interpreter | Visitor pour evaluer l'AST |
| Command | Visiteur comme commande sur elements |

---

## Implementation dans les frameworks

| Framework/Lib | Implementation |
|---------------|----------------|
| go/ast | ast.Visitor, ast.Walk |
| go/types | types.Object visitors |
| html/template | Parcours de l'arbre |

---

## Anti-patterns a eviter

| Anti-pattern | Probleme | Solution |
|--------------|----------|----------|
| Visitor monolithique | Trop de responsabilites | Decomposer en visiteurs specialises |
| Oublier Accept | Elements non visites | Verifier tous les types |
| Etat mutable partage | Race conditions | Visiteurs thread-local |

---

## Tests

```go
func TestAreaCalculator(t *testing.T) {
	shapes := []Shape{
		&Circle{Radius: 2},
		&Rectangle{Width: 3, Height: 4},
	}

	calc := &AreaCalculator{}
	for _, s := range shapes {
		s.Accept(calc)
	}

	// Circle: 3.14159 * 4 = 12.57
	// Rectangle: 3 * 4 = 12
	// Total ~= 24.57
	expected := 24.57
	if calc.TotalArea < 24 || calc.TotalArea > 25 {
		t.Errorf("expected ~%.2f, got %.2f", expected, calc.TotalArea)
	}
}

func TestEvalVisitor(t *testing.T) {
	// Expression: x + y
	ast := &BinaryOpNode{
		Operator: "+",
		Left:     &VariableNode{Name: "x"},
		Right:    &VariableNode{Name: "y"},
	}

	eval := NewEvalVisitor(map[string]float64{"x": 10, "y": 5})
	ast.Accept(eval)

	if eval.Result() != 15 {
		t.Errorf("expected 15, got %.2f", eval.Result())
	}
}

func TestPrintVisitor(t *testing.T) {
	ast := &NumberNode{Value: 42}
	printer := &PrintVisitor{}
	ast.Accept(printer)

	if !strings.Contains(printer.String(), "42") {
		t.Error("expected number in output")
	}
}
```

---

## Sources

- [Refactoring Guru - Visitor](https://refactoring.guru/design-patterns/visitor)
- [Gang of Four - Design Patterns](https://en.wikipedia.org/wiki/Design_Patterns)
- [Go AST Visitor](https://pkg.go.dev/go/ast#Visitor)
