#!/bin/bash
# ============================================================================
# on-stop-quality.sh - Project-level quality gate at end of Claude's turn
# Hook: Stop (all matchers)
# Exit 0 = always (fail-open)
#
# Purpose: Run `make build`, `make lint`, `make test` at project level
# after every Claude turn. If any fails, output errors as additionalContext
# so Claude sees them and fixes iteratively.
#
# Project type detection:
#   - Programming language detected  → require build/lint/test
#   - IaC only (Terraform, Ansible)  → skip (handled by their own tools)
#   - No source code                 → skip silently
#
# If Makefile or targets don't exist, tell Claude to create them.
#
# Security scanning is handled by git-guard.sh in PreToolUse (Bash).
# ============================================================================

set +e  # Fail-open: never block

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/workspace}"

# Source common utilities
# shellcheck source=common.sh
[ -f "$SCRIPT_DIR/common.sh" ] && . "$SCRIPT_DIR/common.sh"

# === Prevent infinite loops ===
SESSION_ID="${CLAUDE_SESSION_ID:-default}"
TRACKER="/tmp/.claude-edited-files-${SESSION_ID}"
QUALITY_RAN="/tmp/.claude-quality-ran-${SESSION_ID}"

# Check if code was edited this turn (tracker populated by post-edit.sh)
HAD_EDITS=false
if [ -f "$TRACKER" ] && [ -s "$TRACKER" ]; then
    HAD_EDITS=true
    rm -f "$TRACKER" "$TRACKER.lock" 2>/dev/null || true
fi

# If no edits this turn and quality already ran, skip to avoid loop
if [ "$HAD_EDITS" = "false" ] && [ -f "$QUALITY_RAN" ]; then
    rm -f "$QUALITY_RAN" 2>/dev/null || true
    exit 0
fi

# === Find project root ===
PROJECT_ROOT=""
if [ -d "$PROJECT_DIR/src" ]; then
    PROJECT_ROOT=$(find_project_root "$PROJECT_DIR/src" "$PROJECT_DIR" 2>/dev/null)
fi
if [ -z "$PROJECT_ROOT" ] || [ "$PROJECT_ROOT" = "$PROJECT_DIR/src" ]; then
    PROJECT_ROOT=$(find_project_root "$PROJECT_DIR" "$PROJECT_DIR" 2>/dev/null)
fi
PROJECT_ROOT="${PROJECT_ROOT:-$PROJECT_DIR}"

# === Detect project type ===
# Returns: "code", "iac", or "none"
# "code" = programming language project (needs build/lint/test)
# "iac"  = infrastructure-as-code only (Terraform, Ansible, Helm, etc.)
# "none" = no detectable source code
detect_project_type() {
    local root="$1"
    local search_dirs=("$root" "$root/src")

    # Programming language markers (file extensions)
    local code_extensions=(
        "*.go" "*.py" "*.rs" "*.js" "*.ts" "*.jsx" "*.tsx"
        "*.java" "*.c" "*.cpp" "*.cc" "*.h" "*.hpp"
        "*.rb" "*.php" "*.ex" "*.exs" "*.dart" "*.scala"
        "*.kt" "*.kts" "*.swift" "*.cs" "*.vb"
        "*.r" "*.R" "*.pl" "*.pm" "*.lua"
        "*.f90" "*.f95" "*.f03" "*.f08"
        "*.adb" "*.ads" "*.cob" "*.cbl"
        "*.pas" "*.dpr" "*.m" "*.asm" "*.s"
    )

    # Build system markers (confirm it's a code project)
    local build_markers=(
        "go.mod" "Cargo.toml" "package.json" "pyproject.toml"
        "pom.xml" "build.gradle" "build.gradle.kts" "build.sbt"
        "mix.exs" "pubspec.yaml" "CMakeLists.txt" "Package.swift"
        "composer.json" "Gemfile" "fpm.toml" "alire.toml"
        "setup.py" "setup.cfg" "Makefile"
    )

    # Check for programming language files
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] || continue
        for ext in "${code_extensions[@]}"; do
            if compgen -G "$dir/$ext" > /dev/null 2>&1; then
                echo "code"
                return
            fi
            # Check one level deeper (common project layouts)
            if compgen -G "$dir"/*/"$ext" > /dev/null 2>&1; then
                echo "code"
                return
            fi
        done
    done

    # Check build system markers at root
    for marker in "${build_markers[@]}"; do
        if [ -f "$root/$marker" ]; then
            echo "code"
            return
        fi
    done

    # Check for IaC-only project
    local iac_markers=(
        "*.tf"           # Terraform
        "*.tfvars"       # Terraform vars
        "terragrunt.hcl" # Terragrunt
        "playbook*.yml"  # Ansible
        "Chart.yaml"     # Helm
        "*.bicep"        # Azure Bicep
        "template.yaml"  # CloudFormation / SAM
        "serverless.yml" # Serverless Framework
        "Pulumi.yaml"    # Pulumi
    )

    for pattern in "${iac_markers[@]}"; do
        if compgen -G "$root/$pattern" > /dev/null 2>&1 || \
           compgen -G "$root"/*/"$pattern" > /dev/null 2>&1; then
            echo "iac"
            return
        fi
    done

    echo "none"
}

