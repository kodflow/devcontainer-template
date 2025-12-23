#!/bin/bash
# task-validate.sh - PreToolUse hook pour valider le workflow
#
# PLAN MODE: Autorise Read/Glob/Grep/WebSearch, BLOQUE Write/Edit
# BYPASS MODE: Autorise Write/Edit SI une task est WIP
#
# Exit 0 = autorisé, Exit 2 = bloqué

set -e

# Vérifier que Taskwarrior est installé
if ! command -v task &>/dev/null; then
    exit 0  # Dégradé graceful si pas de Taskwarrior
fi

# Lire l'input JSON de Claude
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "N/A"')

# Trouver la session active
SESSION_DIR="$HOME/.claude/sessions"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)

# Si pas de session
if [[ ! -f "$SESSION_FILE" ]]; then
    echo "❌ BLOQUÉ: Aucun projet actif."
    echo ""
    echo "→ Utilisez /feature <description> ou /fix <description>"
    exit 2
fi

# Lire le mode et les infos de session
MODE=$(jq -r '.mode // "plan"' "$SESSION_FILE")
PROJECT=$(jq -r '.project // "unknown"' "$SESSION_FILE")
CURRENT_TASK=$(jq -r '.current_task // empty' "$SESSION_FILE")

# ============================================================
# PLAN MODE - Recherche uniquement, pas d'édition
# ============================================================
if [[ "$MODE" == "plan" ]]; then
    # Autoriser les fichiers de plan
    if [[ "$FILE_PATH" == *"/plans/"* || "$FILE_PATH" == *"CLAUDE.md"* ]]; then
        echo "✓ Mode PLAN: Édition plan autorisée"
        exit 0
    fi

    # Bloquer Write/Edit sur le code
    if [[ "$TOOL" == "Write" || "$TOOL" == "Edit" ]]; then
        echo "❌ BLOQUÉ: Mode PLAN actif - pas d'édition de code"
        echo ""
        echo "  Vous êtes en phase d'analyse. Pour éditer du code:"
        echo "  1. Terminez le plan (définition epics/tasks)"
        echo "  2. Validez avec l'utilisateur"
        echo "  3. Passez en BYPASS MODE"
        echo ""
        echo "  Projet: $PROJECT"
        exit 2
    fi

    # Autoriser tout le reste (Read, Glob, Grep, etc.)
    exit 0
fi

# ============================================================
# BYPASS MODE - Exécution avec task WIP obligatoire
# ============================================================
if [[ "$MODE" == "bypass" ]]; then
    # Vérifier qu'une task est en cours
    if [[ -z "$CURRENT_TASK" ]]; then
        echo "❌ BLOQUÉ: Aucune task en cours (WIP)"
        echo ""
        echo "  En BYPASS MODE, vous devez:"
        echo "  1. Démarrer une task: task-start.sh <uuid>"
        echo "  2. Effectuer les modifications"
        echo "  3. Terminer la task: task-done.sh <uuid>"
        exit 2
    fi

    # Trouver l'UUID de la task courante
    TASK_UUID=$(jq -r --arg tid "$CURRENT_TASK" '
        .epics[]?.tasks[]? | select(.id == $tid) | .uuid
    ' "$SESSION_FILE" 2>/dev/null || echo "")

    if [[ -z "$TASK_UUID" ]]; then
        echo "⚠️  Task ID invalide: $CURRENT_TASK"
        exit 0  # Autoriser quand même (graceful)
    fi

    # Vérifier le status de la task
    TASK_STATUS=$(jq -r --arg tid "$CURRENT_TASK" '
        .epics[]?.tasks[]? | select(.id == $tid) | .status
    ' "$SESSION_FILE" 2>/dev/null || echo "TODO")

    if [[ "$TASK_STATUS" != "WIP" ]]; then
        echo "❌ BLOQUÉ: Task '$CURRENT_TASK' n'est pas WIP (status: $TASK_STATUS)"
        echo ""
        echo "  Démarrez la task avec: task-start.sh $TASK_UUID"
        exit 2
    fi

    # Log l'action (pré-événement)
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    task uuid:"$TASK_UUID" annotate "pre:{\"ts\":\"$TIMESTAMP\",\"tool\":\"$TOOL\",\"file\":\"$FILE_PATH\"}" 2>/dev/null || true

    # Afficher confirmation
    TASK_NAME=$(jq -r --arg tid "$CURRENT_TASK" '
        .epics[]?.tasks[]? | select(.id == $tid) | .name
    ' "$SESSION_FILE" 2>/dev/null || echo "Unknown")

    echo "✓ Projet: $PROJECT"
    echo "✓ Task WIP: $TASK_NAME"
    exit 0
fi

# Mode inconnu - autoriser par défaut
exit 0
