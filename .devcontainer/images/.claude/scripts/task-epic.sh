#!/bin/bash
# task-epic.sh - Créer un epic dans Taskwarrior
# Usage: task-epic.sh <project> <epic_number> <epic_name>
# Exemple: task-epic.sh "feat-login" 1 "Setup infrastructure"

set -e

# Vérifier Taskwarrior
if ! command -v task &>/dev/null; then
    echo "❌ Taskwarrior non installé"
    exit 1
fi

PROJECT="$1"
EPIC_NUM="$2"
EPIC_NAME="$3"

if [[ -z "$PROJECT" || -z "$EPIC_NUM" || -z "$EPIC_NAME" ]]; then
    echo "Usage: task-epic.sh <project> <epic_number> <epic_name>"
    echo "Exemple: task-epic.sh \"feat-login\" 1 \"Setup infrastructure\""
    exit 1
fi

# Configurer UDAs si pas déjà fait
task config uda.epic.type numeric 2>/dev/null || true
task config uda.epic.label Epic 2>/dev/null || true
task config uda.parent.type string 2>/dev/null || true
task config uda.parent.label Parent 2>/dev/null || true
task config uda.parallel.type string 2>/dev/null || true
task config uda.parallel.label Parallel 2>/dev/null || true
task config uda.parallel.values yes,no 2>/dev/null || true
task config uda.parallel.default no 2>/dev/null || true

# Créer l'epic
OUTPUT=$(task add project:"$PROJECT" "Epic $EPIC_NUM: $EPIC_NAME" +epic +planning epic:"$EPIC_NUM" 2>&1)
TASK_ID=$(echo "$OUTPUT" | grep -oP 'Created task \K\d+' || echo "")

if [[ -z "$TASK_ID" ]]; then
    echo "❌ Erreur création epic"
    echo "$OUTPUT"
    exit 1
fi

# Récupérer l'UUID
EPIC_UUID=$(task "$TASK_ID" uuid 2>/dev/null | tr -d '\n')

echo "$EPIC_UUID"
