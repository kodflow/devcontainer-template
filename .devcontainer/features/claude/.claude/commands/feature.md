# Feature - Développement de fonctionnalités

$ARGUMENTS

---

## Description

Workflow complet pour développer une nouvelle fonctionnalité avec **suivi Taskwarrior obligatoire** :
1. **Initialisation Taskwarrior** → Création projet avec 4 phases
2. **Plan obligatoire** → Explorer et planifier avant de coder
3. **Branche dédiée** → `feat/<description>`
4. **CI validation** → Vérifier que la pipeline passe
5. **PR sans merge** → Créer la PR, merge manuel requis

**Chaque action Write/Edit est tracée** et bloquée si aucune tâche Taskwarrior n'est active.

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Nouvelle feature avec ce nom |
| `--continue` | Reprendre la feature en cours (via session) |
| `--status` | Afficher le statut de la branche courante |

---

## Workflow complet

### Étape 0 : Initialisation Taskwarrior (OBLIGATOIRE)

**AVANT toute action**, initialiser le projet Taskwarrior :

```bash
# Exécuter le script d'initialisation
/workspace/.claude/scripts/task-init.sh "feat" "<description>"
```

Cela crée :
- **4 phases bloquantes** dans Taskwarrior :
  1. Planning (active)
  2. Implementation (bloquée → dépend de Phase 1)
  3. Testing (bloquée → dépend de Phase 2)
  4. PR (bloquée → dépend de Phase 3)
- **Session persistante** : `.claude/sessions/<project>.json`
- **UDAs configurés** : phase, model, parallel, branch

**Output attendu :**
```
═══════════════════════════════════════════════
  ✓ Projet créé: <project-name>
═══════════════════════════════════════════════

  Phases:
    1. Planning       [EN COURS]
    2. Implementation [BLOQUÉE]
    3. Testing        [BLOQUÉE]
    4. PR             [BLOQUÉE]

  Branch: feat/<project-name>
  Session: /workspace/.claude/sessions/<project-name>.json
═══════════════════════════════════════════════
```

---

### Étape 1 : Initialisation Git

```bash
# Déterminer la branche principale
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Sync avec remote
git fetch origin

# Créer la branche feature
BRANCH="feat/$(echo "$DESCRIPTION" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
git checkout -b "$BRANCH" "origin/$MAIN_BRANCH"

echo "✓ Branche créée : $BRANCH"
```

---

### Étape 2 : Mode Plan (Phase 1 - OBLIGATOIRE)

**Tâche Taskwarrior active** : `Phase 1: Planning - Explorer et planifier`

**AVANT toute implémentation**, utiliser `EnterPlanMode` :

1. Explorer le codebase pour comprendre l'existant
2. Identifier les fichiers à modifier
3. Créer un plan détaillé dans `/home/vscode/.claude/plans/`
4. Attendre validation utilisateur
5. `ExitPlanMode` pour commencer l'implémentation

**Format du plan :**
```markdown
# Plan : <feature-name>

## Fichiers à modifier
- path/to/file1.ts : description
- path/to/file2.ts : description

## Étapes d'implémentation
1. Étape 1
2. Étape 2
...

## Tests à ajouter
- Test 1
- Test 2
```

**Après validation du plan :**
```bash
# Marquer Phase 1 comme terminée
SESSION_FILE=$(ls -t /workspace/.claude/sessions/*.json | head -1)
TASK1_ID=$(jq -r '.phases["1"].id' "$SESSION_FILE")
task "$TASK1_ID" done

# Créer les sous-tâches depuis le plan
PROJECT=$(jq -r '.project' "$SESSION_FILE")
/workspace/.claude/scripts/task-subtasks.sh "$PROJECT" "$PLAN_FILE"

# Mettre à jour la session pour Phase 2
TASK2_UUID=$(jq -r '.phases["2"].uuid' "$SESSION_FILE")
jq ".current_phase = 2 | .current_task_uuid = \"$TASK2_UUID\"" "$SESSION_FILE" > tmp && mv tmp "$SESSION_FILE"
task uuid:"$TASK2_UUID" start
```

---

### Étape 3 : Implémentation (Phase 2)

**Tâche Taskwarrior active** : `Phase 2: Implementation`

Suivre le plan validé. **Chaque Write/Edit est automatiquement tracé** via les hooks.

Pour chaque modification significative :

