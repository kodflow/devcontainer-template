# Plan - Infrastructure as Code Planning

$ARGUMENTS

---

## Description

Commande de planification façon Terraform. Crée un état déterministe dans Taskwarrior :
- Analyse complète (6 phases)
- Génération des epics/tasks
- État reproductible et versionné

**Comportement intelligent :**
- **Sur `main`** → Création automatique de branche (pas de question)
- **`/plan` répété** → Met à jour le plan existant (affinage itératif)

**Workflow** : `/plan <desc>` → (affiner) → `/plan` → validation → `/apply`

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Nouveau plan OU mise à jour du plan existant |
| `--fix` | Mode bugfix (branche fix/ au lieu de feat/) |
| `--status` | Afficher l'état du plan actuel |
| `--destroy` | Abandonner le plan et nettoyer |
| `--help` | Affiche l'aide |

---

## --help

Quand `--help` est passé, afficher :

```
═══════════════════════════════════════════════
  /plan - Infrastructure as Code Planning
═══════════════════════════════════════════════

Usage: /plan <description> [options]

Options:
  <description>     Nouveau plan ou mise à jour
  --fix             Mode bugfix (branche fix/)
  --status          Afficher l'état du plan
  --destroy         Abandonner et nettoyer
  --help            Affiche cette aide

Comportement:
  Sur main          → Crée branche automatiquement
  /plan répété      → Met à jour le plan existant

Exemples:
  /plan add-auth            Nouveau plan feature
  /plan                     Affiner le plan en cours
  /plan login-bug --fix     Nouveau plan bugfix
  /plan --status            Voir l'état

Workflow:
  /plan <desc> → /plan (affiner) → /apply
═══════════════════════════════════════════════
```

---

## Concept : État déterministe

Comme Terraform, `/plan` produit un état reproductible :

```
Session JSON = État du plan (comme terraform.tfstate)
Taskwarrior  = Ressources déclarées (comme les resources TF)
/apply       = Application de l'état (comme terraform apply)
```

### Fichier de session

```json
{
  "schemaVersion": 2,
  "state": "planned",
  "type": "feature|fix",
  "project": "<project-name>",
  "branch": "feat/<name>|fix/<name>",
  "createdAt": "2024-01-01T00:00:00Z",
  "epics": [
    {
      "id": 1,
      "uuid": "<uuid>",
      "name": "Epic name",
      "status": "TODO|WIP|DONE",
      "tasks": [
        {
          "id": "T1.1",
          "uuid": "<uuid>",
          "name": "Task name",
          "status": "TODO|WIP|DONE",
          "parallel": "yes|no",
          "ctx": { "files": [], "action": "create" }
        }
      ]
    }
  ]
}
```

### États possibles

| State | Description | Transition |
|-------|-------------|------------|
| `planning` | En cours d'analyse | → `planned` |
| `planned` | Prêt pour /apply | → `applying` |
| `applying` | Exécution en cours | → `applied` |
| `applied` | Terminé (PR créée) | FIN |

---

## Comportement automatique

### Détection du contexte

```bash
CURRENT_BRANCH=$(git branch --show-current)
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
SESSION_FILE=$(ls -t $HOME/.claude/sessions/*.json 2>/dev/null | head -1)
```

### Arbre de décision

```
/plan <desc>
     │
     ├── Sur main/master ?
     │   └── OUI → Créer branche + nouveau plan
     │
     ├── Session existante (état planning|planned) ?
     │   └── OUI → Mettre à jour le plan existant
     │
     └── Sur branche feat/fix sans session ?
         └── Créer session pour branche existante
```

| Contexte | Action | Résultat |
|----------|--------|----------|
| Sur `main`, pas de session | Créer branche + plan | Nouveau projet |
| Sur `main`, session existe | Reprendre le plan | Continue session |
| Sur `feat/*`, session existe | Affiner le plan | Update epics/tasks |
| Sur `feat/*`, pas de session | Créer session | Adopte la branche |

### Mise à jour du plan (itératif)

Quand `/plan` est appelé avec un plan existant :

1. **Charger l'état actuel** depuis la session
2. **Comparer** avec les nouvelles instructions
3. **Mettre à jour** les epics/tasks :
   - Ajouter les nouvelles tasks
   - Modifier les tasks existantes (si pas DONE)
   - Marquer obsolètes (ne pas supprimer)
4. **Re-valider** avec l'utilisateur

