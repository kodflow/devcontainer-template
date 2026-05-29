<!-- scenario-contract v1
name: security
selects_when: --security flag, or a diff touching auth/crypto/secrets/network surface
lenses: [taint-source-to-sink, owasp-top-10, secrets, supply-chain]
writes: .claude/plans/review-fixes-<timestamp>.md
engine: workflow
-->

# /review scenario — `security`

Deep security review. Selected by `--security` or when the diff touches an
auth / crypto / secrets / network surface.

## Lenses

| Lens | Focus |
|---|---|
| taint-source-to-sink | untrusted input → dangerous sink paths |
| owasp-top-10 | injection, broken auth, SSRF, etc. |
| secrets | hardcoded credentials / tokens / keys |
| supply-chain | dependency + build-step risk |

Confirmed findings are written to a `review-fixes-<timestamp>` plan under
`.claude/plans/` for `/goal` execution. No disk writes outside that authorized dir.
