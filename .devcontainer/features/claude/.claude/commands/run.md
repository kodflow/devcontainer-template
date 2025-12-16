# Run - Task Executor

$ARGUMENTS

---

## Parsing des arguments

| Pattern | Action |
|---------|--------|
| `<project>` | Exécute toutes les tâches du projet |
| `--for <project> --task <id>` | Exécute une tâche spécifique |

---

## Actions

### `<project>` : Exécuter tout le projet

1. **Vérifier les tâches interrompues** :
   ```bash
   task project:<project> +ACTIVE list
   ```
   Si trouvées → reprendre ou terminer d'abord

2. **Récupérer les tâches prêtes** par phase :
   ```bash
   task project:<project> +claude +UNBLOCKED +PENDING export
   ```

3. **Pour chaque phase** (ordre croissant) :

   **Tâches `parallel:yes`** → Lancer en parallèle via `Task` tool
   ```
   Task tool avec model approprié pour chaque tâche
   Attendre complétion de toutes
   ```

   **Tâches `parallel:no`** → Exécuter séquentiellement

4. **Pour chaque tâche** :
   ```bash
   # Lire les détails
   task <ID> info

   # Démarrer
   task <ID> start

   # Exécuter selon annotations (Action, Fichiers, Critères)

   # Succès
   task <ID> done

   # Ou échec
   task <ID> annotate "ERREUR: <message>"
   task <ID> stop
   ```

5. **Passer à la phase suivante** quand toutes terminées

### `--for <project> --task <id>` : Exécuter une tâche

1. **Lire les détails** :
   ```bash
   task <ID> info
   ```

2. **Extraire** :
   - `model` → Utiliser ce modèle
   - Annotations → Actions à faire

3. **Exécuter** :
   ```bash
   task <ID> start
   # ... travail ...
   task <ID> done  # ou stop si erreur
   ```

---

## Reprise après crash

```bash
# Trouver les tâches interrompues
task +ACTIVE list

# Pour chaque tâche active
task <ID> info  # Voir où on en était
# Soit reprendre, soit reset
task <ID> stop  # Reset si besoin de recommencer
```

---

## Parallélisation

```
Phase 1:
  ├─ T1 (parallel:no)  → Exécuter seul
  ├─ T2 (parallel:yes) ┐
  └─ T3 (parallel:yes) ┴→ Exécuter ensemble

Phase 2:
  └─ T4 (depends:1,2,3) → Après phase 1
```

Utiliser `Task` tool avec `run_in_background: true` pour paralléliser :
```
Task(subagent_type: "general-purpose", model: <model_from_task>)
```

---

## Output

### Exécution projet
```
## Exécution : <projet>

### Phase 1
- [x] #1: <tâche> (haiku) ✓
- [x] #2: <tâche> (sonnet) ✓ [//]
- [x] #3: <tâche> (sonnet) ✓ [//]

### Phase 2
- [x] #4: <tâche> (opus) ✓
- [ ] #5: <tâche> - EN COURS

### Résumé
- Total : 5
- Complétées : 4
- En cours : 1
- Erreurs : 0
```

### Exécution tâche
```
## Tâche #<ID>

- Projet : <nom>
- Status : Complétée ✓
- Modèle : <model>
- Durée : <temps>
```
