# Structural Patterns (GoF)

Patterns de composition d'objets.

## Fichiers detailles

| Pattern | Fichier | Description |
|---------|---------|-------------|
| Adapter | [adapter.md](adapter.md) | Convertir interfaces incompatibles |
| Decorator | [decorator.md](decorator.md) | Ajouter comportements dynamiquement |
| Proxy | [proxy.md](proxy.md) | Virtual, Remote, Protection, Cache |
| Facade | [facade.md](facade.md) | Simplifier systemes complexes |

## Les 7 Patterns

### 1. Adapter

> Convertir une interface en une autre.

Voir fichier detaille: [adapter.md](adapter.md)

```typescript
class StripeAdapter implements PaymentProcessor {
  constructor(private stripe: StripeAPI) {}

  async pay(amount: number) {
    await this.stripe.charge(amount * 100, 'EUR');
  }
}
```

**Quand :** Integrer du code legacy ou librairies tierces.

---

### 2. Bridge

> Separer abstraction et implementation.

```typescript
abstract class Shape {
  constructor(protected renderer: Renderer) {}
  abstract draw(): void;
}

class Circle extends Shape {
  draw() { this.renderer.render('circle'); }
}
```

**Quand :** Plusieurs dimensions de variation independantes.

---

### 3. Composite

> Traiter objets simples et composes uniformement.

```typescript
interface Component {
  getPrice(): number;
}

class Box implements Component {
  private items: Component[] = [];
  add(item: Component) { this.items.push(item); }
  getPrice() {
    return this.items.reduce((sum, item) => sum + item.getPrice(), 0);
  }
}
```

**Quand :** Structures arborescentes (menus, fichiers, UI).

---

### 4. Decorator

> Ajouter des comportements dynamiquement.

Voir fichier detaille: [decorator.md](decorator.md)

```typescript
let client: HttpClient = new BasicHttpClient();
client = new LoggingDecorator(client);
client = new AuthDecorator(client, () => 'token');
client = new RetryDecorator(client, 3);
```

**Quand :** Ajouter des responsabilites sans modifier la classe.

---

### 5. Facade

> Interface simplifiee pour un sous-systeme complexe.

Voir fichier detaille: [facade.md](facade.md)

```typescript
class VideoPublisher {
  publish(video: string, audio: string) {
    const v = this.videoEncoder.encode(video);
    const a = this.audioEncoder.encode(audio);
    const file = this.muxer.mux(v, a);
    this.uploader.upload(file);
  }
}
```

**Quand :** Simplifier l'acces a un systeme complexe.

---

### 6. Flyweight

> Partager des etats communs entre objets.

```typescript
class FlyweightFactory {
  private cache = new Map<string, CharacterFlyweight>();

  get(font: string, size: number): CharacterFlyweight {
    const key = `${font}-${size}`;
    if (!this.cache.has(key)) {
      this.cache.set(key, new CharacterFlyweight(font, size));
    }
    return this.cache.get(key)!;
  }
}
```

**Quand :** Beaucoup d'objets similaires (jeux, editeurs texte).

---

### 7. Proxy

> Controler l'acces a un objet.

Voir fichier detaille: [proxy.md](proxy.md)

```typescript
class ImageProxy implements Image {
  private realImage: RealImage | null = null;

  display() {
    if (!this.realImage) {
      this.realImage = new RealImage(this.filename);
    }
    this.realImage.display();
  }
}
```

**Types :** Virtual (lazy), Remote (RPC), Protection (auth), Cache.

---

## Tableau de decision

| Besoin | Pattern |
|--------|---------|
| Convertir interface | Adapter |
| Deux axes de variation | Bridge |
| Structure arborescente | Composite |
| Ajouter comportements | Decorator |
| Simplifier systeme complexe | Facade |
| Partager etat commun | Flyweight |
| Controler acces | Proxy |

## Sources

- [Refactoring Guru - Structural Patterns](https://refactoring.guru/design-patterns/structural-patterns)
