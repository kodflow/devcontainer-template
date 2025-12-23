#!/bin/bash
# task-init.sh - Initialise un projet Taskwarrior (sans phases statiques)
# Usage: task-init.sh <type> <description>
#
# Ce script initialise uniquement le projet et la session.
# Les epics et tasks sont créés dynamiquement pendant le planning.

set -euo pipefail

# Vérifier que Taskwarrior est installé
if ! command -v task &>/dev/null; then
    echo "❌ Taskwarrior non installé !"
    echo ""
    echo "Installation requise pour /feature et /fix :"
    echo ""
    echo "  Ubuntu/Debian : sudo apt-get install taskwarrior"
    echo "  Alpine        : sudo apk add task"
    echo "  macOS         : brew install task"
    echo "  Arch          : sudo pacman -S task"
    echo ""
    echo "Ou exécutez: /update"
    exit 1
fi

TYPE="$1"        # feature ou fix
DESC="$2"        # Description

if [[ -z "$TYPE" || -z "$DESC" ]]; then
    echo "Usage: task-init.sh <type> <description>"
    echo "Exemple: task-init.sh feature \"authentication-system\""
    exit 1
fi

# Normaliser le nom du projet
PROJECT=$(echo "$DESC" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
BRANCH="${TYPE}/${PROJECT}"

# Créer le dossier sessions si nécessaire
SESSION_DIR="$HOME/.claude/sessions"
mkdir -p "$SESSION_DIR"

# Vérifier si une session existe déjà pour ce projet
if [[ -f "$SESSION_DIR/$PROJECT.json" ]]; then
    echo "⚠ Session existante trouvée pour: $PROJECT"
    echo "→ Utilisez --continue pour reprendre"
    exit 1
fi

# Configurer Taskwarrior pour usage non-interactif
echo "Configuration de Taskwarrior..."

# Désactiver les confirmations interactives (IMPORTANT pour Claude)
task config confirmation off 2>/dev/null || true

# Configurer les UDAs pour le système epic/task
# Note: "parent" est un mot réservé, on utilise "epic_uuid" à la place
task config uda.epic.type numeric 2>/dev/null || true
task config uda.epic.label Epic 2>/dev/null || true
task config uda.epic_uuid.type string 2>/dev/null || true
task config uda.epic_uuid.label "Epic UUID" 2>/dev/null || true

# Parallélisation
task config uda.parallel.type string 2>/dev/null || true
task config uda.parallel.label Parallel 2>/dev/null || true
task config uda.parallel.values yes,no 2>/dev/null || true
task config uda.parallel.default no 2>/dev/null || true

# Branch et PR
task config uda.branch.type string 2>/dev/null || true
task config uda.branch.label Branch 2>/dev/null || true
task config uda.pr_number.type numeric 2>/dev/null || true
task config uda.pr_number.label PR 2>/dev/null || true

echo "✓ Taskwarrior configuré"

# Créer le fichier de session (PLAN MODE par défaut)
SESSION_FILE="$SESSION_DIR/$PROJECT.json"
cat > "$SESSION_FILE" << EOF
{
    "project": "$PROJECT",
    "branch": "$BRANCH",
    "type": "$TYPE",
    "mode": "plan",
    "plan_phase": 1,
    "epics": [],
    "current_epic": null,
    "current_task": null,
    "actions": 0,
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "last_action": null
}
EOF

echo ""
echo "═══════════════════════════════════════════════"
echo "  ✓ Projet initialisé: $PROJECT"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Mode: PLAN (analyse et définition des epics/tasks)"
echo ""
echo "  Phases PLAN MODE:"
echo "    1. Analyse de la demande"
echo "    2. Recherche documentation"
echo "    3. Analyse projet existant"
echo "    4. Affûtage (boucle si nécessaire)"
echo "    5. Définition épics/tasks → VALIDATION"
echo "    6. Écriture Taskwarrior"
echo ""
echo "  Après validation → BYPASS MODE (exécution)"
echo ""
echo "  Branch: $BRANCH"
echo "  Session: $SESSION_FILE"
echo "═══════════════════════════════════════════════"
