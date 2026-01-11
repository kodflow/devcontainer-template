# Command Pattern

> Encapsuler une requete comme un objet pour parametrer, journaliser ou annuler.

## Intention

Encapsuler une requete en tant qu'objet, permettant de parametrer les clients
avec differentes requetes, mettre en file d'attente, journaliser les requetes,
et supporter les operations reversibles (undo).

## Structure

```typescript
// 1. Interface Command
interface Command {
  execute(): void;
  undo(): void;
}

// 2. Receiver (l'objet qui effectue l'action)
class TextEditor {
  private content: string = '';
  private cursorPosition: number = 0;

  getContent(): string {
    return this.content;
  }

  insertAt(position: number, text: string): void {
    this.content =
      this.content.slice(0, position) + text + this.content.slice(position);
    this.cursorPosition = position + text.length;
  }

  deleteRange(start: number, end: number): string {
    const deleted = this.content.slice(start, end);
    this.content = this.content.slice(0, start) + this.content.slice(end);
    this.cursorPosition = start;
    return deleted;
  }

  getCursor(): number {
    return this.cursorPosition;
  }

  setCursor(position: number): void {
    this.cursorPosition = Math.min(position, this.content.length);
  }
}

// 3. Concrete Commands
class InsertTextCommand implements Command {
  private position: number;

  constructor(
    private editor: TextEditor,
    private text: string,
  ) {
    this.position = editor.getCursor();
  }

  execute(): void {
    this.editor.insertAt(this.position, this.text);
  }

  undo(): void {
    this.editor.deleteRange(this.position, this.position + this.text.length);
  }
}

class DeleteTextCommand implements Command {
  private deletedText: string = '';
  private position: number;

  constructor(
    private editor: TextEditor,
    private length: number,
  ) {
    this.position = editor.getCursor();
  }

  execute(): void {
    this.deletedText = this.editor.deleteRange(
      this.position,
      this.position + this.length,
    );
  }

  undo(): void {
    this.editor.insertAt(this.position, this.deletedText);
  }
}

// 4. Invoker avec historique
class CommandHistory {
  private undoStack: Command[] = [];
  private redoStack: Command[] = [];

  execute(command: Command): void {
    command.execute();
    this.undoStack.push(command);
    this.redoStack = []; // Clear redo apres nouvelle action
  }

  undo(): boolean {
    const command = this.undoStack.pop();
    if (!command) return false;

    command.undo();
    this.redoStack.push(command);
    return true;
  }

  redo(): boolean {
    const command = this.redoStack.pop();
    if (!command) return false;

    command.execute();
    this.undoStack.push(command);
    return true;
  }

  canUndo(): boolean {
    return this.undoStack.length > 0;
  }

  canRedo(): boolean {
    return this.redoStack.length > 0;
  }
}
```

## Usage

```typescript
const editor = new TextEditor();
const history = new CommandHistory();

// Executer des commandes
history.execute(new InsertTextCommand(editor, 'Hello'));
history.execute(new InsertTextCommand(editor, ' World'));
console.log(editor.getContent()); // "Hello World"

// Undo
history.undo();
console.log(editor.getContent()); // "Hello"

// Redo
history.redo();
console.log(editor.getContent()); // "Hello World"

// Nouvelle action efface redo
history.execute(new InsertTextCommand(editor, '!'));
console.log(editor.getContent()); // "Hello World!"
console.log(history.canRedo()); // false
```

## Macro Command (Composite)

```typescript
class MacroCommand implements Command {
  private commands: Command[] = [];

  add(command: Command): void {
    this.commands.push(command);
  }

  execute(): void {
    for (const command of this.commands) {
      command.execute();
    }
  }

  undo(): void {
    // Undo en ordre inverse
    for (let i = this.commands.length - 1; i >= 0; i--) {
      this.commands[i].undo();
    }
  }
}

// Usage - formater un bloc de texte
const formatMacro = new MacroCommand();
formatMacro.add(new SelectAllCommand(editor));
formatMacro.add(new UppercaseCommand(editor));
formatMacro.add(new BoldCommand(editor));

history.execute(formatMacro);
// Tout est annule en une seule operation undo
history.undo();
```

## Command Queue (Asynchrone)

```typescript
interface AsyncCommand {
  execute(): Promise<void>;
  undo(): Promise<void>;
}

class CommandQueue {
  private queue: AsyncCommand[] = [];
  private isProcessing = false;

  async enqueue(command: AsyncCommand): Promise<void> {
    this.queue.push(command);
    await this.processQueue();
  }

  private async processQueue(): Promise<void> {
    if (this.isProcessing) return;
    this.isProcessing = true;

    while (this.queue.length > 0) {
      const command = this.queue.shift()!;
      try {
        await command.execute();
      } catch (error) {
        console.error('Command failed:', error);
        // Optionnel: rollback des commandes precedentes
      }
    }

    this.isProcessing = false;
  }
}

// Command asynchrone
class SendEmailCommand implements AsyncCommand {
  constructor(
    private emailService: EmailService,
    private to: string,
    private subject: string,
    private body: string,
  ) {}

  async execute(): Promise<void> {
    await this.emailService.send(this.to, this.subject, this.body);
  }

  async undo(): Promise<void> {
    // Les emails ne peuvent pas etre annules, mais on peut envoyer un rappel
    await this.emailService.send(
      this.to,
      `[CANCELLED] ${this.subject}`,
      'Please disregard the previous email.',
    );
  }
}
```

