#!/bin/bash
# task-start.sh - Démarrer une task (TODO → WIP)
# Usage: task-start.sh <uuid>
# Met à jour la session JSON et démarre la task dans Taskwarrior

set -e

# Vérifier Taskwarrior
if ! command -v task &>/dev/null; then
    echo "❌ Taskwarrior non installé"
    exit 1
fi

TASK_UUID="$1"

if [[ -z "$TASK_UUID" ]]; then
    echo "Usage: task-start.sh <uuid>"
    exit 1
fi

# Vérifier que la task existe
if ! task uuid:"$TASK_UUID" info &>/dev/null; then
    echo "❌ Task non trouvée: $TASK_UUID"
    exit 1
fi

# Démarrer la task
task uuid:"$TASK_UUID" start 2>/dev/null || true

# Mettre à jour la session si elle existe
SESSION_DIR="$HOME/.claude/sessions"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)

if [[ -f "$SESSION_FILE" ]]; then
    # Extraire l'epic de la task
    EPIC_NUM=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].epic // 1')

    # Trouver l'ID de la task dans la session
    TASK_ID=$(jq -r --arg uuid "$TASK_UUID" '
        .epics[]?.tasks[]? | select(.uuid == $uuid) | .id
    ' "$SESSION_FILE" 2>/dev/null || echo "")

    # Mettre à jour la session
    TMP_FILE=$(mktemp)
    jq --arg uuid "$TASK_UUID" --arg epic "$EPIC_NUM" --arg tid "$TASK_ID" '
        .mode = "bypass" |
        .current_task = $tid |
        .current_task_uuid = $uuid |
        .current_epic = ($epic | tonumber) |
        (.epics[]?.tasks[]? | select(.uuid == $uuid)).status = "WIP"
    ' "$SESSION_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$SESSION_FILE"
fi

# Afficher info
TASK_DESC=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].description // "Unknown"')
echo "▶ Task démarrée: $TASK_DESC"
echo "  UUID: $TASK_UUID"