PROJECT_TYPE=$(detect_project_type "$PROJECT_ROOT")

# === IaC-only projects: skip quality gate ===
if [ "$PROJECT_TYPE" = "iac" ]; then
    # IaC projects use their own validation (terraform validate, ansible-lint, etc.)
    # These are handled by the specific tools, not make build/lint/test
    exit 0
fi

# === No source code detected: skip silently ===
if [ "$PROJECT_TYPE" = "none" ]; then
    exit 0
fi

# === Programming language project: enforce quality gate ===

# Determine which targets make sense based on project structure
REQUIRED_TARGETS=""
OPTIONAL_BUILD=true

# Some ecosystems don't have a separate "build" step (interpreted languages)
# but we still require it for consistency — the Makefile target can just
# run syntax checks or be a no-op if truly not needed
for marker in "go.mod" "Cargo.toml" "CMakeLists.txt" "pom.xml" \
              "build.gradle" "build.gradle.kts" "build.sbt" \
              "Package.swift" "pubspec.yaml" "fpm.toml" "alire.toml"; do
    if [ -f "$PROJECT_ROOT/$marker" ]; then
        REQUIRED_TARGETS="build lint test"
        break
    fi
done

# For interpreted languages: build is optional but lint+test are required
if [ -z "$REQUIRED_TARGETS" ]; then
    for marker in "package.json" "pyproject.toml" "setup.py" "setup.cfg" \
                  "Gemfile" "composer.json" "mix.exs"; do
        if [ -f "$PROJECT_ROOT/$marker" ]; then
            REQUIRED_TARGETS="lint test"
            OPTIONAL_BUILD=false
            break
        fi
    done
fi

# Fallback: if we detected code files but no build system marker
if [ -z "$REQUIRED_TARGETS" ]; then
    REQUIRED_TARGETS="lint test"
    OPTIONAL_BUILD=false
fi

# === Check for Makefile ===
if [ ! -f "$PROJECT_ROOT/Makefile" ]; then
    echo "--- Quality Gate: No Makefile ---" >&2

    CONTEXT="QUALITY GATE: No Makefile found at $PROJECT_ROOT.\n\n"
    CONTEXT+="Programming language project detected. Please create a Makefile with these targets:\n"
    for target in $REQUIRED_TARGETS; do
        case "$target" in
            build) CONTEXT+="  - \`make build\` : Compile/build the project\n" ;;
            lint)  CONTEXT+="  - \`make lint\`  : Run linter(s) appropriate for the language\n" ;;
            test)  CONTEXT+="  - \`make test\`  : Run the test suite\n" ;;
        esac
    done
    if [ "$OPTIONAL_BUILD" = "false" ]; then
        CONTEXT+="\nNote: \`make build\` is optional for this project type (interpreted language).\n"
        CONTEXT+="Add it if there's a compilation/transpilation step, otherwise skip it.\n"
    fi
    CONTEXT+="\nBefore creating it, ask the user:\n"
    CONTEXT+="  1. Which linter(s) they prefer?\n"
    CONTEXT+="  2. Which test framework to use?\n"
    CONTEXT+="  3. Any specific flags or configurations?\n\n"
    CONTEXT+="If the answers are obvious from the project structure (e.g., go.mod -> Go with golangci-lint,\n"
    CONTEXT+="Cargo.toml -> Rust with clippy, package.json -> check existing scripts), create the Makefile\n"
    CONTEXT+="directly with sensible defaults."

    if command -v jq &>/dev/null; then
        jq -n -c \
            --arg ctx "$CONTEXT" \
            '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":$ctx}}' \
            2>/dev/null || true
    fi
    touch "$QUALITY_RAN" 2>/dev/null || true
    exit 0
