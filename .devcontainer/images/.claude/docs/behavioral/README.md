# Behavioral Patterns (GoF)

Patterns de communication entre objets.

## Fichiers detailles

| Pattern | Fichier | Description |
|---------|---------|-------------|
| Chain of Responsibility | [chain-of-responsibility.md](chain-of-responsibility.md) | Middleware pattern |
| Command | [command.md](command.md) | Undo/Redo, transactions |
| Observer | [observer.md](observer.md) | Event Emitter moderne |
| State | [state.md](state.md) | State machine pattern |
| Strategy | [strategy.md](strategy.md) | Algorithmes interchangeables |

## Les 11 Patterns

### 1. Chain of Responsibility

> Chaine de handlers qui passent la requete.

Voir fichier detaille: [chain-of-responsibility.md](chain-of-responsibility.md)

```go
const chain = new AuthHandler();
chain.setNext(new ValidationHandler()).setNext(new BusinessHandler());
chain.handle(request);
```

**Quand :** Middleware, validations, filtres.

---

### 2. Command

> Encapsuler une requete comme un objet.

Voir fichier detaille: [command.md](command.md)

```go
interface Command {
  execute(): void;
  undo(): void;
}

class CommandInvoker {
  private history: Command[] = [];

  execute(command: Command) {
    command.execute();
    this.history.push(command);
  }

  undo() {
    this.history.pop()?.undo();
  }
}
```

**Quand :** Undo/redo, queues, transactions.

---

### 3. Iterator

> Parcourir sans exposer la structure interne.

```go
interface Iterator<T> {
  next(): T | null;
  hasNext(): boolean;
}

class TreeIterator<T> implements Iterator<T> {
  private stack: TreeNode<T>[] = [];

  constructor(root: TreeNode<T>) {
    this.stack.push(root);
  }

  next(): T | null {
    if (!this.hasNext()) return null;
    const node = this.stack.pop()!;
    if (node.right) this.stack.push(node.right);
    if (node.left) this.stack.push(node.left);
    return node.value;
  }
}
```

**Quand :** Collections custom, lazy loading.

---

### 4. Mediator

> Reduire les dependances directes entre composants.

```go
interface Mediator {
  notify(sender: Component, event: string): void;
}

class DialogMediator implements Mediator {
  notify(sender: Component, event: string) {
    if (sender === this.submitBtn && event === 'click') {
      if (this.form.validate()) this.form.submit();
    }
  }
}
```

**Quand :** UI complexes, systemes avec beaucoup d'interactions.

---

### 5. Memento

> Sauvegarder et restaurer l'etat.

```go
class Editor {
  save(): EditorMemento {
    return new EditorMemento(this.content);
  }

  restore(memento: EditorMemento) {
    this.content = memento.getState();
  }
}
```

**Quand :** Undo, snapshots, checkpoints.

---

### 6. Observer

> Notification de changements.

Voir fichier detaille: [observer.md](observer.md)

```go
class TypedEventEmitter<Events extends EventMap> {
  on<K extends keyof Events>(event: K, callback: (data: Events[K]) => void) {
    // ...
  }

  emit<K extends keyof Events>(event: K, data: Events[K]) {
    // ...
  }
}
```

**Quand :** Events, reactive programming, UI updates.

---

### 7. State

> Comportement qui change selon l'etat.

Voir fichier detaille: [state.md](state.md)

```go
class Order {
  private state: OrderState;

  setState(state: OrderState) { this.state = state; }
  confirm() { this.state.confirm(this); }
  ship() { this.state.ship(this); }
}
```

**Quand :** State machines, workflows.

---

### 8. Strategy

> Algorithmes interchangeables.

Voir fichier detaille: [strategy.md](strategy.md)

```go
class PaymentProcessor {
  constructor(private strategy: PaymentStrategy) {}

  setStrategy(strategy: PaymentStrategy) {
    this.strategy = strategy;
  }

  async checkout(amount: number) {
    return this.strategy.pay(amount);
  }
}
```

**Quand :** Plusieurs algorithmes, selection runtime.

---

### 9. Template Method

> Squelette d'algorithme, details dans sous-classes.

```go
abstract class DataMiner {
  mine(path: string) {
    const data = this.openFile(path);
    const parsed = this.parse(data);
    const analyzed = this.analyze(parsed);
    this.report(analyzed);
  }

  abstract openFile(path: string): string;
  abstract parse(data: string): object;
  analyze(data: object) { return data; }
}
```

**Quand :** Algorithme commun, etapes variables.

---

### 10. Visitor

> Operations sur une structure d'objets.

```go
interface Visitor {
  visitCircle(c: Circle): void;
  visitRectangle(r: Rectangle): void;
}

class AreaCalculator implements Visitor {
  visitCircle(c: Circle) { return Math.PI * c.radius ** 2; }
  visitRectangle(r: Rectangle) { return r.width * r.height; }
}
```

**Quand :** Operations variees sur structures stables.

---

### 11. Interpreter

> Interpreter une grammaire.

```go
interface Expression {
  interpret(context: Map<string, number>): number;
}

class AddExpression implements Expression {
  constructor(private left: Expression, private right: Expression) {}
  interpret(ctx: Map<string, number>) {
    return this.left.interpret(ctx) + this.right.interpret(ctx);
  }
}
```

**Quand :** DSL, regles, expressions (rarement utilise).

---

## Tableau de decision

| Besoin | Pattern |
|--------|---------|
| Pipeline de handlers | Chain of Responsibility |
| Undo/redo, queue | Command |
| Parcours custom | Iterator |
| Reduire couplage UI | Mediator |
| Snapshot etat | Memento |
| Evenements, reactive | Observer |
| Machine a etats | State |
| Algorithmes variables | Strategy |
| Squelette + variations | Template Method |
| Operations sur structure | Visitor |

## Sources

- [Refactoring Guru - Behavioral Patterns](https://refactoring.guru/design-patterns/behavioral-patterns)
