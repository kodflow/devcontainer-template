#!/bin/bash
# PreToolUse hook - Valide qu'une tâche est active
# UNIQUEMENT pour Write|Edit - Bash est autorisé sans tâche
# Exit 0 = autorisé, Exit 2 = bloqué

set -euo pipefail

# Lire l'input JSON de Claude
INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // "N/A"')

# === STATE CHECK (schéma v2) ===
# Vérifier l'état courant via .state (planning/planned/applying/applied)
STATE_FILE="${CLAUDE_STATE_FILE:-/workspace/.claude/state.json}"

if [[ -f "$STATE_FILE" ]]; then
    # Schéma v2: utilise .state au lieu de .mode
    STATE=$(jq -r '.state // "planning"' "$STATE_FILE" 2>/dev/null || echo "planning")
    SCHEMA_VERSION=$(jq -r '.schemaVersion // 1' "$STATE_FILE" 2>/dev/null || echo "1")

    # Valider schéma v2 si déclaré
    if [[ "$SCHEMA_VERSION" == "2" ]]; then
        # Vérifier les invariants obligatoires
        TYPE=$(jq -r '.type // ""' "$STATE_FILE" 2>/dev/null)
        PROJECT=$(jq -r '.project // ""' "$STATE_FILE" 2>/dev/null)

        if [[ -z "$TYPE" || -z "$PROJECT" ]]; then
            echo "❌ Session invalide: type ou project manquant"
            exit 2
        fi

        if [[ ! "$TYPE" =~ ^(feature|fix)$ ]]; then
            echo "❌ Session invalide: type doit être 'feature' ou 'fix'"
            exit 2
        fi
    fi

    # En état planning, bloquer Write/Edit sauf sur fichiers autorisés
    if [[ "$STATE" == "planning" ]]; then
        # Liste des chemins autorisés en PLAN MODE
        ALLOWED_PATTERNS=(
            ".claude/plans/"
            ".claude/sessions/"
            "/plans/"
            "*.md"
        )

        IS_ALLOWED=false
        for pattern in "${ALLOWED_PATTERNS[@]}"; do
            if [[ "$FILE_PATH" == *"$pattern"* ]] || [[ "$FILE_PATH" == $pattern ]]; then
                IS_ALLOWED=true
                break
            fi
        done

        if [[ "$IS_ALLOWED" == "false" ]]; then
            echo "═══════════════════════════════════════════════"
            echo "  🚫 BLOQUÉ - state=planning"
            echo "═══════════════════════════════════════════════"
            echo ""
            echo "  Fichier: $FILE_PATH"
            echo "  Outil: $TOOL"
            echo ""
            echo "  En état 'planning', seuls ces chemins sont autorisés:"
            echo "    - .claude/plans/*"
            echo "    - .claude/sessions/*"
            echo "    - *.md (documentation)"
            echo ""
            echo "  Pour passer en état 'applying':"
            echo "    1. Validez le plan avec l'utilisateur"
            echo "    2. Écrivez les tasks dans Taskwarrior"
            echo "    3. state=planned → /apply → state=applying"
            echo ""
            echo "═══════════════════════════════════════════════"
            exit 2
        fi

        # En état planning avec fichier autorisé
        echo "✓ state=planning: Écriture autorisée sur $FILE_PATH"
        exit 0
    fi
fi

# === BYPASS MODE - Vérification Taskwarrior ===

# Vérifier que Taskwarrior est installé
if ! command -v task &>/dev/null; then
    echo "⚠️  Taskwarrior non installé - validation désactivée"
    echo "→ Pour activer le suivi obligatoire: /update"
    exit 0  # Autoriser quand même (dégradé graceful)
fi

# Trouver la session active (cherche dans .claude/sessions/)
SESSION_DIR="$HOME/.claude/sessions"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)

# Si pas de session, BLOQUER Write/Edit
if [[ ! -f "$SESSION_FILE" ]]; then
    echo "❌ BLOQUÉ: Aucune tâche Taskwarrior active."
    echo ""
    echo "→ Utilisez /feature <description> ou /fix <description>"
    echo "  pour démarrer un workflow avec suivi obligatoire."
    exit 2
fi

# Schéma v2: currentTask (avec fallback sur current_task_uuid pour compatibilité)
TASK_UUID=$(jq -r '.currentTask // .current_task_uuid // empty' "$SESSION_FILE")
PROJECT=$(jq -r '.project // "unknown"' "$SESSION_FILE")
SESSION_STATE=$(jq -r '.state // "planning"' "$SESSION_FILE")

# Vérifier que l'état permet l'exécution
if [[ "$SESSION_STATE" != "applying" ]]; then
    echo "❌ BLOQUÉ: État invalide ($SESSION_STATE)"
    echo "→ L'état doit être 'applying' pour modifier des fichiers"
    echo "→ Utilisez /apply pour démarrer l'exécution"
    exit 2
fi

if [[ -z "$TASK_UUID" ]]; then
    echo "❌ BLOQUÉ: Aucune tâche active (currentTask=null)"
    echo "→ Démarrez une task avec task-start.sh <uuid>"
    exit 2
fi

# Vérifier que la tâche existe et est active
TASK_STATUS=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].status // "unknown"')

if [[ "$TASK_STATUS" != "pending" ]]; then
    echo "❌ BLOQUÉ: Tâche terminée ou inexistante (status: $TASK_STATUS)"
    echo "→ Utilisez /feature --continue pour reprendre"
    exit 2
fi

# Vérifier que la tâche n'est pas bloquée par des dépendances
BLOCKED=$(task uuid:"$TASK_UUID" +BLOCKED count 2>/dev/null || echo "0")
if [[ "$BLOCKED" -gt 0 ]]; then
    DEPS=$(task uuid:"$TASK_UUID" depends 2>/dev/null | head -1)
    echo "❌ BLOQUÉ: Cette tâche dépend de tâches non terminées"
    echo "→ Dépendances: $DEPS"
    echo "→ Terminez d'abord les tâches précédentes"
    exit 2
fi

# Log l'action à venir (pré-événement)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

task uuid:"$TASK_UUID" annotate "pre:{\"ts\":\"$TIMESTAMP\",\"tool\":\"$TOOL\",\"file\":\"$FILE_PATH\"}" 2>/dev/null

# Afficher confirmation
TASK_DESC=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].description // "Unknown"')
echo "✓ Projet: $PROJECT"
echo "✓ Tâche: $TASK_DESC"
exit 0
