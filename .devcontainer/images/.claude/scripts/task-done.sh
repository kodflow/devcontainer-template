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

# Marquer comme terminée
task uuid:"$TASK_UUID" done 2>/dev/null || true

# Mettre à jour la session si elle existe
SESSION_DIR="$HOME/.claude/sessions"
SESSION_FILE=$(ls -t "$SESSION_DIR"/*.json 2>/dev/null | head -1)

if [[ -f "$SESSION_FILE" ]]; then
    # Mettre à jour le status de la task dans la session
    TMP_FILE=$(mktemp)
    jq --arg uuid "$TASK_UUID" '
        (.epics[]?.tasks[]? | select(.uuid == $uuid)).status = "DONE"
    ' "$SESSION_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$SESSION_FILE"

    # Vérifier si toutes les tasks de l'epic sont DONE
    EPIC_NUM=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].epic // 1')
    ALL_DONE=$(jq --arg epic "$EPIC_NUM" '
        .epics[] | select(.id == ($epic | tonumber)) |
        .tasks | all(.status == "DONE")
    ' "$SESSION_FILE" 2>/dev/null || echo "false")

    if [[ "$ALL_DONE" == "true" ]]; then
        # Marquer l'epic comme DONE
        TMP_FILE=$(mktemp)
        jq --arg epic "$EPIC_NUM" '
            (.epics[] | select(.id == ($epic | tonumber))).status = "DONE"
        ' "$SESSION_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$SESSION_FILE"
        echo "✓ Epic $EPIC_NUM terminé !"
    fi
fi

# Afficher info
TASK_DESC=$(task uuid:"$TASK_UUID" export 2>/dev/null | jq -r '.[0].description // "Unknown"' || echo "Completed")
echo "✓ Task terminée: $TASK_DESC"
