# Conventions

## Commits

Format : `type(scope): message`

| Type | Usage |
|------|-------|
| `feat` | Nouvelle fonctionnalité |
| `fix` | Correction de bug |
| `docs` | Documentation |
| `refactor` | Restructuration sans changement fonctionnel |
| `test` | Ajout ou modification de tests |
| `chore` | Maintenance (CI, deps, config) |
| `perf` | Optimisation de performance |

Le scope est déduit du répertoire principal modifié. Exemples : `feat(auth): add JWT login`, `fix(api): handle timeout error`.

## Branches

| Préfixe | Usage |
|---------|-------|
| `feat/` | Nouvelle fonctionnalité |
| `fix/` | Correction de bug |
| `docs/` | Documentation |
| `refactor/` | Restructuration |

Ne jamais committer directement sur `main`. Toujours passer par une branche + PR.

## Stratégie de merge

Squash merge par défaut. GitHub supprime automatiquement la branche distante après le merge.

## Structure du code

| Répertoire | Contenu |
|------------|---------|
| `src/` | Tout le code source (obligatoire) |
| `tests/` | Tests unitaires (Go : à côté du code dans `src/`) |
| `docs/` | Documentation |
| `.devcontainer/` | Configuration du container |

## Makefile

Les hooks de qualité cherchent d'abord un target Makefile avant d'utiliser les outils directement :

| Target | Usage |
|--------|-------|
| `make fmt` / `make format` | Formatage du code |
| `make lint` | Linting |
| `make typecheck` | Vérification de types |
| `make test` | Tests |

Si votre projet a un Makefile avec ces targets, les hooks l'utilisent. Sinon, ils détectent le langage et lancent l'outil correspondant.

## Fichiers protégés

Les hooks Claude empêchent la modification accidentelle de :

- `.devcontainer/` — configuration container
- `.claude/scripts/` — scripts hooks
- `.env` — variables d'environnement
- `node_modules/`, `vendor/` — dépendances
- `*.lock` — fichiers de lock

Pour forcer une modification : `ALLOW_PROTECTED_EDIT=1`.
