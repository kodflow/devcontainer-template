# Feature - Développement de fonctionnalités

$ARGUMENTS

---

## Description

Workflow complet pour développer une nouvelle fonctionnalité :
1. **Plan obligatoire** → Explorer et planifier avant de coder
2. **Branche dédiée** → `feat/<description>`
3. **CI validation** → Vérifier que la pipeline passe
4. **PR sans merge** → Créer la PR, merge manuel requis

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Nouvelle feature avec ce nom |
| `--continue` | Reprendre la feature en cours |
| `--status` | Afficher le statut de la branche courante |

---

## Workflow complet

### Étape 1 : Initialisation

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

### Étape 2 : Mode Plan (OBLIGATOIRE)

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

---

### Étape 3 : Implémentation

Suivre le plan validé. Pour chaque modification significative :

```bash
# Commit conventionnel
git add <files>
git commit -m "feat(<scope>): <description>"

# Push régulier
git push -u origin "$BRANCH"
```

**Conventional Commits :**
- `feat(scope): message` - Nouvelle fonctionnalité
- `test(scope): message` - Ajout de tests
- `docs(scope): message` - Documentation
- `refactor(scope): message` - Refactoring sans changement fonctionnel

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

Reprendre une feature en cours :

```bash
# Vérifier la branche courante
CURRENT=$(git branch --show-current)

if [[ "$CURRENT" == feat/* ]]; then
    echo "Feature en cours : $CURRENT"
    # Continuer le workflow depuis l'étape appropriée
else
    echo "Aucune feature en cours. Utiliser /feature <description>"
fi
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
