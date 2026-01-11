# Copy-on-Write (COW)

Pattern d'optimisation différant la copie jusqu'à la modification.

---

## Qu'est-ce que Copy-on-Write ?

> Stratégie de copie paresseuse : partager les données en lecture, copier seulement lors de l'écriture.

```
┌──────────────────────────────────────────────────────────────┐
│                    Copy-on-Write                              │
│                                                               │
│  Initial:                     After Write to B:               │
│                                                               │
│  ┌───────┐                    ┌───────┐                       │
│  │   A   │──┐                 │   A   │───► Data (original)   │
│  └───────┘  │                 └───────┘                       │
│             ├──► Data                                         │
│  ┌───────┐  │                 ┌───────┐                       │
│  │   B   │──┘                 │   B   │───► Data' (copy)      │
│  └───────┘                    └───────┘                       │
│                                                               │
│  A et B partagent              B a sa propre copie            │
└──────────────────────────────────────────────────────────────┘
```

**Pourquoi :**

- Économiser la mémoire (pas de copie si pas de modification)
- Améliorer les performances (copie différée)
- Sécurité des snapshots (état cohérent)
- Partage efficace entre threads

---

## Implémentation de base

### CopyOnWriteArray

```typescript
class CopyOnWriteArray<T> {
  private data: T[];
  private refCount: number = 1;

  constructor(initial: T[] = []) {
    this.data = [...initial];
  }

  // Lecture - pas de copie
  get(index: number): T {
    return this.data[index];
  }

  get length(): number {
    return this.data.length;
  }

  // Iteration - pas de copie
  *[Symbol.iterator](): Iterator<T> {
    for (const item of this.data) {
      yield item;
    }
  }

  // Écriture - copie avant modification
  set(index: number, value: T): CopyOnWriteArray<T> {
    // Créer une copie avec la modification
    const newData = [...this.data];
    newData[index] = value;
    return new CopyOnWriteArray(newData);
  }

  push(value: T): CopyOnWriteArray<T> {
    return new CopyOnWriteArray([...this.data, value]);
  }

  filter(predicate: (value: T) => boolean): CopyOnWriteArray<T> {
    return new CopyOnWriteArray(this.data.filter(predicate));
  }

  map<U>(fn: (value: T) => U): CopyOnWriteArray<U> {
    return new CopyOnWriteArray(this.data.map(fn));
  }
}

// Usage
const list1 = new CopyOnWriteArray([1, 2, 3]);
const list2 = list1.push(4);  // list1 inchangé, list2 = [1,2,3,4]
const list3 = list2.set(0, 10); // list2 inchangé, list3 = [10,2,3,4]

console.log([...list1]); // [1, 2, 3]
console.log([...list2]); // [1, 2, 3, 4]
console.log([...list3]); // [10, 2, 3, 4]
```

---

### CopyOnWriteMap

```typescript
class CopyOnWriteMap<K, V> {
  private data: Map<K, V>;

  constructor(entries?: Iterable<[K, V]>) {
    this.data = new Map(entries);
  }

  // Lecture - pas de copie
  get(key: K): V | undefined {
    return this.data.get(key);
  }

  has(key: K): boolean {
    return this.data.has(key);
  }

  get size(): number {
    return this.data.size;
  }

  // Écriture - nouvelle instance
  set(key: K, value: V): CopyOnWriteMap<K, V> {
    const newMap = new Map(this.data);
    newMap.set(key, value);
    return new CopyOnWriteMap(newMap);
  }

  delete(key: K): CopyOnWriteMap<K, V> {
    const newMap = new Map(this.data);
    newMap.delete(key);
    return new CopyOnWriteMap(newMap);
  }

  merge(other: CopyOnWriteMap<K, V>): CopyOnWriteMap<K, V> {
    const newMap = new Map(this.data);
    for (const [k, v] of other.data) {
      newMap.set(k, v);
    }
    return new CopyOnWriteMap(newMap);
  }
}
```

---

## Optimisation avec Structural Sharing

> Partager les parties non modifiées de la structure.

