#!/usr/bin/env bats
# Static validation tests for sync-toolchains.sh — issue #329.
# The previous `go install ${tool}@latest` was broken for tools that are not
# bare module names (golangci-lint, gosec, gofumpt, gotestsum) — failures were
# masked by `|| true`, so a stale volume kept v1.64.8 forever after v2 EOL.
# These tests pin the new structural guarantees:
#   - per-tool full module-path map exists for every Go module-installed tool
#   - golangci-lint and gosec are auto-refreshed against upstream (drift-resistant)
#   - ktn-linter still uses the binary download (not a Go module)

setup() {
    load '../helpers/setup'
    common_setup
    SYNC_SH="${BATS_TEST_DIRNAME}/../../.devcontainer/images/hooks/lifecycle/sync-toolchains.sh"
}

teardown() {
    common_teardown
}

@test "sync-toolchains.sh syntax is valid" {
    bash -n "$SYNC_SH"
}

@test "sync_go declares full module path for golangci-lint v2" {
    grep -qE '\[golangci-lint\]="github.com/golangci/golangci-lint/v2/cmd/golangci-lint"' "$SYNC_SH"
}

@test "sync_go declares full module path for gosec v2" {
    grep -qE '\[gosec\]="github.com/securego/gosec/v2/cmd/gosec"' "$SYNC_SH"
}

@test "sync_go declares full module path for gofumpt, gotestsum, goimports" {
    grep -qE '\[gofumpt\]="mvdan.cc/gofumpt"' "$SYNC_SH"
    grep -qE '\[gotestsum\]="gotest.tools/gotestsum"' "$SYNC_SH"
    grep -qE '\[goimports\]="golang.org/x/tools/cmd/goimports"' "$SYNC_SH"
}

@test "sync_go auto-refreshes golangci-lint against upstream (no static major pin)" {
    grep -qE '\[golangci-lint\]="golangci/golangci-lint"' "$SYNC_SH"
}

@test "sync_go auto-refreshes gosec against upstream (no static major pin)" {
    grep -qE '\[gosec\]="securego/gosec"' "$SYNC_SH"
}

@test "sync_go probes upstream via api.github.com releases/latest" {
    grep -qF 'api.github.com/repos/${repo}/releases/latest' "$SYNC_SH"
}

@test "sync_go honors GITHUB_TOKEN for upstream probe (rate-limit mitigation)" {
    grep -qF 'Authorization: token ${GITHUB_TOKEN}' "$SYNC_SH"
}

@test "sync_go does NOT use the broken bare-name 'go install \${tool}@latest'" {
    # Regression guard: the original ${tool}@latest call silently failed for
    # every non-module-name tool. New code routes through GO_TOOL_MODULES.
    ! grep -qE 'go install "\$\{?tool\}?@latest"' "$SYNC_SH"
}

@test "sync_go keeps ktn-linter on the binary-download path (not a Go module)" {
    grep -qF 'github.com/kodflow/ktn-linter/releases/latest/download/ktn-linter-linux-' "$SYNC_SH"
}

@test "sync_go preserves the existing tarball/binary-cache layout" {
    # GOPATH/bin is the install target; build-time installs land here too.
    grep -qE 'mkdir -p "\$\{GOPATH\}/bin"' "$SYNC_SH"
}

@test "sync_go skips reinstall when upstream probe fails AND tool is present" {
    # Network failure must NOT clobber a working binary. The branch that
    # handles `[ -z "$upstream" ]` only installs when the tool is missing.
    grep -A4 'upstream probe failed' "$SYNC_SH" | grep -q 'install_go_tool_latest'
    grep -B1 'upstream probe failed' "$SYNC_SH" | grep -q 'if \[ -z "\$installed" \]'
}
