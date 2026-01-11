# Factory Patterns

> Deleguer la creation d'objets a des methodes ou classes specialisees.

## Factory Method

### Intention

Definir une interface pour creer un objet, mais laisser les sous-classes
decider quelle classe instancier.

### Structure

```typescript
// 1. Interface produit
interface Notification {
  send(message: string): Promise<void>;
}

// 2. Produits concrets
class EmailNotification implements Notification {
  constructor(private email: string) {}

  async send(message: string): Promise<void> {
    console.log(`Email to ${this.email}: ${message}`);
  }
}

class SMSNotification implements Notification {
  constructor(private phone: string) {}

  async send(message: string): Promise<void> {
    console.log(`SMS to ${this.phone}: ${message}`);
  }
}

class PushNotification implements Notification {
  constructor(private deviceId: string) {}

  async send(message: string): Promise<void> {
    console.log(`Push to ${this.deviceId}: ${message}`);
  }
}

// 3. Creator abstrait
abstract class NotificationFactory {
  abstract createNotification(recipient: string): Notification;

  async notify(recipient: string, message: string): Promise<void> {
    const notification = this.createNotification(recipient);
    await notification.send(message);
  }
}

// 4. Creators concrets
class EmailNotificationFactory extends NotificationFactory {
  createNotification(email: string): Notification {
    return new EmailNotification(email);
  }
}

class SMSNotificationFactory extends NotificationFactory {
  createNotification(phone: string): Notification {
    return new SMSNotification(phone);
  }
}
```

## Abstract Factory

### Intention

Fournir une interface pour creer des familles d'objets lies sans specifier
leurs classes concretes.

### Structure

```typescript
// 1. Interfaces produits
interface Button {
  render(): string;
  onClick(handler: () => void): void;
}

interface Input {
  render(): string;
  getValue(): string;
}

interface Modal {
  open(): void;
  close(): void;
}

// 2. Abstract Factory
interface UIFactory {
  createButton(label: string): Button;
  createInput(placeholder: string): Input;
  createModal(title: string): Modal;
}

// 3. Famille Material Design
class MaterialButton implements Button {
  constructor(private label: string) {}
  render() { return `<md-button>${this.label}</md-button>`; }
  onClick(handler: () => void) { /* ... */ }
}

class MaterialInput implements Input {
  constructor(private placeholder: string) {}
  render() { return `<md-input placeholder="${this.placeholder}">`; }
  getValue() { return ''; }
}

class MaterialModal implements Modal {
  constructor(private title: string) {}
  open() { console.log(`Opening Material modal: ${this.title}`); }
  close() { console.log('Closing Material modal'); }
}

class MaterialUIFactory implements UIFactory {
  createButton(label: string) { return new MaterialButton(label); }
  createInput(placeholder: string) { return new MaterialInput(placeholder); }
  createModal(title: string) { return new MaterialModal(title); }
}

// 4. Famille Bootstrap
class BootstrapButton implements Button {
  constructor(private label: string) {}
  render() { return `<button class="btn">${this.label}</button>`; }
  onClick(handler: () => void) { /* ... */ }
}

class BootstrapUIFactory implements UIFactory {
  createButton(label: string) { return new BootstrapButton(label); }
  createInput(placeholder: string) { return new BootstrapInput(placeholder); }
  createModal(title: string) { return new BootstrapModal(title); }
}
```

## Simple Factory (non-GoF mais courant)

```typescript
type NotificationType = 'email' | 'sms' | 'push';

class NotificationSimpleFactory {
  static create(type: NotificationType, recipient: string): Notification {
    switch (type) {
      case 'email':
        return new EmailNotification(recipient);
      case 'sms':
        return new SMSNotification(recipient);
      case 'push':
        return new PushNotification(recipient);
      default:
        throw new Error(`Unknown notification type: ${type}`);
    }
  }
}

// Usage
const notification = NotificationSimpleFactory.create('email', 'user@example.com');
```

## Variantes modernes

### Factory avec registre

```typescript
type Creator<T> = (...args: unknown[]) => T;

class NotificationRegistry {
  private static creators = new Map<string, Creator<Notification>>();

  static register(type: string, creator: Creator<Notification>): void {
    this.creators.set(type, creator);
  }

  static create(type: string, ...args: unknown[]): Notification {
    const creator = this.creators.get(type);
    if (!creator) throw new Error(`Unknown type: ${type}`);
    return creator(...args);
  }
}

// Enregistrement
NotificationRegistry.register('email', (email: string) =>
  new EmailNotification(email)
);
NotificationRegistry.register('sms', (phone: string) =>
  new SMSNotification(phone)
);

// Usage
const notification = NotificationRegistry.create('email', 'user@example.com');
```

