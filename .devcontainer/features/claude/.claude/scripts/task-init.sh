#!/bin/bash
# Initialise Taskwarrior pour un nouveau projet feature/fix
# Usage: task-init.sh <type> <description>

set -euo pipefail

TYPE="$1"        # feature ou fix
DESC="$2"        # Description

# Normaliser le nom du projet
PROJECT=$(echo "$DESC" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
BRANCH="${TYPE}/${PROJECT}"

# Créer le dossier sessions si nécessaire
SESSION_DIR="/workspace/.claude/sessions"
mkdir -p "$SESSION_DIR"

# Vérifier si une session existe déjà pour ce projet
if [[ -f "$SESSION_DIR/$PROJECT.json" ]]; then
    echo "⚠ Session existante trouvée pour: $PROJECT"
    echo "→ Utilisez --continue pour reprendre"
    exit 1
fi

# Configurer les UDAs si pas encore fait
if ! task _get rc.uda.phase.type &>/dev/null 2>&1; then
    echo "Configuration des UDAs Taskwarrior..."
    task config uda.phase.type numeric 2>/dev/null || true
    task config uda.phase.label Phase 2>/dev/null || true
    task config uda.phase.default 1 2>/dev/null || true
    task config uda.model.type string 2>/dev/null || true
    task config uda.model.label Model 2>/dev/null || true
    task config uda.model.values opus,sonnet,haiku 2>/dev/null || true
    task config uda.model.default sonnet 2>/dev/null || true
    task config uda.parallel.type string 2>/dev/null || true
    task config uda.parallel.label Parallel 2>/dev/null || true
    task config uda.parallel.values yes,no 2>/dev/null || true
    task config uda.parallel.default no 2>/dev/null || true
    task config uda.branch.type string 2>/dev/null || true
    task config uda.branch.label Branch 2>/dev/null || true
    task config uda.pr_number.type numeric 2>/dev/null || true
    task config uda.pr_number.label PR 2>/dev/null || true
    echo "✓ UDAs configurés"
fi

echo "Création du projet: $PROJECT"

# Phase 1: Planning (tâche unique)
TASK1_OUTPUT=$(task add "Phase 1: Planning - Explorer et planifier" \
    project:"$PROJECT" +claude +planning phase:1 \
    model:sonnet parallel:no branch:"$BRANCH" 2>&1)
TASK1_ID=$(echo "$TASK1_OUTPUT" | grep -oP 'Created task \K\d+' || echo "")
if [[ -z "$TASK1_ID" ]]; then
    echo "❌ Erreur création tâche Phase 1"
    exit 1
fi
TASK1_UUID=$(task "$TASK1_ID" uuid)
task "$TASK1_ID" annotate "init:{\"phase\":1,\"desc\":\"Explore codebase, create plan, await validation\"}" 2>/dev/null

# Phase 2: Implementation (bloquée, sous-tâches créées après le plan)
TASK2_OUTPUT=$(task add "Phase 2: Implementation" \
    project:"$PROJECT" +claude +implementation phase:2 \
    model:sonnet parallel:no branch:"$BRANCH" depends:"$TASK1_ID" 2>&1)
TASK2_ID=$(echo "$TASK2_OUTPUT" | grep -oP 'Created task \K\d+' || echo "")
if [[ -z "$TASK2_ID" ]]; then
    echo "❌ Erreur création tâche Phase 2"
    exit 1
fi
TASK2_UUID=$(task "$TASK2_ID" uuid)
task "$TASK2_ID" annotate "init:{\"phase\":2,\"desc\":\"Subtasks created from validated plan\"}" 2>/dev/null

# Phase 3: Testing (bloquée)
TASK3_OUTPUT=$(task add "Phase 3: Testing - Vérifier et tester" \
    project:"$PROJECT" +claude +testing phase:3 \
    model:sonnet parallel:no branch:"$BRANCH" depends:"$TASK2_ID" 2>&1)
TASK3_ID=$(echo "$TASK3_OUTPUT" | grep -oP 'Created task \K\d+' || echo "")
if [[ -z "$TASK3_ID" ]]; then
    echo "❌ Erreur création tâche Phase 3"
    exit 1
fi
TASK3_UUID=$(task "$TASK3_ID" uuid)
task "$TASK3_ID" annotate "init:{\"phase\":3,\"desc\":\"Run tests, verify functionality\"}" 2>/dev/null

# Phase 4: PR (bloquée)
TASK4_OUTPUT=$(task add "Phase 4: PR - Créer la Pull Request" \
    project:"$PROJECT" +claude +pr phase:4 \
    model:haiku parallel:no branch:"$BRANCH" depends:"$TASK3_ID" 2>&1)
TASK4_ID=$(echo "$TASK4_OUTPUT" | grep -oP 'Created task \K\d+' || echo "")
if [[ -z "$TASK4_ID" ]]; then
    echo "❌ Erreur création tâche Phase 4"
    exit 1
fi
TASK4_UUID=$(task "$TASK4_ID" uuid)
task "$TASK4_ID" annotate "init:{\"phase\":4,\"desc\":\"Create PR, verify CI, NO auto-merge\"}" 2>/dev/null

# Créer le fichier de session (persistant)
SESSION_FILE="$SESSION_DIR/$PROJECT.json"
cat > "$SESSION_FILE" << EOF
{
    "project": "$PROJECT",
    "branch": "$BRANCH",
    "type": "$TYPE",
    "phases": {
        "1": {"id": $TASK1_ID, "uuid": "$TASK1_UUID", "name": "Planning", "subtasks": []},
        "2": {"id": $TASK2_ID, "uuid": "$TASK2_UUID", "name": "Implementation", "subtasks": []},
        "3": {"id": $TASK3_ID, "uuid": "$TASK3_UUID", "name": "Testing", "subtasks": []},
        "4": {"id": $TASK4_ID, "uuid": "$TASK4_UUID", "name": "PR", "subtasks": []}
    },
    "current_phase": 1,
    "current_task_uuid": "$TASK1_UUID",
    "actions": 0,
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_action": null
}
EOF

# Démarrer la première tâche
task "$TASK1_ID" start 2>/dev/null || true

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Projet créé: $PROJECT"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Phases:"
echo "    1. Planning       [EN COURS]"
echo "    2. Implementation [BLOQUÉE]"
echo "    3. Testing        [BLOQUÉE]"
echo "    4. PR             [BLOQUÉE]"
echo ""
echo "  Branch: $BRANCH"
echo "  Session: $SESSION_FILE"
echo "═══════════════════════════════════════════════"
