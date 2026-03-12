#!/bin/bash
# ============================================================================
# secure-archive.sh - Encrypt/decrypt files with AES-256-CBC + PBKDF2
#
# Usage:
#   secure-archive encrypt <output.enc> <path1> [path2 ...]
#   secure-archive decrypt <input.enc> [output-dir]
#
# Encryption: tar czf | openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -md sha512
# Password: prompted interactively via fd:3, never in args or env
# No temp files: pure pipe (tar → openssl → file)
#
# Compatible: OpenSSL 3.x (Linux), LibreSSL 3.6+ (macOS)
# ============================================================================

set -euo pipefail

CIPHER="aes-256-cbc"
ITER=600000
MD="sha512"

# ============================================================================
# Helpers
# ============================================================================

die() {
    echo "Error: $*" >&2
    exit 1
}

usage() {
    cat >&2 <<'EOF'
Usage:
  secure-archive encrypt <output.enc> <path1> [path2 ...]
  secure-archive decrypt <input.enc> [output-dir]

Examples:
  secure-archive encrypt backup.enc src/ docs/notes.txt
  secure-archive decrypt backup.enc /tmp/restored/
  encrypt secrets.enc ~/.ssh/id_rsa          # alias
  decrypt secrets.enc ~/restored/            # alias
EOF
    exit 2
}

check_openssl() {
    command -v openssl &>/dev/null || die "openssl not found in PATH"

    # Verify PBKDF2 support (OpenSSL 1.1.1+ or LibreSSL 3.6+)
    if ! openssl enc -${CIPHER} -pbkdf2 -P -pass pass:test -iter 1 &>/dev/null; then
        die "openssl does not support -pbkdf2 (need OpenSSL 1.1.1+ or LibreSSL 3.6+)"
    fi
}

read_password() {
    local prompt="$1"
    local var_name="$2"

    # Must have a terminal for interactive password input
    [ -t 0 ] || die "Cannot read password: stdin is not a terminal"

    local pw
    printf '%s' "$prompt" >&2
    IFS= read -rs pw </dev/tty
    echo >&2  # newline after hidden input

    if [ -z "$pw" ]; then
        die "Password cannot be empty"
    fi

    # Use nameref to set the caller's variable
    eval "$var_name=\$pw"
}

# ============================================================================
# Encrypt
# ============================================================================

do_encrypt() {
    [ $# -lt 2 ] && usage

    local output="$1"
    shift
    local paths=("$@")

    # Overwrite protection
    if [ -e "$output" ]; then
        die "Output file already exists: $output (remove it first)"
    fi

    # Validate all input paths exist
    for p in "${paths[@]}"; do
        [ -e "$p" ] || die "Path not found: $p"
    done

    check_openssl

    # Read and confirm password
    local password="" password_confirm=""
    read_password "Password: " password
    read_password "Confirm password: " password_confirm

    if [ "$password" != "$password_confirm" ]; then
        unset password password_confirm
        die "Passwords do not match"
    fi
    unset password_confirm

    # Encrypt: tar → openssl → file
    # Password passed via fd:3 (never in args or env)
    tar czf - "${paths[@]}" 2>/dev/null | \
        openssl enc -${CIPHER} -pbkdf2 -iter ${ITER} -md ${MD} -salt \
            -pass fd:3 -out "$output" \
            3<<< "$password"

    unset password

    local size
    size=$(stat -c%s "$output" 2>/dev/null || stat -f%z "$output" 2>/dev/null || echo "?")
    echo "Encrypted: $output ($size bytes)" >&2
}

# ============================================================================
# Decrypt
# ============================================================================

do_decrypt() {
    [ $# -lt 1 ] && usage

    local input="$1"
    local outdir="${2:-.}"

    [ -f "$input" ] || die "Input file not found: $input"

    check_openssl

    # Create output directory if needed
    if [ ! -d "$outdir" ]; then
        mkdir -p "$outdir" || die "Cannot create output directory: $outdir"
    fi

    # Read password
    local password=""
    read_password "Password: " password

    # Decrypt: file → openssl → tar
    # Password passed via fd:3 (never in args or env)
    openssl enc -d -${CIPHER} -pbkdf2 -iter ${ITER} -md ${MD} \
        -pass fd:3 -in "$input" \
        3<<< "$password" | \
        tar xzf - -C "$outdir"

    unset password

    echo "Decrypted to: $outdir" >&2
}

# ============================================================================
# Main dispatch
# ============================================================================

[ $# -lt 1 ] && usage

case "$1" in
    encrypt)
        shift
        do_encrypt "$@"
        ;;
    decrypt)
        shift
        do_decrypt "$@"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        die "Unknown command: $1 (use 'encrypt' or 'decrypt')"
        ;;
esac
