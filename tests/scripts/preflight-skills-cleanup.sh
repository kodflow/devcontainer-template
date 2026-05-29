#!/usr/bin/env bash
# preflight-skills-cleanup.sh — capture l'état AVANT la série de commits.
# But : figer la réalité (pas tout faire passer) pour comparer après chaque commit.
set -uo pipefail
cd "$(cd "$(dirname "$0")/../.." && pwd)" || { echo "preflight: cannot cd to repo root" >&2; exit 1; }

echo "== Preflight skills-cleanup =="
echo "do.md         : $(test -f .devcontainer/images/.claude/commands/do.md && echo present || echo absent)"
echo "do/           : $(test -d .devcontainer/images/.claude/commands/do && echo present || echo absent)"
echo "goal-state.sh : $(test -f .devcontainer/images/.claude/scripts/goal-state.sh && echo present || echo absent)"
echo "Skill(do) refs: $(grep -REIn 'Skill\(skill="do"' .devcontainer/images/.claude/commands/ | wc -l)"
echo "goal-state    : $(grep -RIl 'goal-state' .devcontainer/images/.claude/ | wc -l) fichiers"
echo "GrepAI (-i)   : $(grep -RIli grepai .devcontainer/images/.claude/commands/ | grep -vE 'update/apply.md|audit.md' | wc -l) (hors allowlist)"
echo "/prompt live  : $(grep -RIn '/prompt' CLAUDE.md .devcontainer/images/.claude/CLAUDE.md .devcontainer/images/CLAUDE.md docs/ 2>/dev/null | grep -vE 'use /refine|migration' | wc -l)"
echo "== Baseline test suite =="
make test
