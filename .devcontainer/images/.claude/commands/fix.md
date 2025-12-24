# Fix - Correction de bugs

$ARGUMENTS

---

## Description

Workflow complet pour corriger un bug avec **suivi Taskwarrior obligatoire** :
1. **PLAN MODE** → Analyse, reproduction, identification de la cause racine
2. **Validation utilisateur** → Approbation du plan avant correction
3. **BYPASS MODE** → Exécution des tasks de correction
4. **CI validation** → Vérifier que la pipeline passe
5. **PR sans merge** → Créer la PR, merge manuel requis

**Chaque action Write/Edit est tracée** et bloquée si aucune task Taskwarrior n'est en WIP.

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Nouveau fix avec ce nom |
| `--continue` | Reprendre le fix en cours (via session) |
| `--status` | Afficher le statut de la branche courante |
| `--pr` | Corriger les retours CodeRabbit de la PR (un par un) |
| `--help` | Affiche l'aide de la commande |

---

## --help

Quand `--help` est passé, afficher :

```
═══════════════════════════════════════════════
  /fix - Correction de bugs
═══════════════════════════════════════════════

Usage: /fix <description> [options]

Options:
  <description>     Nouveau fix avec ce nom
  --continue        Reprendre le fix en cours
  --status          Afficher le statut de la branche
  --pr              Corriger les retours CodeRabbit (un par un)
  --help            Affiche cette aide

Exemples:
  /fix login-error          Cree fix/login-error
  /fix --continue           Reprend la derniere session
  /fix --status             Affiche l'etat de la PR
  /fix --pr                 Corrige les commentaires CodeRabbit
═══════════════════════════════════════════════
```

---

## Workflow complet

### Étape 0 : Initialisation (OBLIGATOIRE)

**AVANT toute action**, initialiser le projet et la branche :

```bash
# Exécuter le script d'initialisation
/home/vscode/.claude/scripts/task-init.sh "fix" "<description>"

# Déterminer la branche principale
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Sync avec remote et créer la branche
git fetch origin
BRANCH="fix/$(echo "$DESCRIPTION" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
git checkout -b "$BRANCH" "origin/$MAIN_BRANCH"
```

**Output attendu :**
```
═══════════════════════════════════════════════
  ✓ Projet initialisé: <project-name>
═══════════════════════════════════════════════

  Mode: PLAN (analyse et définition des epics/tasks)

  Phases PLAN MODE:
    1. Analyse de la demande
    2. Recherche documentation
    3. Analyse projet existant
    4. Affûtage (boucle si nécessaire)
    5. Définition épics/tasks → VALIDATION
    6. Écriture Taskwarrior

  Après validation → BYPASS MODE (exécution)

  Branch: fix/<project-name>
  Session: $HOME/.claude/sessions/<project-name>.json
═══════════════════════════════════════════════
```

---

### Étape 1 : PLAN MODE (6 phases obligatoires)