**Output mise à jour :**
```
═══════════════════════════════════════════════
  /plan - Mise à jour du plan
═══════════════════════════════════════════════

  Plan existant détecté : <project>
  State : planning

─────────────────────────────────────────────
  Changements proposés
─────────────────────────────────────────────

  Epic 1: Setup (inchangé)
    ├─ T1.1 [DONE] Create structure
    └─ T1.2 [TODO] Configure deps

  Epic 2: Implementation (modifié)
    ├─ T2.1 [TODO] AuthService (modifié)
    ├─ T2.2 [NEW]  Add validation    ← NOUVEAU
    └─ T2.3 [TODO] Write tests

─────────────────────────────────────────────

  + 1 nouvelle task
  ~ 1 task modifiée
  = 3 tasks inchangées

═══════════════════════════════════════════════
```

---

## Workflow complet

### Étape 0 : Initialisation

```bash
CURRENT_BRANCH=$(git branch --show-current)
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
SESSION_FILE=$(ls -t $HOME/.claude/sessions/*.json 2>/dev/null | head -1)

# CAS 1 : Sur main → Créer nouvelle branche (AUTOMATIQUE, LOCAL)
if [[ "$CURRENT_BRANCH" == "$MAIN_BRANCH" || "$CURRENT_BRANCH" == "master" ]]; then
    TYPE="${HAS_FIX:+fix}" || "feature"
    PREFIX="${TYPE:0:4}"
    BRANCH="$PREFIX/$(echo "$DESCRIPTION" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"

    # LOCAL ONLY: Création depuis refs/heads/main (pas de fetch)
    # Note: La branche est créée depuis le main local, point.
    git checkout -b "$BRANCH" "$MAIN_BRANCH"

    /home/vscode/.claude/scripts/task-init.sh "$TYPE" "<description>"
fi

# CAS 2 : Session existante → Mise à jour du plan
if [[ -f "$SESSION_FILE" ]]; then
    STATE=$(jq -r '.state' "$SESSION_FILE")
    if [[ "$STATE" == "planning" || "$STATE" == "planned" ]]; then
        # Mode mise à jour
        echo "Plan existant détecté, mise à jour..."
    fi
fi

# CAS 3 : Sur branche sans session → Créer session
if [[ ! -f "$SESSION_FILE" && "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]]; then
    TYPE=$([[ "$CURRENT_BRANCH" == fix/* ]] && echo "fix" || echo "feature")
    /home/vscode/.claude/scripts/task-init.sh "$TYPE" "${CURRENT_BRANCH#*/}"
fi
```

**Output nouveau plan :**
```
═══════════════════════════════════════════════
  /plan <description>
═══════════════════════════════════════════════

  Type    : feature
  Branch  : feat/<description>  ← créée automatiquement
  State   : planning
  Session : ~/.claude/sessions/<project>.json

─────────────────────────────────────────────
  Phases de planification
─────────────────────────────────────────────

  [ ] 1. Analyse de la demande
  [ ] 2. Recherche documentation
  [ ] 3. Analyse projet existant
  [ ] 4. Affûtage
  [ ] 5. Définition épics/tasks
  [ ] 6. Écriture Taskwarrior

  → Commencer l'analyse...

═══════════════════════════════════════════════
```

---

### Étape 1 : PLAN MODE (6 phases)

**INTERDIT en PLAN MODE :**
- ❌ Write/Edit sur fichiers code
- ❌ Bash modifiant l'état du projet
- ✅ Write/Edit sur `/plans/` uniquement

#### Phase 1 : Analyse de la demande
- Comprendre ce que l'utilisateur veut
- Identifier contraintes et exigences
- Pour un fix : identifier les étapes de reproduction

#### Phase 2 : Recherche documentation
- WebSearch pour APIs/libs externes
- Lire docs existantes du projet
- Pour un fix : rechercher bugs similaires

#### Phase 3 : Analyse projet existant
- Glob/Grep pour trouver code existant
- Read fichiers pertinents
- Comprendre patterns/architecture
- Pour un fix : reproduire le bug

#### Phase 4 : Affûtage
- Croiser infos (demande + docs + existant)
- Si manque info → retour Phase 2
- Identifier tous les fichiers à modifier
- Pour un fix : identifier la cause racine

#### Phase 5 : Définition épics/tasks → VALIDATION

**Output attendu :**
```
═══════════════════════════════════════════════
  Plan généré
═══════════════════════════════════════════════

Epic 1: <nom>
  ├─ T1.1: <description> [parallel:no]
  │        files: [src/api.ts]
  │        action: create
  ├─ T1.2: <description> [parallel:yes]
  └─ T1.3: <description> [parallel:yes]

Epic 2: <nom>
  ├─ T2.1: <description> [parallel:no]
  └─ T2.2: <description> [parallel:no]

─────────────────────────────────────────────
  Résumé
─────────────────────────────────────────────

  Epics  : 2
  Tasks  : 5
  Files  : 8 fichiers modifiés

═══════════════════════════════════════════════
```

Puis **obligatoire** :
```
AskUserQuestion: "Valider ce plan ?"
```

#### Phase 6 : Écriture Taskwarrior

