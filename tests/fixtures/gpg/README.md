# GPG fixture keyring

Throw-away keys for bats tests of `postCreate.sh::step_gpg_signing` (#366).
Never used outside `tests/`. Committed checked-in to avoid runtime
`--quick-generate-key` calls that block on CI entropy.

## Files

| File | Contents | UID |
|---|---|---|
| `pubkey.asc` | Public key (with-secret companion) | `test-with-secret@example.com` |
| `seckey.asc` | Secret key matching `pubkey.asc` | `test-with-secret@example.com` |
| `pubkey-only.asc` | Public-only key (no companion secret) | `test-pub-only@example.com` |

## Regeneration

```bash
GNUPGHOME=$(mktemp -d) && export GNUPGHOME && chmod 700 "$GNUPGHOME"
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "test-with-secret@example.com" rsa2048 default never
gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "test-pub-only@example.com" rsa2048 default never
gpg --armor --export test-with-secret@example.com           > pubkey.asc
gpg --armor --export-secret-keys --pinentry-mode loopback \
    --passphrase '' test-with-secret@example.com            > seckey.asc
gpg --armor --export test-pub-only@example.com              > pubkey-only.asc
```

## Security note

These keys are PUBLIC TEST FIXTURES. The secret key (`seckey.asc`) is exported
with an empty passphrase and committed to the repository. It must NEVER be
used to sign anything beyond test fixtures. Treat its key ID as a known
"do-not-trust" identifier.
