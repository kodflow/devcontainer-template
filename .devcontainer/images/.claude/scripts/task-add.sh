#!/bin/bash
# task-add.sh - Ajouter une task à un epic
# Usage: task-add.sh <project> <epic_num> <epic_uuid> <task_name> [parallel:yes|no] [ctx:JSON]
# Exemple: task-add.sh "feat-login" 1 "uuid-xxx" "Créer AuthService" "no" '{"files":["src/auth.ts"]}'

set -e

# Vérifier Taskwarrior
if ! command -v task &>/dev/null; then
    echo "❌ Taskwarrior non installé"
    exit 1
fi

PROJECT="$1"
EPIC_NUM="$2"
EPIC_UUID="$3"
TASK_NAME="$4"
PARALLEL="${5:-no}"
CTX_JSON="${6:-}"

if [[ -z "$PROJECT" || -z "$EPIC_NUM" || -z "$EPIC_UUID" || -z "$TASK_NAME" ]]; then
    echo "Usage: task-add.sh <project> <epic_num> <epic_uuid> <task_name> [parallel] [ctx_json]"
    exit 1
fi

# Créer la task
# Note: "parent" est un mot réservé dans Taskwarrior, on utilise "epic_uuid" à la place
OUTPUT=$(task add project:"$PROJECT" "$TASK_NAME" +task epic:"$EPIC_NUM" epic_uuid:"$EPIC_UUID" parallel:"$PARALLEL" 2>&1)
TASK_ID=$(echo "$OUTPUT" | grep -oP 'Created task \K\d+' || echo "")

if [[ -z "$TASK_ID" ]]; then
    echo "❌ Erreur création task"
    echo "$OUTPUT"
    exit 1
fi

# Récupérer l'UUID
TASK_UUID=$(task "$TASK_ID" uuid 2>/dev/null | tr -d '\n')

# Ajouter le contexte JSON si fourni
if [[ -n "$CTX_JSON" ]]; then
    # Escape les guillemets pour l'annotation
    CTX_ESCAPED=$(echo "$CTX_JSON" | sed 's/"/\\"/g')
    task uuid:"$TASK_UUID" annotate "ctx:$CTX_JSON" 2>/dev/null || true
fi

echo "$TASK_UUID"