### Factory avec Dependency Injection

```typescript
interface NotificationConfig {
  type: 'email' | 'sms' | 'push';
  recipient: string;
}

class NotificationService {
  constructor(
    private emailFactory: () => EmailNotification,
    private smsFactory: () => SMSNotification,
    private pushFactory: () => PushNotification,
  ) {}

  create(config: NotificationConfig): Notification {
    switch (config.type) {
      case 'email':
        return this.emailFactory();
      case 'sms':
        return this.smsFactory();
      case 'push':
        return this.pushFactory();
    }
  }
}
```

## Anti-patterns

```typescript
// MAUVAIS: Factory avec trop de responsabilites
class GodFactory {
  createUser() { /* ... */ }
  createOrder() { /* ... */ }
  createNotification() { /* ... */ }
  // Viole SRP
}

// MAUVAIS: Logique metier dans la factory
class BadFactory {
  static create(type: string): Notification {
    const notification = new EmailNotification('');
    notification.validate(); // Non! C'est de la logique metier
    notification.save();     // Non! C'est de la persistence
    return notification;
  }
}

// MAUVAIS: Factory qui retourne any
class UnsafeFactory {
  static create(type: string): any {
    // Perte de type safety
    return new SomeClass();
  }
}
```

## Alternative moderne : Functions

```typescript
// Factory functions (plus simple, meme resultat)
const createEmailNotification = (email: string): Notification =>
  new EmailNotification(email);

const createSMSNotification = (phone: string): Notification =>
  new SMSNotification(phone);

// Avec configuration
interface NotificationOptions {
  retries?: number;
  timeout?: number;
}

const createNotification = (
  type: NotificationType,
  recipient: string,
  options: NotificationOptions = {}
): Notification => {
  const creators: Record<NotificationType, () => Notification> = {
    email: () => new EmailNotification(recipient),
    sms: () => new SMSNotification(recipient),
    push: () => new PushNotification(recipient),
  };
  return creators[type]();
};
```

## Tests unitaires

```typescript
import { describe, it, expect, vi } from 'vitest';

describe('NotificationFactory', () => {
  it('should create email notifications', () => {
    const factory = new EmailNotificationFactory();
    const notification = factory.createNotification('test@example.com');

    expect(notification).toBeInstanceOf(EmailNotification);
  });

  it('should use factory method in template', async () => {
    const factory = new SMSNotificationFactory();
    const sendSpy = vi.spyOn(SMSNotification.prototype, 'send');

    await factory.notify('+1234567890', 'Hello');

    expect(sendSpy).toHaveBeenCalledWith('Hello');
  });
});

describe('NotificationRegistry', () => {
  it('should register and create notifications', () => {
    NotificationRegistry.register('webhook', (url: string) =>
      new WebhookNotification(url)
    );

    const notification = NotificationRegistry.create(
      'webhook',
      'https://example.com'
    );

    expect(notification).toBeInstanceOf(WebhookNotification);
  });

  it('should throw for unknown types', () => {
    expect(() => NotificationRegistry.create('unknown')).toThrow();
  });
});

describe('UIFactory', () => {
  it('should create consistent UI families', () => {
    const factory: UIFactory = new MaterialUIFactory();

    const button = factory.createButton('Click');
    const input = factory.createInput('Type here');

    expect(button.render()).toContain('md-button');
    expect(input.render()).toContain('md-input');
  });
});
```

## Quand utiliser

### Factory Method

- Creation deleguee aux sous-classes
- Produit unique avec variantes

### Abstract Factory

- Familles d'objets coherents
- Independance plateforme/theme

### Simple Factory

- Logique de creation centralisee
- Pas besoin d'extensibilite par heritage

## Patterns lies

- **Builder** : Construction complexe vs selection de type
- **Prototype** : Clonage vs instantiation
- **Singleton** : Souvent combine avec Factory

## Sources

- [Refactoring Guru - Factory Method](https://refactoring.guru/design-patterns/factory-method)
- [Refactoring Guru - Abstract Factory](https://refactoring.guru/design-patterns/abstract-factory)