```bash
# Commit conventionnel
git add <files>
git commit -m "feat(<scope>): <description>"

# Push régulier
git push -u origin "$BRANCH"

# Logger le commit dans Taskwarrior
TASK_UUID=$(jq -r '.current_task_uuid' "$SESSION_FILE")
task uuid:"$TASK_UUID" annotate "commit:{\"sha\":\"$(git rev-parse HEAD)\",\"msg\":\"feat(<scope>): <description>\"}"
```

**Conventional Commits :**
- `feat(scope): message` - Nouvelle fonctionnalité
- `test(scope): message` - Ajout de tests
- `docs(scope): message` - Documentation
- `refactor(scope): message` - Refactoring sans changement fonctionnel

**Fin de Phase 2 :**
```bash
# Marquer Phase 2 comme terminée
TASK2_ID=$(jq -r '.phases["2"].id' "$SESSION_FILE")
task "$TASK2_ID" done

# Passer à Phase 3
TASK3_UUID=$(jq -r '.phases["3"].uuid' "$SESSION_FILE")
jq ".current_phase = 3 | .current_task_uuid = \"$TASK3_UUID\"" "$SESSION_FILE" > tmp && mv tmp "$SESSION_FILE"
task uuid:"$TASK3_UUID" start
```

---

### Étape 4 : Sync avec main (si nécessaire)

Si des commits ont été ajoutés sur main pendant le développement :

```bash
git fetch origin "$MAIN_BRANCH"
git rebase "origin/$MAIN_BRANCH"

# Si conflits :
# 1. Résoudre les conflits
# 2. git add <resolved-files>
# 3. git rebase --continue

git push --force-with-lease
```

---

### Étape 5 : Vérification CI

#### Détection du provider Git

```bash
REMOTE=$(git remote get-url origin 2>/dev/null)

case "$REMOTE" in
    *github.com*)    PROVIDER="github" ;;
    *gitlab.com*)    PROVIDER="gitlab" ;;
    *bitbucket.org*) PROVIDER="bitbucket" ;;
    *)               PROVIDER="unknown" ;;
esac
```

#### Vérification du statut (ordre de priorité)

**1. MCP connecté :**
```
mcp__github__get_pull_request_status (si GitHub)
mcp__gitlab__get_merge_request (si GitLab)
```

**2. Token dans l'environnement :**
| Provider | Variables à chercher |
|----------|---------------------|
| GitHub | `GITHUB_TOKEN`, `GH_TOKEN`, `GITHUB_PERSONAL_ACCESS_TOKEN` |
| GitLab | `GITLAB_TOKEN`, `GITLAB_PRIVATE_TOKEN`, `CI_JOB_TOKEN` |
| Bitbucket | `BITBUCKET_TOKEN`, `BITBUCKET_ACCESS_TOKEN` |

**3. CLI disponible :**
```bash
gh pr checks "$BRANCH"        # GitHub
glab mr view "$BRANCH"        # GitLab
```

**4. Curl direct :**
```bash
# GitHub
curl -s "https://api.github.com/repos/$OWNER/$REPO/commits/$SHA/status"

# GitLab
curl -s "https://gitlab.com/api/v4/projects/$PROJECT_ID/pipelines?ref=$BRANCH"
```

#### En cas d'échec CI

1. Analyser les logs d'erreur
2. Identifier la cause (tests, lint, build, etc.)
3. Corriger le problème
4. Commit + push
5. Réessayer (max 3 tentatives)

```
Tentative 1/3 : Analyse de l'erreur...
→ Erreur : test_login failed
→ Fix : correction du mock
→ Commit + push
→ Vérification CI...
```

---

### Étape 6 : Création PR

**Via MCP (priorité) :**
```
mcp__github__create_pull_request
mcp__gitlab__create_merge_request
```

**Via CLI (fallback) :**
```bash
gh pr create --title "feat: $DESCRIPTION" --body "..."
glab mr create --title "feat: $DESCRIPTION" --description "..."
```

**Format du body :**
```markdown
## Summary
- <Point 1>
- <Point 2>

## Changes
- `path/to/file1.ts` : description
- `path/to/file2.ts` : description

## Test plan
- [ ] Test 1
- [ ] Test 2
```

---

## GARDE-FOUS (ABSOLUS)

### INTERDICTIONS

| Action | Status |
|--------|--------|
| Merge automatique | ❌ **INTERDIT** |
| Push sur main/master | ❌ **INTERDIT** |
| Skip le mode /plan | ❌ **INTERDIT** |
| Force push sans --force-with-lease | ❌ **INTERDIT** |

