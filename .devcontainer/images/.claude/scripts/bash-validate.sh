#!/bin/bash
# bash-validate.sh - PreToolUse hook pour Bash
# Vérifie que les commandes bash respectent les règles du mode courant
# Exit 0 = autorisé, Exit 2 = bloqué

set -euo pipefail

# Lire l'input JSON de Claude
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Ne traiter que les commandes Bash
if [[ "$TOOL" != "Bash" ]]; then
    exit 0
fi

# Trouver la session active
SESSION_DIR="$HOME/.claude/sessions"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)

# Si pas de session, autoriser (mode dégradé)
if [[ ! -f "$SESSION_FILE" ]]; then
    exit 0
fi

# Lire le mode courant
MODE=$(jq -r '.mode // "bypass"' "$SESSION_FILE")

# En mode BYPASS, tout est autorisé
if [[ "$MODE" == "bypass" ]]; then
    exit 0
fi

# === MODE PLAN : Vérifier les règles ===

RULES_FILE="/workspace/.claude/plan-mode-rules.yml"
if [[ ! -f "$RULES_FILE" ]]; then
    # Pas de fichier de règles, utiliser les règles par défaut
    RULES_FILE="$HOME/.claude/plan-mode-rules.yml"
fi

# Commandes bloquées par défaut (hardcodées si pas de fichier)
BLOCKED_COMMANDS=(
    "git add"
    "git commit"
    "git push"
    "git merge"
    "git rebase"
    "npm install"
    "yarn install"
    "pnpm install"
    "pip install"
    "go mod tidy"
    "prettier --write"
    "prettier -w"
    "eslint --fix"
    "go fmt"
    "sed -i"
    "touch"
    "mkdir"
    "rm "
    "mv "
    "cp "
)

# Patterns bloqués
BLOCKED_PATTERNS=(
    ">>"
    "| tee"
    "--write"
    "--fix"
)

# Exceptions (autorisées même si match)
EXCEPTIONS=(
    "> /dev/null"
    "2> /dev/null"
    "2>&1"
    "&> /dev/null"
)

# Fonction pour vérifier si une exception s'applique
has_exception() {
    local cmd="$1"
    for exc in "${EXCEPTIONS[@]}"; do
        if [[ "$cmd" == *"$exc"* ]]; then
            return 0
        fi
    done
    return 1
}

# Vérifier les commandes bloquées
COMMAND_LOWER=$(echo "$COMMAND" | tr '[:upper:]' '[:lower:]')

for blocked in "${BLOCKED_COMMANDS[@]}"; do
    if [[ "$COMMAND_LOWER" == *"$blocked"* ]]; then
        # Vérifier les exceptions
        if has_exception "$COMMAND"; then
            continue
        fi
        echo "═══════════════════════════════════════════════"
        echo "  ❌ BLOQUÉ: Commande interdite en PLAN MODE"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo "  Mode actuel: PLAN (lecture seule)"
        echo "  Commande bloquée: $blocked"
        echo ""
        echo "  Commande complète:"
        echo "    $COMMAND" | head -c 200
        echo ""
        echo ""
        echo "  Pour exécuter cette commande:"
        echo "    1. Terminez le planning"
        echo "    2. Démarrez une task avec task-start.sh"
        echo "    3. Le mode passera en BYPASS"
        echo ""
        echo "═══════════════════════════════════════════════"
        exit 2
    fi
done

# Vérifier les patterns bloqués
for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        # Vérifier les exceptions
        if has_exception "$COMMAND"; then
            continue
        fi
        # Vérifier si c'est une redirection vers /dev/null
        if [[ "$pattern" == ">>" ]] && [[ "$COMMAND" == *"/dev/null"* ]]; then
            continue
        fi
        echo "═══════════════════════════════════════════════"
        echo "  ❌ BLOQUÉ: Pattern interdit en PLAN MODE"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo "  Mode actuel: PLAN (lecture seule)"
        echo "  Pattern détecté: $pattern"
        echo ""
        echo "  Les redirections vers fichiers sont interdites"
        echo "  en mode PLAN (sauf vers /dev/null)."
        echo ""
        echo "═══════════════════════════════════════════════"
        exit 2
    fi
done

# Commande autorisée
exit 0