## Transactional Command

```typescript
interface TransactionalCommand extends Command {
  validate(): boolean;
  commit(): void;
  rollback(): void;
}

class TransactionManager {
  private commands: TransactionalCommand[] = [];
  private executed: TransactionalCommand[] = [];

  add(command: TransactionalCommand): void {
    this.commands.push(command);
  }

  async executeAll(): Promise<boolean> {
    // Validation phase
    for (const command of this.commands) {
      if (!command.validate()) {
        console.error('Validation failed');
        return false;
      }
    }

    // Execution phase
    try {
      for (const command of this.commands) {
        command.execute();
        this.executed.push(command);
      }

      // Commit phase
      for (const command of this.executed) {
        command.commit();
      }

      return true;
    } catch (error) {
      // Rollback phase
      for (const command of this.executed.reverse()) {
        command.rollback();
      }
      return false;
    }
  }
}
```

## Anti-patterns

```typescript
// MAUVAIS: Command qui fait trop
class GodCommand implements Command {
  execute(): void {
    this.validateInput();
    this.processData();
    this.saveToDatabase();
    this.sendNotification();
    this.updateCache();
    // Devrait etre plusieurs commands
  }

  undo(): void {
    // Comment annuler tout ca proprement?
  }
}

// MAUVAIS: Command avec etat externe
class StatefulCommand implements Command {
  private static lastResult: unknown; // Etat partage = problemes

  execute(): void {
    StatefulCommand.lastResult = this.doSomething();
  }
}

// MAUVAIS: Undo incomplet
class IncompleteUndoCommand implements Command {
  private previousState?: State;

  execute(): void {
    // Oublie de sauvegarder l'etat avant modification
    this.modify();
  }

  undo(): void {
    // previousState est undefined!
    this.restore(this.previousState);
  }
}
```

## Tests unitaires

```typescript
import { describe, it, expect, beforeEach, vi } from 'vitest';

describe('TextEditor Commands', () => {
  let editor: TextEditor;
  let history: CommandHistory;

  beforeEach(() => {
    editor = new TextEditor();
    history = new CommandHistory();
  });

  describe('InsertTextCommand', () => {
    it('should insert text at cursor', () => {
      history.execute(new InsertTextCommand(editor, 'Hello'));
      expect(editor.getContent()).toBe('Hello');
    });

    it('should support undo', () => {
      history.execute(new InsertTextCommand(editor, 'Hello'));
      history.undo();
      expect(editor.getContent()).toBe('');
    });
  });

  describe('DeleteTextCommand', () => {
    beforeEach(() => {
      history.execute(new InsertTextCommand(editor, 'Hello World'));
    });

    it('should delete text', () => {
      editor.setCursor(5);
      history.execute(new DeleteTextCommand(editor, 6));
      expect(editor.getContent()).toBe('Hello');
    });

    it('should restore deleted text on undo', () => {
      editor.setCursor(5);
      history.execute(new DeleteTextCommand(editor, 6));
      history.undo();
      expect(editor.getContent()).toBe('Hello World');
    });
  });

  describe('CommandHistory', () => {
    it('should support multiple undo/redo', () => {
      history.execute(new InsertTextCommand(editor, 'A'));
      history.execute(new InsertTextCommand(editor, 'B'));
      history.execute(new InsertTextCommand(editor, 'C'));

      expect(editor.getContent()).toBe('ABC');

      history.undo();
      expect(editor.getContent()).toBe('AB');

      history.undo();
      expect(editor.getContent()).toBe('A');

      history.redo();
      expect(editor.getContent()).toBe('AB');
    });

    it('should clear redo stack after new command', () => {
      history.execute(new InsertTextCommand(editor, 'A'));
      history.undo();
      history.execute(new InsertTextCommand(editor, 'B'));

      expect(history.canRedo()).toBe(false);
    });
  });

  describe('MacroCommand', () => {
    it('should execute all commands', () => {
      const macro = new MacroCommand();
      macro.add(new InsertTextCommand(editor, 'Hello'));
      macro.add(new InsertTextCommand(editor, ' World'));

      macro.execute();

      expect(editor.getContent()).toBe('Hello World');
    });

    it('should undo all commands in reverse order', () => {
      const macro = new MacroCommand();
      macro.add(new InsertTextCommand(editor, 'Hello'));
      macro.add(new InsertTextCommand(editor, ' World'));

      history.execute(macro);
      history.undo();

      expect(editor.getContent()).toBe('');
    });
  });
});
```

## Quand utiliser

- Operations reversibles (Undo/Redo)
- File d'attente de requetes
- Journalisation d'operations
- Transactions
- Callbacks structures

## Patterns lies

- **Memento** : Sauvegarde l'etat pour undo
- **Strategy** : Algorithmes vs operations
- **Composite** : Macro commands

## Sources

- [Refactoring Guru - Command](https://refactoring.guru/design-patterns/command)