### Message de fin

```
═══════════════════════════════════════════════
  ✓ Feature prête !

  Branche : feat/<description>
  PR : https://github.com/<owner>/<repo>/pull/<number>
  CI : ✓ Passed

  ⚠️  MERGE MANUEL REQUIS
  → Le merge automatique est désactivé
  → Revue de code recommandée avant merge
═══════════════════════════════════════════════
```

---

## --continue

Reprendre une feature en cours via la session Taskwarrior :

```bash
SESSION_DIR="/workspace/.claude/sessions"

# Trouver la session la plus récente (ou spécifier un projet)
# Usage: /feature --continue [project_name]
if [[ -n "$1" ]]; then
    SESSION_FILE="$SESSION_DIR/$1.json"
else
    SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)
fi

if [[ ! -f "$SESSION_FILE" ]]; then
    echo "❌ Aucune session trouvée"
    echo "→ Utilisez /feature <description> pour démarrer"
    exit 1
fi

PROJECT=$(jq -r '.project' "$SESSION_FILE")
BRANCH=$(jq -r '.branch' "$SESSION_FILE")
CURRENT_PHASE=$(jq -r '.current_phase' "$SESSION_FILE")
CURRENT_UUID=$(jq -r '.current_task_uuid' "$SESSION_FILE")
ACTIONS=$(jq -r '.actions' "$SESSION_FILE")
LAST_ACTION=$(jq -r '.last_action // "N/A"' "$SESSION_FILE")

echo "═══════════════════════════════════════════════"
echo "  Reprise: $PROJECT"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Phase courante: $CURRENT_PHASE"
echo "  Actions effectuées: $ACTIONS"
echo "  Dernière action: $LAST_ACTION"
echo ""

# Afficher les derniers événements depuis Taskwarrior
echo "  Derniers événements:"
task uuid:"$CURRENT_UUID" annotations 2>/dev/null | grep -E "^[0-9]" | tail -5 | while read -r LINE; do
    echo "    $LINE"
done

echo ""
echo "═══════════════════════════════════════════════"

# Vérifier la branche git
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [[ "$CURRENT_BRANCH" != "$BRANCH" ]]; then
    echo ""
    echo "⚠ Branche actuelle: $CURRENT_BRANCH"
    echo "→ Branche attendue: $BRANCH"
    echo "→ Exécuter: git checkout $BRANCH"
fi

# Relancer la tâche
task uuid:"$CURRENT_UUID" start 2>/dev/null || true
```

**Récupération après crash :**

Le système permet de reprendre grâce à :
1. **Session persistante** : `.claude/sessions/<project>.json`
2. **Annotations Taskwarrior** : Chaque action loggée avec timestamp
3. **Double source de vérité** : Comparaison session ↔ annotations

```bash
# Voir l'état d'un projet
task project:<name> all

# Voir les événements d'une tâche
task uuid:<uuid> annotations

# Exporter les événements en JSON
task project:<name> export | jq '.[].annotations'
```

---

## --status

Afficher le statut de la feature :

```
## Statut : feat/<description>

| Élément | Status |
|---------|--------|
| Branche | feat/<description> |
| Commits | 5 ahead of main |
| PR | #42 (open) |
| CI | ✓ Passed |
| Merge | En attente (manuel) |
```

---

## Outputs

### Initialisation
```
═══════════════════════════════════════════════
  /feature add-user-authentication
═══════════════════════════════════════════════

✓ Branche créée : feat/add-user-authentication
✓ Base : origin/main (abc1234)

→ Passage en mode /plan obligatoire...
```

### Après CI success
```
═══════════════════════════════════════════════
  ✓ Feature prête !

  Branche : feat/add-user-authentication
  Commits : 3
  PR : https://github.com/owner/repo/pull/42
  CI : ✓ Passed (2m 34s)

  ⚠️  MERGE MANUEL REQUIS
═══════════════════════════════════════════════
```

### Après CI fail (avec retry)
```
═══════════════════════════════════════════════
  CI Failed - Tentative 1/3
═══════════════════════════════════════════════

Erreur détectée :
  Job : test
  Message : FAIL src/auth/login.test.ts

Analyse :
  → Mock manquant pour userService

Correction appliquée :
  → Ajout du mock dans login.test.ts

Commit : fix(test): add missing userService mock
Push : origin/feat/add-user-authentication

→ Relance CI...
```
