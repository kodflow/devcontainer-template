# Fix - Correction de bugs

$ARGUMENTS

---

## Description

Workflow complet pour corriger un bug :
1. **Plan obligatoire** → Analyser et planifier la correction
2. **Branche dédiée** → `fix/<description>`
3. **CI validation** → Vérifier que la pipeline passe
4. **PR sans merge** → Créer la PR, merge manuel requis

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<description>` | Nouveau fix avec ce nom |
| `--continue` | Reprendre le fix en cours |
| `--status` | Afficher le statut de la branche courante |

---

## Workflow complet

### Étape 1 : Initialisation

```bash
# Déterminer la branche principale
MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

# Sync avec remote
git fetch origin

# Créer la branche fix
BRANCH="fix/$(echo "$DESCRIPTION" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')"
git checkout -b "$BRANCH" "origin/$MAIN_BRANCH"

echo "✓ Branche créée : $BRANCH"
```

---

### Étape 2 : Mode Plan (OBLIGATOIRE)

**AVANT toute correction**, utiliser `EnterPlanMode` :

1. Reproduire et comprendre le bug
2. Identifier la cause racine
3. Créer un plan de correction dans `/home/vscode/.claude/plans/`
4. Attendre validation utilisateur
5. `ExitPlanMode` pour commencer la correction

**Format du plan :**
```markdown
# Plan : fix-<bug-name>

## Bug identifié
- Description du comportement actuel
- Comportement attendu
- Étapes de reproduction

## Cause racine
- Fichier : path/to/file.ts
- Ligne(s) : 42-45
- Problème : description

## Correction proposée
1. Modifier X dans Y
2. Ajouter test pour Z

## Tests de non-régression
- Test 1
- Test 2
```

---

### Étape 3 : Implémentation

Suivre le plan validé. Pour chaque modification :

```bash
# Commit conventionnel
git add <files>
git commit -m "fix(<scope>): <description>"

# Push régulier
git push -u origin "$BRANCH"
```

**Conventional Commits :**
- `fix(scope): message` - Correction du bug
- `test(scope): message` - Test de non-régression
- `docs(scope): message` - Documentation du fix

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

---

### Étape 6 : Création PR

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
| Merge automatique | ❌ **INTERDIT** |
| Push sur main/master | ❌ **INTERDIT** |
| Skip le mode /plan | ❌ **INTERDIT** |
| Force push sans --force-with-lease | ❌ **INTERDIT** |

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

Reprendre un fix en cours :

```bash
# Vérifier la branche courante
CURRENT=$(git branch --show-current)

if [[ "$CURRENT" == fix/* ]]; then
    echo "Fix en cours : $CURRENT"
    # Continuer le workflow depuis l'étape appropriée
else
    echo "Aucun fix en cours. Utiliser /fix <description>"
fi
```

---

## --status

Afficher le statut du fix :

```
## Statut : fix/<description>

| Élément | Status |
|---------|--------|
| Branche | fix/<description> |
| Commits | 2 ahead of main |
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

→ Passage en mode /plan obligatoire...
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
