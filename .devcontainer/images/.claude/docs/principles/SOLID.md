# SOLID Principles

5 principes fondamentaux de la programmation orientée objet par Robert C. Martin.

## Les 5 Principes

### S - Single Responsibility Principle (SRP)

> Une classe ne doit avoir qu'une seule raison de changer.

**Problème :**
```typescript
// ❌ Mauvais - Multiple responsabilités
class User {
  save() { /* DB logic */ }
  validate() { /* Validation logic */ }
  sendEmail() { /* Email logic */ }
}
```

**Solution :**
```typescript
// ✅ Bon - Une responsabilité par classe
class User { /* Data only */ }
class UserRepository { save(user: User) {} }
class UserValidator { validate(user: User) {} }
class UserNotifier { sendEmail(user: User) {} }
```

**Quand l'appliquer :** Toujours. C'est le principe le plus fondamental.

---

### O - Open/Closed Principle (OCP)

> Ouvert à l'extension, fermé à la modification.

**Problème :**
```typescript
// ❌ Mauvais - Modifier pour ajouter
class PaymentProcessor {
  process(type: string) {
    if (type === 'card') { /* ... */ }
    else if (type === 'paypal') { /* ... */ }
    // Ajouter ici = modifier
  }
}
```

**Solution :**
```typescript
// ✅ Bon - Étendre sans modifier
interface PaymentMethod {
  process(): void;
}

class CardPayment implements PaymentMethod { process() {} }
class PayPalPayment implements PaymentMethod { process() {} }
// Ajouter = nouvelle classe
```

**Quand l'appliquer :** Quand le code change souvent pour ajouter des variantes.

---

### L - Liskov Substitution Principle (LSP)

> Les sous-types doivent être substituables à leurs types de base.

**Problème :**
```typescript
// ❌ Mauvais - Carré n'est pas un Rectangle
class Rectangle {
  setWidth(w: number) { this.width = w; }
  setHeight(h: number) { this.height = h; }
}

class Square extends Rectangle {
  setWidth(w: number) { this.width = this.height = w; } // Viole LSP
}
```

**Solution :**
```typescript
// ✅ Bon - Abstraction commune
interface Shape {
  area(): number;
}

class Rectangle implements Shape { area() { return this.width * this.height; } }
class Square implements Shape { area() { return this.side ** 2; } }
```

**Quand l'appliquer :** Avant chaque héritage, vérifier la substitution.

---

### I - Interface Segregation Principle (ISP)

> Plusieurs interfaces spécifiques valent mieux qu'une interface générale.

**Problème :**
```typescript
// ❌ Mauvais - Interface trop large
interface Worker {
  work(): void;
  eat(): void;
  sleep(): void;
}

class Robot implements Worker {
  work() {}
  eat() { throw new Error('Robots dont eat'); } // Forcé d'implémenter
  sleep() { throw new Error('Robots dont sleep'); }
}
```

**Solution :**
```typescript
// ✅ Bon - Interfaces spécifiques
interface Workable { work(): void; }
interface Eatable { eat(): void; }
interface Sleepable { sleep(): void; }

class Robot implements Workable { work() {} }
class Human implements Workable, Eatable, Sleepable { /* ... */ }
```

**Quand l'appliquer :** Quand des implémenteurs doivent laisser des méthodes vides.

---

### D - Dependency Inversion Principle (DIP)

> Dépendre d'abstractions, pas d'implémentations concrètes.

**Problème :**
```typescript
// ❌ Mauvais - Dépendance concrète
class UserService {
  private db = new MySQLDatabase(); // Couplage fort

  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = ${id}`);
  }
}
```

**Solution :**
```typescript
// ✅ Bon - Dépendance sur abstraction
interface Database {
  query(sql: string): any;
}

class UserService {
  constructor(private db: Database) {} // Injection

  getUser(id: string) {
    return this.db.query(`SELECT * FROM users WHERE id = ${id}`);
  }
}
```

**Quand l'appliquer :** Pour tout ce qui est externe (DB, API, filesystem).

---

## Résumé Visuel

```
┌─────────────────────────────────────────────────────────────┐
│  S  │ Une classe = Une responsabilité                       │
├─────────────────────────────────────────────────────────────┤
│  O  │ Ajouter du code, pas modifier                         │
├─────────────────────────────────────────────────────────────┤
│  L  │ Sous-classe = comportement parent préservé            │
├─────────────────────────────────────────────────────────────┤
│  I  │ Interfaces petites et spécifiques                     │
├─────────────────────────────────────────────────────────────┤
│  D  │ Dépendre d'interfaces, pas de classes                 │
└─────────────────────────────────────────────────────────────┘
```

## Patterns liés

- **Factory** : Respecte OCP pour la création
- **Strategy** : Respecte OCP pour les algorithmes
- **Adapter** : Aide à respecter DIP
- **Facade** : Aide à respecter ISP

## Sources

- [Robert C. Martin - Clean Architecture](https://blog.cleancoder.com/)
- [SOLID Principles - Wikipedia](https://en.wikipedia.org/wiki/SOLID)
