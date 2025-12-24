# Review - AI Code Review avec CodeRabbit

$ARGUMENTS

---

## Description

Effectue une revue de code automatisee avec CodeRabbit CLI. Detecte les bugs, vulnerabilites, problemes de performance et suggere des corrections.

---

## Arguments

| Pattern | Action |
|---------|--------|
| (vide) | Review des changements non commites |
| `--staged` | Review uniquement des changements stages |
| `--committed` | Review des changements commites (vs base branch) |
| `--all` | Review complete du projet |
| `--fix` | Applique les corrections suggerees |
| `--pr` | Declenche une full review CodeRabbit sur la PR GitHub |
| `--help` | Affiche l'aide de la commande |

---

## --help

Quand `--help` est passe, afficher :

```
═══════════════════════════════════════════════
  /review - AI Code Review avec CodeRabbit
═══════════════════════════════════════════════

Usage: /review [options]

Options:
  (vide)          Review des changements non commites
  --staged        Review uniquement des changements stages
  --committed     Review des changements commites (vs base)
  --all           Review complete du projet
  --fix           Applique les corrections suggerees
  --pr            Full review CodeRabbit sur la PR GitHub
  --help          Affiche cette aide

Exemples:
  /review                 Review des modifications locales
  /review --staged        Review avant commit
  /review --committed     Review de la branche actuelle
  /review --fix           Review et applique les corrections
  /review --pr            Full review sur la PR courante
═══════════════════════════════════════════════
```

---

## Prerequis

### Verification de l'installation

```bash
command -v coderabbit || command -v cr
```

Si non installe :
```
## Erreur

CodeRabbit CLI n'est pas installe.
→ Rebuilder le container ou executer: curl -fsSL https://cli.coderabbit.ai/install.sh | sh
```

### Verification de l'authentification

```bash
coderabbit auth status 2>/dev/null || cr auth status 2>/dev/null
```

Si non authentifie :
```
## Authentification requise

CodeRabbit necessite une authentification.
→ Executer: coderabbit auth login (ou cr auth login)
→ Suivre les instructions dans le navigateur
```

---

## Workflow principal

### 1. Detection du contexte

```bash
# Verifier les changements
git status --porcelain
git diff --stat
git diff --cached --stat
```

Si aucun changement et pas `--all` :
```
## Aucun changement

Aucun fichier modifie a analyser.
→ Utilisez --all pour analyser tout le projet
```

### 2. Construction de la commande

**Base** : `coderabbit --plain`

**Options additionnelles** :

| Argument | Options ajoutees |
|----------|------------------|
| (vide) | `--type uncommitted` |
| `--staged` | `--type uncommitted` (analyse le cache git) |
| `--committed` | `--type committed` |
| `--all` | `--type all` |

**Configuration auto** :
```bash
# Si CLAUDE.md existe, l'utiliser comme contexte
if [[ -f "/workspace/CLAUDE.md" ]]; then
    CONFIG_OPT="--config /workspace/CLAUDE.md"
fi
```

### 3. Execution de la review

```bash
# Commande complete
coderabbit --plain $TYPE_OPT $CONFIG_OPT 2>&1
```

### 4. Traitement des resultats

Afficher les resultats avec mise en forme :

```
═══════════════════════════════════════════════
  Review CodeRabbit
═══════════════════════════════════════════════

[Resultats de la review]

═══════════════════════════════════════════════
  Resume
═══════════════════════════════════════════════

Fichiers analyses : X
Problemes trouves : Y
  - Critiques : Z
  - Warnings : W
  - Info : I

═══════════════════════════════════════════════
```

---

## --fix : Application des corrections

Quand `--fix` est passe :

1. Executer la review normale
2. Parser les suggestions de correction
3. Pour chaque correction suggeree :
   - Afficher le fichier et la ligne
   - Afficher le code actuel vs suggere
   - Appliquer la correction automatiquement
4. Afficher un resume des corrections appliquees

```bash
# Note: CodeRabbit --fix n'existe pas nativement
# Le mode --fix analyse les suggestions et les applique via Edit
```

**Workflow --fix** :

1. Capturer la sortie de `coderabbit --plain`
2. Parser les blocs de code suggeres
3. Appliquer les modifications avec l'outil Edit
4. Afficher le resume

```
═══════════════════════════════════════════════
  Corrections appliquees
═══════════════════════════════════════════════

| Fichier | Ligne | Type | Status |
|---------|-------|------|--------|
| src/api.ts | 42 | Bug fix | ✓ Applique |
| src/auth.ts | 15 | Security | ✓ Applique |

Total : 2 corrections appliquees
═══════════════════════════════════════════════
```

---

## Outputs

### Succes

```
═══════════════════════════════════════════════
  ✓ Review terminee
═══════════════════════════════════════════════

Fichiers analyses : 5
Problemes trouves : 3
  - Critiques : 1
  - Warnings : 2
  - Info : 0

→ Voir les details ci-dessus
═══════════════════════════════════════════════
```

### Aucun probleme

```
═══════════════════════════════════════════════
  ✓ Aucun probleme detecte
═══════════════════════════════════════════════

Fichiers analyses : 5
Code quality : Excellent

→ Pret pour commit/PR
═══════════════════════════════════════════════
```

### Erreur

```
═══════════════════════════════════════════════
  ✗ Erreur lors de la review
═══════════════════════════════════════════════

Message : [erreur de coderabbit]

→ Verifier l'authentification : cr auth status
→ Verifier la connexion internet
═══════════════════════════════════════════════
```

---

## --pr : Full Review sur PR GitHub

Quand `--pr` est passe :

### 1. Detection de la PR

```bash
# Obtenir le numero de PR via gh CLI
gh pr view --json number,url,state
```

Si pas de PR associee a la branche :
```
## Erreur

Aucune PR trouvee pour la branche actuelle.
→ Creer une PR avec: gh pr create
→ Ou utiliser /review sans --pr pour une review locale
```

### 2. Poster le commentaire CodeRabbit

Utiliser l'outil MCP GitHub (prioritaire) ou gh CLI :

**Via MCP (prioritaire)** :
```
mcp__github__add_issue_comment({
  owner: "<org>",
  repo: "<repo>",
  issue_number: <pr_number>,
  body: "@coderabbitai full review"
})
```

**Via gh CLI (fallback)** :
```bash
gh pr comment <pr_number> --body "@coderabbitai full review"
```

### 3. Confirmation

```
═══════════════════════════════════════════════
  ✓ Full Review CodeRabbit declenchee
═══════════════════════════════════════════════

PR : #<number> - <title>
URL : <pr_url>

→ CodeRabbit va analyser tous les fichiers de la PR
→ Les commentaires apparaitront sur la PR GitHub
→ Utilisez /fix --pr pour corriger les retours un par un
═══════════════════════════════════════════════
```

---

## Integration avec autres commandes

| Workflow | Commandes |
|----------|-----------|
| Avant commit | `/review --staged` puis `/commit` |
| Apres dev | `/review` puis `/review --fix` puis `/commit` |
| PR review locale | `/review --committed` |
| PR review GitHub | `/review --pr` puis `/fix --pr` |
| Audit complet | `/review --all` |
