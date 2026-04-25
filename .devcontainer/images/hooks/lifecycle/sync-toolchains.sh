#!/bin/bash
# ============================================================================
# sync-toolchains.sh — Sync toolchains from image to volume on version mismatch
# Called by onCreateCommand (volumes already mounted)
#
# Problem: Features install to ~/.cache/ during build. Volume mounts OVER that
# path at runtime. On rebuild, the volume has OLD tools.
#
# Solution: Features write version markers to /opt/devcontainer-versions/.
# This script compares with volume markers and re-installs only on mismatch.
# ============================================================================

set -e

VERSIONS_DIR="/opt/devcontainer-versions"
CACHE_DIR="${HOME}/.cache"

[ -d "$VERSIONS_DIR" ] || exit 0

sync_lang() {
    local lang="$1"
    local image_ver volume_ver

    image_ver=$(cat "${VERSIONS_DIR}/${lang}" 2>/dev/null) || return 0
    volume_ver=$(cat "${CACHE_DIR}/.toolchain-version-${lang}" 2>/dev/null || echo "")

    if [ "$image_ver" = "$volume_ver" ]; then
        echo "  ${lang}: up to date (volume cache hit)"
        return 0
    fi

    echo "  ${lang}: version mismatch (image=${image_ver} volume=${volume_ver:-none})"
    echo "  ${lang}: syncing from image..."

    case "$lang" in
        rust)
            sync_rust
            ;;
        go)
            sync_go
            ;;
        python)
            sync_python
            ;;
        node)
            sync_node
            ;;
        *)
            echo "  ${lang}: no sync handler, skipping"
            return 0
            ;;
    esac

    echo "$image_ver" > "${CACHE_DIR}/.toolchain-version-${lang}"
    echo "  ${lang}: synced"
}

sync_rust() {
    export CARGO_HOME="${CARGO_HOME:-${CACHE_DIR}/cargo}"
    export RUSTUP_HOME="${RUSTUP_HOME:-${CACHE_DIR}/rustup}"
    export PATH="${CARGO_HOME}/bin:${PATH}"

    if ! command -v rustup &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path 2>/dev/null
    fi

    [ -f "${CARGO_HOME}/env" ] && source "${CARGO_HOME}/env"
    rustup toolchain install stable --profile minimal 2>/dev/null
    rustup default stable 2>/dev/null
    rustup component add rust-analyzer clippy rustfmt 2>/dev/null

    if command -v cargo-binstall &>/dev/null || {
        curl -L --proto '=https' --tlsv1.2 -sSf \
            https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash 2>/dev/null
    }; then
        local tools=(cargo-watch cargo-nextest cargo-deny)
        for tool in "${tools[@]}"; do
            command -v "$tool" &>/dev/null || cargo binstall --no-confirm --locked "$tool" 2>/dev/null || true
        done
        local binstall_only=(cargo-outdated cargo-tarpaulin wasm-bindgen-cli cargo-expand)
        for tool in "${binstall_only[@]}"; do
            command -v "$tool" &>/dev/null || cargo binstall --no-confirm --disable-strategies compile "$tool" 2>/dev/null || true
        done
    fi
}

