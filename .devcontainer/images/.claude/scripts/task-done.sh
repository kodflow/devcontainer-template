#!/bin/bash
# task-done.sh - Terminer une task (WIP → DONE)
# Usage: task-done.sh <uuid>
# Met à jour la session JSON et marque la task comme terminée

set -e

# Vérifier Taskwarrior
if ! command -v task &>/dev/null; then
    echo "❌ Taskwarrior non installé"
    exit 1
fi

TASK_UUID="$1"

if [[ -z "$TASK_UUID" ]]; then
    echo "Usage: task-done.sh <uuid>"
    exit 1
fi

# Vérifier que la task existe
if ! task uuid:"$TASK_UUID" info &>/dev/null; then
    echo "❌ Task non trouvée: $TASK_UUID"
    exit 1
fi

# Récupérer les infos de la task AVANT de la terminer
TASK_DATA=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0]')
PROJECT=$(echo "$TASK_DATA" | jq -r '.project // ""')
EPIC_NUM=$(echo "$TASK_DATA" | jq -r '.epic // ""')

# Marquer comme terminée
task uuid:"$TASK_UUID" done 2>/dev/null || true

# === Auto-close Epic dans Taskwarrior ===
# Si la task a un epic, vérifier si toutes les tasks de l'epic sont terminées
if [[ -n "$PROJECT" && -n "$EPIC_NUM" ]]; then
    # Compter les tasks non terminées pour cet epic (excluant l'epic lui-même)
    REMAINING=$(task project:"$PROJECT" epic:"$EPIC_NUM" +task status:pending count 2>/dev/null || echo "0")

    if [[ "$REMAINING" == "0" ]]; then
        # Trouver et fermer l'epic parent
        EPIC_UUID=$(task project:"$PROJECT" epic:"$EPIC_NUM" +epic status:pending _uuids 2>/dev/null | head -1)
        if [[ -n "$EPIC_UUID" ]]; then
            task uuid:"$EPIC_UUID" done 2>/dev/null || true
            echo "✓ Epic $EPIC_NUM auto-fermé (toutes les tasks terminées)"
        fi
    fi
fi

# === Mise à jour session JSON (fallback) ===
SESSION_DIR="$HOME/.claude/sessions"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)

if [[ -f "$SESSION_FILE" ]]; then
    # Mettre à jour le status de la task dans la session
    TMP_FILE=$(mktemp)
    jq --arg uuid "$TASK_UUID" '
        (.epics[]?.tasks[]? | select(.uuid == $uuid)).status = "DONE"
    ' "$SESSION_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$SESSION_FILE"

    # Mettre à jour le status de l'epic dans la session si fermé
    if [[ -n "$EPIC_NUM" ]]; then
        TMP_FILE=$(mktemp)
        jq --arg epic "$EPIC_NUM" '
            if .epics then
                (.epics[] | select(.id == ($epic | tonumber))).status = "DONE"
            else . end
        ' "$SESSION_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$SESSION_FILE"
    fi
fi

# Afficher info
TASK_DESC=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].description // "Unknown"' || echo "Completed")
echo "✓ Task terminée: $TASK_DESC"