**Mode actif** : PLAN (pas d'édition de code autorisée)

#### Phase 1 : Analyse de la demande
- Comprendre le bug reporté
- Identifier les étapes de reproduction

#### Phase 2 : Recherche documentation
- Rechercher des bugs similaires (issues, forums)
- Lire docs pertinentes

#### Phase 3 : Analyse projet existant
- Reproduire le bug
- Identifier le fichier et la ligne problématique
- Comprendre le flux de données

#### Phase 4 : Affûtage
- Identifier la cause racine
- Si manque info → retour Phase 2
- Définir la correction minimale

#### Phase 5 : Définition épics/tasks → VALIDATION USER

**Output attendu :**
```
## Bug identifié
- Description du comportement actuel
- Comportement attendu
- Cause racine: path/to/file.ts:42

## Plan de correction

Epic 1: Investigation
  ├─ Task 1.1: Créer test de reproduction [parallel:no]
  └─ Task 1.2: Identifier les dépendances [parallel:no]
Epic 2: Correction
  ├─ Task 2.1: Corriger le bug [parallel:no]
  └─ Task 2.2: Ajouter tests de non-régression [parallel:no]
```

**Chaque task doit avoir un contexte JSON :**
```json
{
  "files": ["src/auth.ts"],
  "action": "modify",
  "description": "Corriger la validation du token",
  "tests": ["src/__tests__/auth.test.ts"]
}
```

Puis `AskUserQuestion: "Valider ce plan de correction ?"`

#### Phase 6 : Écriture Taskwarrior

Après validation utilisateur :

```bash
SESSION_FILE=$(ls -t $HOME/.claude/sessions/*.json | head -1)
PROJECT=$(jq -r '.project' "$SESSION_FILE")

# Créer les epics
EPIC1_UUID=$(/home/vscode/.claude/scripts/task-epic.sh "$PROJECT" 1 "Investigation")
EPIC2_UUID=$(/home/vscode/.claude/scripts/task-epic.sh "$PROJECT" 2 "Correction")

# Créer les tasks
/home/vscode/.claude/scripts/task-add.sh "$PROJECT" 1 "$EPIC1_UUID" "Test de reproduction" "no" '{"files":["src/__tests__/bug.test.ts"],"action":"create"}'
/home/vscode/.claude/scripts/task-add.sh "$PROJECT" 2 "$EPIC2_UUID" "Corriger le bug" "no" '{"files":["src/auth.ts"],"action":"modify"}'

# Le mode passe automatiquement en bypass quand on démarre une task
```

---

### Étape 2 : BYPASS MODE (exécution)

**Mode actif** : BYPASS (édition autorisée SI task WIP)

#### Workflow par task

```bash
# 1. Démarrer la task (TODO → WIP)
/home/vscode/.claude/scripts/task-start.sh <uuid>

# 2. Exécuter la task
# - Lire le contexte JSON (files, action, description)
# - Effectuer les modifications requises
# - Chaque Write/Edit est automatiquement tracé

# 3. Commit conventionnel
git add <files>
git commit -m "fix(<scope>): <description>"
git push -u origin "$BRANCH"

# 4. Terminer la task (WIP → DONE)
/home/vscode/.claude/scripts/task-done.sh <uuid>

# 5. Passer à la task suivante
```

**Conventional Commits pour fix :**
- `fix(scope): message` - Correction du bug
- `test(scope): message` - Test de non-régression
- `docs(scope): message` - Documentation du fix

---

### Étape 3 : Sync avec main (si nécessaire)

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

### Étape 4 : Vérification CI

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

**2. CLI disponible :**
```bash
gh pr checks "$BRANCH"        # GitHub
glab mr view "$BRANCH"        # GitLab
```

#### En cas d'échec CI

1. Analyser les logs d'erreur
2. Identifier la cause (tests, lint, build, etc.)
3. Corriger le problème
4. Commit + push
5. Réessayer (max 3 tentatives)

---

### Étape 5 : Création PR

**Via MCP (priorité) :**
```
mcp__github__create_pull_request
mcp__gitlab__create_merge_request
```

**Via CLI (fallback) :**
```bash
gh pr create --title "fix: $DESCRIPTION" --body "..."
glab mr create --title "fix: $DESCRIPTION" --description "..."
```

**Format du body :**
```markdown
## Bug

<Description du bug corrigé>

## Root cause

<Explication de la cause>

## Fix

- `path/to/file.ts` : description de la correction

## Test plan

- [ ] Vérifier que le bug est corrigé
- [ ] Vérifier les non-régressions
```

---

## GARDE-FOUS (ABSOLUS)

### INTERDICTIONS

| Action | Status |
|--------|--------|
| Merge automatique | **INTERDIT** |
| Push sur main/master | **INTERDIT** |
| Skip PLAN MODE | **INTERDIT** |
| Write/Edit sans task WIP | **BLOQUÉ** |
| Force push sans --force-with-lease | **INTERDIT** |

### Message de fin

```
═══════════════════════════════════════════════
  ✓ Fix prêt !

  Branche : fix/<description>
  PR : https://github.com/<owner>/<repo>/pull/<number>
  CI : ✓ Passed

  ⚠️  MERGE MANUEL REQUIS
  → Le merge automatique est désactivé
  → Revue de code recommandée avant merge
═══════════════════════════════════════════════
```

---

## --continue

Reprendre un fix en cours via la session Taskwarrior :

```bash
SESSION_DIR="$HOME/.claude/sessions"

# Trouver la session la plus récente (ou spécifier un projet)
if [[ -n "$1" ]]; then
    SESSION_FILE="$SESSION_DIR/$1.json"
else
    SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)
fi

if [[ ! -f "$SESSION_FILE" ]]; then
    echo "❌ Aucune session trouvée"
    echo "→ Utilisez /fix <description> pour démarrer"
    exit 1
fi

PROJECT=$(jq -r '.project' "$SESSION_FILE")
BRANCH=$(jq -r '.branch' "$SESSION_FILE")
MODE=$(jq -r '.mode' "$SESSION_FILE")
CURRENT_EPIC=$(jq -r '.current_epic // "N/A"' "$SESSION_FILE")
CURRENT_TASK=$(jq -r '.current_task // "N/A"' "$SESSION_FILE")

echo "═══════════════════════════════════════════════"
echo "  Reprise: $PROJECT"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Mode: $MODE"
echo "  Epic courant: $CURRENT_EPIC"
echo "  Task courante: $CURRENT_TASK"
echo ""

# Afficher les epics et leur statut
echo "  Epics:"
jq -r '.epics[] | "    \(.id). \(.name) [\(.status)]"' "$SESSION_FILE" 2>/dev/null

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
```

---

## --pr : Correction des retours CodeRabbit

Workflow pour corriger les commentaires CodeRabbit sur une PR GitHub, **un par un** avec un commit par correction.

### Principe

```
1 commentaire CodeRabbit = 1 fix = 1 commit = 1 resolution
```

L'objectif est de traiter chaque retour de manière atomique pour :
- Tracer précisément chaque correction
- Permettre un rollback ciblé si nécessaire
- Faciliter la revue humaine

### Workflow détaillé

#### Étape 1 : Détection de la PR

```bash
# Obtenir les infos de la PR
gh pr view --json number,url,title,headRefName
```

Si pas de PR :
```
## Erreur

Aucune PR trouvée pour la branche actuelle.
→ Créer une PR avec: gh pr create
→ Ou demander une review avec: /review --pr
```

#### Étape 2 : Récupération des commentaires CodeRabbit

**Via MCP GitHub (prioritaire)** :
```
mcp__github__get_pull_request_comments({
  owner: "<org>",
  repo: "<repo>",
  pull_number: <pr_number>
})
```

**Via gh CLI (fallback)** :
```bash
gh api repos/<owner>/<repo>/pulls/<pr_number>/comments
```

**Filtrer les commentaires CodeRabbit** :
- `user.login` contient "coderabbit" ou "coderabbitai"
- Exclure les commentaires déjà résolus (outdated)
- Exclure les commentaires de type "summary" ou "praise"

#### Étape 3 : Affichage des retours à traiter

```
═══════════════════════════════════════════════
  CodeRabbit - Retours à corriger
═══════════════════════════════════════════════

PR : #<number> - <title>

Commentaires trouvés : <total>

  1. [<severity>] <file>:<line>
     → <résumé du commentaire>

  2. [<severity>] <file>:<line>
     → <résumé du commentaire>

  ...

═══════════════════════════════════════════════
```

Puis demander : "Commencer les corrections ? (oui/non/sélectionner)"

#### Étape 4 : Correction itérative (pour chaque commentaire)

**4.1 Afficher le commentaire complet :**
```
═══════════════════════════════════════════════
  Commentaire 1/<total>
═══════════════════════════════════════════════

Fichier : <file>
Ligne : <line>
Sévérité : <severity>

Commentaire CodeRabbit :
<contenu complet du commentaire>

Code actuel :
```<lang>
<extrait du code concerné>
```

Suggestion :
```<lang>
<code suggéré si présent>
```
═══════════════════════════════════════════════
```

**4.2 Appliquer la correction :**
- Lire le fichier concerné
- Appliquer la modification suggérée
- Respecter le style existant

**4.3 Commit atomique :**
```bash
git add <file>
git commit -m "fix(<scope>): apply CodeRabbit suggestion

<description courte de la correction>

Resolves CodeRabbit comment: <comment_id>"
```

**4.4 Résoudre le commentaire sur GitHub :**

**Via MCP GitHub (prioritaire)** :
```
mcp__github__add_issue_comment({
  owner: "<org>",
  repo: "<repo>",
  issue_number: <pr_number>,
  body: "@coderabbitai resolve <comment_id>"
})
```

**Alternative - Réponse au commentaire :**
```bash
gh api repos/<owner>/<repo>/pulls/comments/<comment_id>/replies \
  -f body="Fixed in commit <sha>. @coderabbitai resolve"
```

**4.5 Confirmation :**
```
═══════════════════════════════════════════════
  ✓ Commentaire 1/<total> corrigé
═══════════════════════════════════════════════

  Fichier : <file>
  Commit : <sha_court>
  Status : Résolu

  → Passage au commentaire suivant...
═══════════════════════════════════════════════
```

**4.6 Passer au commentaire suivant** ou terminer si c'était le dernier.

#### Étape 5 : Push et résumé final

```bash
git push origin <branch>
```

```
═══════════════════════════════════════════════
  ✓ Corrections CodeRabbit terminées
═══════════════════════════════════════════════

PR : #<number>
Commentaires traités : <n>/<total>
Commits créés : <n>

Résumé des corrections :
  ✓ <file1>:<line> - <description>
  ✓ <file2>:<line> - <description>
  ...

→ Les commentaires ont été marqués comme résolus
→ CodeRabbit refera une review automatique
═══════════════════════════════════════════════
```

### Gestion des cas particuliers

**Commentaire non applicable :**
Si le commentaire n'est pas pertinent ou déjà corrigé :
```
AskUserQuestion: "Ce commentaire semble déjà traité ou non applicable. Ignorer et résoudre ?"
```

Si oui, résoudre avec :
```
@coderabbitai resolve - Already addressed / Not applicable
```

**Erreur lors de la correction :**
```
## Erreur lors de la correction

Commentaire : <file>:<line>
Erreur : <message d'erreur>

Options :
  1. Réessayer
  2. Ignorer ce commentaire
  3. Arrêter les corrections
```

**Conflit potentiel :**
Si le fichier a changé depuis le commentaire :
```
⚠ Le fichier a été modifié depuis le commentaire
→ Vérifier manuellement si la correction est toujours applicable
```

---

## --status

Afficher le statut du fix :

```
## Statut : fix/<description>

| Élément | Status |
|---------|--------|
| Branche | fix/<description> |
| Mode | PLAN / BYPASS |
| Epics | 1/2 terminés |
| Tasks | 2/4 terminées |
| PR | #43 (open) |
| CI | ✓ Passed |
| Merge | En attente (manuel) |
```

---

## Outputs

### Initialisation
```
═══════════════════════════════════════════════
  /fix login-button-not-responding
═══════════════════════════════════════════════

✓ Branche créée : fix/login-button-not-responding
✓ Base : origin/main (abc1234)
✓ Mode : PLAN

→ Commencez par analyser le bug...
```

### Après validation du plan
```
═══════════════════════════════════════════════
  ✓ Plan validé - Passage en BYPASS MODE
═══════════════════════════════════════════════

  Epics créés: 2
  Tasks créées: 4

  Prochaine task:
    Epic 1: Investigation
    Task 1.1: Test de reproduction

  → Démarrer avec: task-start.sh <uuid>
═══════════════════════════════════════════════
```

### Après CI success
```
═══════════════════════════════════════════════
  ✓ Fix prêt !

  Branche : fix/login-button-not-responding
  Commits : 2
  PR : https://github.com/owner/repo/pull/43
  CI : ✓ Passed (1m 12s)

  ⚠️  MERGE MANUEL REQUIS
═══════════════════════════════════════════════
```