```typescript
// Arbre immutable avec partage structurel
class ImmutableTree<T> {
  constructor(
    readonly value: T,
    readonly left?: ImmutableTree<T>,
    readonly right?: ImmutableTree<T>,
  ) {}

  // Modifier seulement le chemin vers le noeud
  setValue(path: 'left' | 'right', newValue: T): ImmutableTree<T> {
    if (path === 'left') {
      // Réutilise this.right, crée nouveau left
      return new ImmutableTree(
        this.value,
        new ImmutableTree(newValue),
        this.right,  // Partagé, pas copié
      );
    } else {
      return new ImmutableTree(
        this.value,
        this.left,   // Partagé, pas copié
        new ImmutableTree(newValue),
      );
    }
  }
}

/*
  Avant:          Après setValue('left', X):

      A                    A'
     / \                  / \
    B   C       →        X   C  (C est partagé)
   / \
  D   E

  Seulement A et B sont copiés, C/D/E sont partagés
*/
```

---

## Utilisation avec Immer

```typescript
import produce from 'immer';

interface State {
  users: { id: string; name: string }[];
  settings: { theme: string };
}

const initialState: State = {
  users: [
    { id: '1', name: 'Alice' },
    { id: '2', name: 'Bob' },
  ],
  settings: { theme: 'dark' },
};

// Immer utilise COW en interne
const nextState = produce(initialState, (draft) => {
  // Syntax mutable, mais crée une copie
  draft.users.push({ id: '3', name: 'Charlie' });
  draft.users[0].name = 'Alicia';
  // settings n'est pas modifié, donc partagé
});

// Vérification du partage structurel
console.log(initialState.settings === nextState.settings); // true (partagé)
console.log(initialState.users === nextState.users);       // false (copié)
console.log(initialState.users[1] === nextState.users[1]); // true (Bob pas modifié)
```

---

## COW pour Thread Safety

```typescript
// Collection thread-safe sans locks pour lecture
class ConcurrentCopyOnWriteList<T> {
  private volatile data: T[] = [];

  // Lecture - aucun lock nécessaire
  get(index: number): T {
    return this.data[index];
  }

  toArray(): T[] {
    return this.data; // Safe: la référence est immutable
  }

  // Écriture - synchronisée
  add(item: T): void {
    synchronized(this, () => {
      // Copie + modification atomique
      const newData = [...this.data, item];
      this.data = newData; // Assignation atomique de référence
    });
  }

  remove(index: number): void {
    synchronized(this, () => {
      const newData = [
        ...this.data.slice(0, index),
        ...this.data.slice(index + 1),
      ];
      this.data = newData;
    });
  }
}

// Les lecteurs ne bloquent jamais
// Les écrivains se bloquent entre eux seulement
```

---

## COW pour Snapshots

```typescript
class DocumentStore {
  private history: CopyOnWriteMap<string, Document>[] = [];
  private current: CopyOnWriteMap<string, Document>;

  constructor() {
    this.current = new CopyOnWriteMap();
  }

  // Créer un snapshot (gratuit grâce à COW)
  createSnapshot(): number {
    this.history.push(this.current);
    return this.history.length - 1;
  }

  // Modifier (crée nouvelle version)
  updateDocument(id: string, doc: Document): void {
    this.current = this.current.set(id, doc);
  }

  // Lire depuis un snapshot
  getFromSnapshot(snapshotId: number, docId: string): Document | undefined {
    return this.history[snapshotId]?.get(docId);
  }

  // Rollback à un snapshot
  rollback(snapshotId: number): void {
    if (snapshotId < this.history.length) {
      this.current = this.history[snapshotId];
      this.history = this.history.slice(0, snapshotId + 1);
    }
  }
}

// Usage
const store = new DocumentStore();
store.updateDocument('doc1', { content: 'v1' });

const snapshot1 = store.createSnapshot();

store.updateDocument('doc1', { content: 'v2' });
store.updateDocument('doc2', { content: 'new' });

// snapshot1 contient toujours v1 de doc1
console.log(store.getFromSnapshot(snapshot1, 'doc1')); // { content: 'v1' }
```

---

## COW dans les systèmes de fichiers