Après validation utilisateur :

```bash
SESSION_FILE=$(ls -t $HOME/.claude/sessions/*.json | head -1)
PROJECT=$(jq -r '.project' "$SESSION_FILE")

# Créer les epics
/home/vscode/.claude/scripts/task-epic.sh "$PROJECT" 1 "Epic 1 name"
/home/vscode/.claude/scripts/task-epic.sh "$PROJECT" 2 "Epic 2 name"

# Créer les tasks
/home/vscode/.claude/scripts/task-add.sh "$PROJECT" 1 "<uuid>" "Task name" "no" '{"files":["..."],"action":"..."}'

# Mettre à jour l'état
jq '.state = "planned"' "$SESSION_FILE" > tmp && mv tmp "$SESSION_FILE"
```

**Output final :**
```
═══════════════════════════════════════════════
  ✓ Plan enregistré
═══════════════════════════════════════════════

  State   : planned
  Epics   : 2
  Tasks   : 5

  Le plan est prêt. Pour l'exécuter :

    /apply

  Pour voir le plan :

    /plan --status

═══════════════════════════════════════════════
```

---

## --fix

Identique au workflow standard mais avec :
- Branche `fix/<name>` au lieu de `feat/<name>`
- Commit prefix `fix(scope):` au lieu de `feat(scope):`
- PR body format "Bug / Root cause / Fix" au lieu de "Summary / Changes"

```bash
/home/vscode/.claude/scripts/task-init.sh "fix" "<description>"
```

---

## --status

Afficher l'état complet du plan :

```
═══════════════════════════════════════════════
  État du plan
═══════════════════════════════════════════════

  Project : <name>
  Type    : feature|fix
  State   : planning|planned|applying|applied
  Branch  : <branch>

─────────────────────────────────────────────
  Epics
─────────────────────────────────────────────

  1. [DONE] Setup infrastructure
     ├─ T1.1 [DONE] Create folder structure
     └─ T1.2 [DONE] Configure dependencies

  2. [WIP] Implementation
     ├─ T2.1 [DONE] Implement AuthService
     ├─ T2.2 [WIP]  Add validation
     └─ T2.3 [TODO] Write tests

─────────────────────────────────────────────
  Progression
─────────────────────────────────────────────

  Tasks    : 3/5 (60%)
  ████████████░░░░░░░░

═══════════════════════════════════════════════
```

---

## --destroy (safe, local only)

Abandonner le plan et nettoyer **localement** :

**Pré-conditions :**
- ❌ INTERDIT si `state=applying` (exécution en cours)
- ✅ Confirmation utilisateur obligatoire

```bash
SESSION_FILE=$(ls -t $HOME/.claude/sessions/*.json | head -1)
PROJECT=$(jq -r '.project' "$SESSION_FILE")
BRANCH=$(jq -r '.branch' "$SESSION_FILE")
STATE=$(jq -r '.state' "$SESSION_FILE")
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Bloquer si applying
if [[ "$STATE" == "applying" ]]; then
    echo "❌ Impossible de détruire un plan en cours d'exécution"
    echo "→ Terminez d'abord les tasks en cours ou attendez /apply"
    exit 1
fi

# Demander confirmation
AskUserQuestion: "Abandonner le plan et supprimer la branche locale $BRANCH ?"
```

**Actions (après confirmation) :**
```bash
# Nettoyer LOCALEMENT (jamais de push)
git checkout "$MAIN_BRANCH"
git branch -D "$BRANCH"
rm "$SESSION_FILE"

# Archiver tasks Taskwarrior (pas delete, juste status:deleted)
task project:"$PROJECT" rc.confirmation=off modify status:deleted
```

**Ce qui n'est PAS fait (local only) :**
- ❌ Pas de `git push origin --delete` (branche remote intacte)
- ❌ Pas de suppression définitive des tasks (archivées)

**Output :**
```
═══════════════════════════════════════════════
  ✓ Plan abandonné (local)
═══════════════════════════════════════════════

  Branche locale supprimée : <branch>
  Session supprimée        : <file>
  Tasks archivées          : <count>

  Note: La branche remote n'est pas supprimée.
  Pour la supprimer manuellement:
    git push origin --delete <branch>

═══════════════════════════════════════════════
```

---

## GARDE-FOUS (ABSOLUS)

| Action | Status |
|--------|--------|
| Write/Edit code en PLAN MODE | ❌ **BLOQUÉ** |
| Skip validation utilisateur | ❌ **INTERDIT** |
| Modifier Taskwarrior sans validation | ❌ **INTERDIT** |
| Passer à /apply sans état "planned" | ❌ **BLOQUÉ** |

---

## Voir aussi

- `/apply` - Exécuter le plan
- `/review` - Demander une code review
- `/git --commit` - Commit manuel