sync_go() {
    export GOROOT="${GOROOT:-/usr/local/go}"
    export GOPATH="${GOPATH:-${CACHE_DIR}/go}"
    export GOCACHE="${GOCACHE:-${CACHE_DIR}/go-build}"
    export PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"

    mkdir -p "${GOPATH}/bin"

    if ! command -v go &>/dev/null; then
        echo "  go: binary missing (requires rebuild)"
        return 1
    fi

    local ARCH
    ARCH=$(uname -m)
    local GO_ARCH
    case "$ARCH" in
        x86_64) GO_ARCH="amd64" ;;
        aarch64|arm64) GO_ARCH="arm64" ;;
        *) GO_ARCH="amd64" ;;
    esac

    # Tool → full Go module path. The previous `go install ${tool}@latest`
    # was broken: `golangci-lint`, `gosec`, `gofumpt`, `gotestsum` are not
    # bare module names and silently failed (suffixed `|| true`). That mask
    # is why issue #329 (v1.64.8 stuck after v2.0.0 EOL) survived rebuilds.
    declare -A GO_TOOL_MODULES=(
        [golangci-lint]="github.com/golangci/golangci-lint/v2/cmd/golangci-lint"
        [gosec]="github.com/securego/gosec/v2/cmd/gosec"
        [gofumpt]="mvdan.cc/gofumpt"
        [gotestsum]="gotest.tools/gotestsum"
        [goimports]="golang.org/x/tools/cmd/goimports"
    )
    # Repo for upstream-version probe. Tools listed here are auto-refreshed
    # to upstream `latest` on every sync — drift-resistant by design, so a
    # stale volume can't pin us to an EOL major branch (issue #329). The set
    # is deliberately small: only tools whose upstream has a history of
    # major-version EOL transitions.
    declare -A GO_TOOL_REPOS=(
        [golangci-lint]="golangci/golangci-lint"
        [gosec]="securego/gosec"
    )

    install_go_tool_latest() {
        local tool="$1"
        local module="${GO_TOOL_MODULES[$tool]:-}"
        if [ -z "$module" ]; then
            echo "    ${tool}: no module path mapping (skipped)"
            return 1
        fi
        go install "${module}@latest" 2>/dev/null
    }

    upstream_latest_version() {
        local repo="$1"
        local auth=()
        [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: token ${GITHUB_TOKEN}")
        # Extract the X.Y.Z triple only — symmetric with installed_tool_version.
        # Without this, a suffix like `2.11.4-rc1` from a non-stable tag would
        # never match the installed binary's strict NN.NN.NN report and trigger
        # a spurious reinstall on every onCreate. (CodeRabbit, PR #330)
        curl -fsS --connect-timeout 3 --max-time 8 "${auth[@]}" \
            "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
            | sed -n 's/.*"tag_name": *"v\?\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' \
            | head -n 1
    }

    installed_tool_version() {
        local tool="$1"
        command -v "$tool" >/dev/null 2>&1 || { echo ""; return; }
        # The first NN.NN.NN triple in `<tool> version` output works for
        # golangci-lint ("has version v2.11.4 ..."), gosec ("Version: 2.22.5"),
        # gofumpt, gotestsum — the format is intentionally lax.
        "$tool" version 2>&1 \
            | sed -n 's/.*\bv\?\([0-9]\+\.[0-9]\+\.[0-9]\+\)\b.*/\1/p' \
            | head -n 1
    }

    local tool installed upstream
    for tool in golangci-lint gosec gofumpt gotestsum goimports ktn-linter; do
        case "$tool" in
            ktn-linter)
                # ktn-linter is published as a release binary on GitHub, NOT as a Go
                # module — `go install ktn-linter@latest` silently fails (not a valid
                # module path). Must download the release asset directly, and do it
                # HERE at runtime so the write lands in the already-mounted
                # package-cache volume (build-time writes under $GOPATH/bin are
                # masked by the volume at container start).
                if ! command -v ktn-linter &>/dev/null; then
                    echo "    installing ktn-linter..."
                    curl -fsSL --connect-timeout 10 --max-time 60 \
                         "https://github.com/kodflow/ktn-linter/releases/latest/download/ktn-linter-linux-${GO_ARCH}" \
                         -o "$GOPATH/bin/ktn-linter" 2>/dev/null \
                        && chmod +x "$GOPATH/bin/ktn-linter" \
                        || true
                fi
                ;;
            *)
                if [ -n "${GO_TOOL_REPOS[$tool]:-}" ]; then
                    # Auto-refresh path: probe upstream, reinstall on drift. A
                    # missing binary or any version mismatch triggers reinstall.
                    # Network/rate-limit failure → leave the existing binary in
                    # place rather than blow away a working install.
                    installed=$(installed_tool_version "$tool")
                    upstream=$(upstream_latest_version "${GO_TOOL_REPOS[$tool]}")
                    if [ -z "$upstream" ]; then
                        # Network or rate-limit; ensure something is installed.
                        if [ -z "$installed" ]; then
                            echo "    ${tool}: upstream probe failed and tool missing — installing latest (best-effort)..."
                            install_go_tool_latest "$tool" || true
                        fi
                        continue
                    fi
                    if [ "$installed" != "$upstream" ]; then
                        echo "    ${tool}: ${installed:-none} → ${upstream}"
                        install_go_tool_latest "$tool" || true
                    fi
                else
                    # No repo mapping → install only if missing (gofumpt,
                    # gotestsum, goimports — none have shipped an EOL major).
                    if ! command -v "$tool" &>/dev/null; then
                        echo "    installing ${tool}..."
                        install_go_tool_latest "$tool" || true
                    fi
                fi
                ;;
        esac
    done
}

sync_python() {
    if ! command -v python3 &>/dev/null; then
        echo "  python: binary missing (requires rebuild)"
        return 1
    fi
    local tools=(ruff pylint mypy bandit pytest)
    for tool in "${tools[@]}"; do
        command -v "$tool" &>/dev/null || python3 -m pip install --quiet "$tool" 2>/dev/null || true
    done
}

sync_node() {
    if ! command -v node &>/dev/null; then
        echo "  node: binary missing (requires rebuild)"
        return 1
    fi
}

echo "Syncing toolchains (image → volume)..."
for marker in "${VERSIONS_DIR}"/*; do
    [ -f "$marker" ] || continue
    lang=$(basename "$marker")
    sync_lang "$lang"
done
echo "Toolchain sync complete."
