<!-- updated: 2026-02-12T17:00:00Z -->
# Lifecycle Hooks

## Purpose

DevContainer lifecycle scripts. All hooks except `initialize.sh` are delegation stubs
that forward to image-embedded implementations in `/etc/devcontainer-hooks/`.

## Scripts

| Script | Event | Type | Description |
|--------|-------|------|-------------|
| `initialize.sh` | onCreateCommand | Inline | Ollama install on host |
| `onCreate.sh` | onCreate | Stub | Delegates to image hook |
| `postCreate.sh` | postCreate | Stub | Delegates to image hook |
| `postAttach.sh` | postAttach | Stub | Delegates to image hook |
| `postStart.sh` | postStart | Stub | Delegates to image hook |
| `updateContent.sh` | updateContent | Stub | Delegates to image hook |

## Delegation Flow

```
Stub (workspace) → DEV (images/hooks/) or IMG (/etc/devcontainer-hooks/)
                 → EXT (hooks/project/) [optional]
```

- **DEV** priority: Template developers see changes immediately
- **IMG** priority: Downstream users get updates via image rebuild
- **EXT** hook: Projects can extend without modifying stubs

## Execution Order

1. initialize.sh (host, earliest)
2. onCreate.sh (stub → image hook)
3. postCreate.sh (stub → image hook)
4. postStart.sh (stub → image hook)
5. postAttach.sh (stub → image hook, latest)

## initialize.sh (Exception)

Runs on the **host machine** before container build. Cannot be image-embedded.
Extracts `OLLAMA_MODEL` dynamically from `grepai.config.yaml` (single source of truth).

## Conventions

- Do NOT add logic to stubs — modify image hooks in `images/hooks/lifecycle/`
- Image hooks use `set -u`, `run_step` pattern, `print_step_summary`
- Stubs must remain thin (~25 lines) for reliable delegation