```typescript
// Simulation de COW filesystem (comme ZFS, Btrfs)
class CowFileSystem {
  private blocks: Map<number, Buffer> = new Map();
  private fileTable: Map<string, number[]> = new Map(); // file -> block ids
  private nextBlockId = 0;

  // Écriture COW
  writeFile(path: string, content: Buffer): void {
    const oldBlocks = this.fileTable.get(path) || [];

    // Allouer nouveaux blocs pour le contenu modifié
    const newBlocks: number[] = [];
    for (let i = 0; i < content.length; i += 4096) {
      const blockId = this.nextBlockId++;
      this.blocks.set(blockId, content.slice(i, i + 4096));
      newBlocks.push(blockId);
    }

    // Atomic pointer swap
    this.fileTable.set(path, newBlocks);

    // Les anciens blocs peuvent être garbage collected
    // ou conservés pour snapshots
  }

  // Snapshot instantané (juste copier les pointeurs)
  createSnapshot(): Map<string, number[]> {
    return new Map(this.fileTable);
  }

  // Clone de fichier (pas de copie physique)
  cloneFile(source: string, dest: string): void {
    const blocks = this.fileTable.get(source);
    if (blocks) {
      // Juste copier les références de blocs
      this.fileTable.set(dest, [...blocks]);
      // Les blocs physiques sont partagés jusqu'à modification
    }
  }
}
```

---

## Cas d'usage typiques

### 1. State Management (Redux/Vuex)

```typescript
// Reducers immutables avec COW
function usersReducer(
  state: UsersState = initialState,
  action: Action,
): UsersState {
  switch (action.type) {
    case 'ADD_USER':
      // COW: nouvel array, anciennes références
      return {
        ...state,
        users: [...state.users, action.payload],
      };

    case 'UPDATE_USER':
      return {
        ...state,
        users: state.users.map((user) =>
          user.id === action.payload.id
            ? { ...user, ...action.payload } // COW pour user modifié
            : user // Réutilise la référence
        ),
      };

    default:
      return state; // Pas de copie si pas de changement
  }
}
```

### 2. Undo/Redo

```typescript
class UndoManager<T> {
  private past: T[] = [];
  private future: T[] = [];

  constructor(private current: T) {}

  // Enregistrer l'état actuel avant modification
  update(newState: T): void {
    this.past.push(this.current); // COW: juste stocker la référence
    this.current = newState;
    this.future = []; // Effacer le futur
  }

  undo(): T | undefined {
    if (this.past.length === 0) return undefined;

    this.future.push(this.current);
    this.current = this.past.pop()!;
    return this.current;
  }

  redo(): T | undefined {
    if (this.future.length === 0) return undefined;

    this.past.push(this.current);
    this.current = this.future.pop()!;
    return this.current;
  }
}
```

### 3. Caching avec versioning

```typescript
class VersionedCache<T> {
  private versions: Map<number, T> = new Map();
  private currentVersion = 0;

  set(value: T): number {
    const version = ++this.currentVersion;
    this.versions.set(version, value);
    return version;
  }

  get(version?: number): T | undefined {
    return this.versions.get(version ?? this.currentVersion);
  }

  // Comparaison de versions efficace
  hasChanged(v1: number, v2: number): boolean {
    const val1 = this.versions.get(v1);
    const val2 = this.versions.get(v2);
    return val1 !== val2; // Comparaison par référence
  }
}
```

---

## Avantages et Inconvénients

### Avantages

| Avantage | Explication |
|----------|-------------|
| Mémoire | Pas de copie si pas de modification |
| Performance lecture | Aucun lock nécessaire |
| Snapshots gratuits | Juste copier les pointeurs |
| Thread-safe | Références immutables |
| Undo/Redo facile | Conserver les anciennes versions |

### Inconvénients

| Inconvénient | Mitigation |
|--------------|------------|
| Coût d'écriture | Batch les modifications |
| Pression GC | Pooling, structural sharing |
| Complexité | Utiliser Immer ou lib dédiée |

---

## Patterns connexes

| Pattern | Relation |
|---------|----------|
| **Immutability** | Base du COW |
| **Structural Sharing** | Optimisation du COW |
| **Snapshot** | Cas d'usage principal |
| **Flyweight** | Partage de données similaire |
| **Prototype** | Clone paresseux |

---

## Sources

- [Copy-on-write - Wikipedia](https://en.wikipedia.org/wiki/Copy-on-write)
- [Immer.js](https://immerjs.github.io/immer/)
- [Persistent Data Structures](https://en.wikipedia.org/wiki/Persistent_data_structure)
- [ZFS Copy-on-Write](https://docs.oracle.com/cd/E19253-01/819-5461/zfsover-2/)