fi

# === Check for required targets in existing Makefile ===
MISSING_TARGETS=""
TOTAL_REQUIRED=0
for target in $REQUIRED_TARGETS; do
    TOTAL_REQUIRED=$((TOTAL_REQUIRED + 1))
    if ! has_makefile_target "$target" "$PROJECT_ROOT"; then
        MISSING_TARGETS="${MISSING_TARGETS}${target} "
    fi
done

# Also check if build exists even if optional (run it if present)
RUN_BUILD=false
if has_makefile_target "build" "$PROJECT_ROOT"; then
    RUN_BUILD=true
fi

if [ -n "$MISSING_TARGETS" ]; then
    echo "--- Quality Gate: Missing Makefile targets ---" >&2
    CONTEXT="QUALITY GATE: Makefile exists at $PROJECT_ROOT but is missing targets: ${MISSING_TARGETS}\n\n"
    CONTEXT+="Please add the missing target(s) to the Makefile:\n"
    for target in $MISSING_TARGETS; do
        case "$target" in
            build) CONTEXT+="  - \`make build\`: Compile/build the project\n" ;;
            lint)  CONTEXT+="  - \`make lint\`: Run linter(s) for the project\n" ;;
            test)  CONTEXT+="  - \`make test\`: Run the test suite\n" ;;
        esac
    done
    CONTEXT+="\nAnalyze the existing Makefile and project structure to determine the right commands.\n"
    CONTEXT+="If unclear, ask the user about their preferred tools."

    if command -v jq &>/dev/null; then
        jq -n -c \
            --arg ctx "$CONTEXT" \
            '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":$ctx}}' \
            2>/dev/null || true
    fi
    touch "$QUALITY_RAN" 2>/dev/null || true
    exit 0
fi

# === Build the list of targets to run ===
TARGETS_TO_RUN=""
if [ "$RUN_BUILD" = "true" ]; then
    TARGETS_TO_RUN="build "
fi
for target in $REQUIRED_TARGETS; do
    [ "$target" = "build" ] && continue  # Already handled above
    TARGETS_TO_RUN+="$target "
done

# === Run quality gate ===
echo "--- Quality Gate ---" >&2

cd "$PROJECT_ROOT" || exit 0
ISSUES=""
PASSED=0
FAILED=0
TOTAL_RUN=0

for target in $TARGETS_TO_RUN; do
    TOTAL_RUN=$((TOTAL_RUN + 1))
    echo "Running: make $target" >&2
    OUTPUT=$(timeout 60 make "$target" 2>&1)
    EXIT_CODE=$?

    if [ "$EXIT_CODE" -ne 0 ]; then
        FAILED=$((FAILED + 1))
        # Truncate output (last 50 lines, max 2000 chars)
        TRUNCATED=$(printf '%s' "$OUTPUT" | tail -50)
        if [ ${#TRUNCATED} -gt 2000 ]; then
            TRUNCATED="${TRUNCATED:0:2000}...(truncated)"
        fi
        ISSUES+="FAIL make ${target} (exit $EXIT_CODE):\n${TRUNCATED}\n\n"
        echo "  FAIL (exit $EXIT_CODE)" >&2
    else
        PASSED=$((PASSED + 1))
        echo "  OK" >&2
    fi
done

# === Report results ===
if [ -n "$ISSUES" ]; then
    echo "Result: $PASSED passed, $FAILED failed" >&2
    echo "--- End Quality Gate ---" >&2

    CONTEXT="QUALITY GATE FAILED ($FAILED/$TOTAL_RUN targets failed, $PASSED/$TOTAL_RUN passed):\n\n"
    CONTEXT+="$ISSUES"
    CONTEXT+="Fix ALL failing targets. Run them again after fixing to verify.\n"
    CONTEXT+="Do NOT skip or comment out failing code - fix the root cause."

    if command -v jq &>/dev/null; then
        jq -n -c \
            --arg ctx "$CONTEXT" \
            '{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":$ctx}}' \
            2>/dev/null || true
    fi
    touch "$QUALITY_RAN" 2>/dev/null || true
else
    echo "All targets passed ($PASSED/$TOTAL_RUN)" >&2
    echo "--- End Quality Gate ---" >&2
    rm -f "$QUALITY_RAN" 2>/dev/null || true
fi

exit 0
