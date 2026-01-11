# Creational Patterns (GoF)

Patterns de creation d'objets.

## Fichiers detailles

| Pattern | Fichier | Description |
|---------|---------|-------------|
| Builder | [builder.md](builder.md) | Construction complexe etape par etape |
| Factory Method / Abstract Factory | [factory.md](factory.md) | Delegation de creation |
| Singleton | [singleton.md](singleton.md) | Instance unique + alternatives DI |

## Les 5 Patterns

### 1. Factory Method

> Deleguer la creation aux sous-classes.

Voir fichier detaille: [factory.md](factory.md)

```go
abstract class LoggerFactory {
  abstract createLogger(): Logger;

  log(message: string) {
    const logger = this.createLogger();
    logger.log(message);
  }
}

class ConsoleLoggerFactory extends LoggerFactory {
  createLogger() { return new ConsoleLogger(); }
}
```

**Quand :** Creation deleguee aux sous-classes.

---

### 2. Abstract Factory

> Familles d'objets lies.

Voir fichier detaille: [factory.md](factory.md)

```go
interface UIFactory {
  createButton(): Button;
  createInput(): Input;
}

class MaterialUIFactory implements UIFactory {
  createButton() { return new MaterialButton(); }
  createInput() { return new MaterialInput(); }
}
```

**Quand :** Plusieurs familles d'objets coherents.

---

### 3. Builder

> Construction complexe etape par etape.

Voir fichier detaille: [builder.md](builder.md)

```go
const query = new QueryBuilder()
  .select(['id', 'name'])
  .from('users')
  .where('active = true')
  .build();
```

**Quand :** Objets complexes avec nombreuses options.

---

### 4. Prototype

> Cloner des objets existants.

```go
interface Prototype<T> {
  clone(): T;
}

class Document implements Prototype<Document> {
  clone(): Document {
    return new Document(
      this.title,
      this.content,
      new Map(this.metadata),
    );
  }
}
```

**Quand :** Cout de creation eleve, copie plus efficace.

---

### 5. Singleton

> Instance unique globale.

Voir fichier detaille: [singleton.md](singleton.md)

```go
class Database {
  private static instance: Database;

  private constructor() {}

  static getInstance(): Database {
    if (!Database.instance) {
      Database.instance = new Database();
    }
    return Database.instance;
  }
}
```

**Quand :** Une seule instance requise (attention: souvent un anti-pattern).

---

## Tableau de decision

| Besoin | Pattern |
|--------|---------|
| Deleguer creation a sous-classes | Factory Method |
| Familles d'objets coherents | Abstract Factory |
| Construction complexe/optionnelle | Builder |
| Clonage plus efficace que creation | Prototype |
| Instance unique | Singleton |

## Alternatives modernes

| Pattern | Alternative |
|---------|-------------|
| Factory | Dependency Injection |
| Singleton | DI Container (scoped) |
| Builder | Object literals + defaults |

## Sources

- [Refactoring Guru - Creational Patterns](https://refactoring.guru/design-patterns/creational-patterns)
