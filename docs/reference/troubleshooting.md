# Troubleshooting

## Common Issues

### The container does not start

**Symptom**: error on `Reopen in Container`

1. Check that Docker is running: `docker ps`
2. Check disk space: `docker system df`
3. Clean up if needed: `docker system prune`
4. Rebuild without cache: `Ctrl+Shift+P` → `Dev Containers: Rebuild Without Cache`

### RTK is not rewriting commands

**Symptom**: `rtk gain` shows zero savings, or commands run raw

1. Check the binary: `rtk --version` (and `rtk verify` for upstream confirmation)
2. Check the plugin: `claude plugin list | grep kodflow-hooks` — the rewrite is the
   transform stage of `on-tool.sh` (`PreToolUse`), not a standalone hook entry
3. Check stderr for `[rtk] WARNING:` lines on session start
4. If still broken: `rm -rf ~/.cache/rtk && rtk init -g --no-patch`

> Note: `settings.json` no longer carries a `hooks` block or an `rtk hook`
> entry — `postStart.sh` (`step_rtk_claude_init`) strips any leftover entry
> from an older image or a manual `rtk init -g`, since a second rewrite
> running in parallel with the plugin would double-rewrite the same command.

### MCP tokens are not recognized

**Symptom**: `mcp__github__*` returns auth errors

1. Check that `.devcontainer/.env` contains the correct token
2. Rebuild the container (`.env` is read at startup)
3. Check the generated `mcp.json`: `cat /workspace/mcp.json`

### Post-edit hooks fail

**Symptom**: lint/format errors after each edit

1. The formatter is the observe stage of `on-tool.sh` (`PostToolUse`, `kodflow-hooks`
   plugin) and is **non-blocking**: the error is displayed but does not block Claude
2. If a formatter is not installed for your language, the hook detects this and skips it
3. Hooks ship in the `kodflow-hooks` plugin, not in `settings.json` (no `hooks`
   block there anymore) — to disable one, uninstall or downgrade the plugin
   with `claude plugin`

### VPN does not connect

**Symptom**: no VPN interface after container start

VPN connect is automatic (`postStart.sh`, `init_vpn`, backgrounded — not a skill):

1. Check that `OP_SERVICE_ACCOUNT_TOKEN` and `VPN_CONFIG_REF` (or the legacy
   `OPENVPN_CONFIG_REF`) are configured, and that the profile exists in 1Password
2. Check the init log: `cat /tmp/vpn-init.log`
3. Check Docker capabilities: `NET_ADMIN` and `/dev/net/tun` must be enabled (this is the default in `docker-compose.yml`)

### Missing Claude files at startup

**Symptom**: `scripts/`, `docs/` or `templates/` missing under `~/.claude/`

`postStart.sh` restores these from `/etc/claude-defaults/` and cleans any legacy
`commands/`, `agents/`, `workflows/` left by an older image (they would run
beside their marketplace plugin twin). If the issue persists:

```bash
# Manual restoration
cp -r /etc/claude-defaults/* ~/.claude/
```

**Symptom**: skills or agents not found

Skills and agents come from the marketplace, not from `/etc/claude-defaults/`.
See "Marketplace plugins fail to install" below.

### Commit is blocked

**Symptom**: a `git commit` is rejected

The git guard is the block stage of `on-tool.sh` (`PreToolUse`, `kodflow-hooks`
plugin). It blocks `--no-verify`/`-n`, AI attribution or a `.claude/` path in
the commit message, and a credential shape in the staged files. This is
intentional. Check `git diff --cached` and remove the secret or the disallowed
text.

### Marketplace plugins fail to install

**Symptom**: `/project`, `/plan`, `/review` or other skills not found; `on-tool.sh` / `on-stop.sh` not firing

`postStart.sh` (`step_marketplace_install`) registers the `kodflow` marketplace
(https://github.com/kodflow/claude-marketplace) and installs/updates
`kodflow-workflow`, `kodflow-review`, `kodflow-devops`, `kodflow-specialists`
and `kodflow-hooks` on every start. It is fail-open: offline, it warns and
keeps the cached plugins working.

1. Check what is registered: `claude plugin marketplace list` and `claude plugin list`
2. Re-run manually: `claude plugin marketplace add https://github.com/kodflow/claude-marketplace`
   then `claude plugin install <name>@kodflow` for any plugin listed as missing
3. On the host (outside the container), `.devcontainer/install.sh`
   (`install_marketplace`) and the `claude` devcontainer feature do the same

## Quick Checks

```bash
# General status
docker ps                           # Container running?
cat /workspace/mcp.json             # MCP configured?
echo $SHELL                         # Should be /bin/zsh
claude plugin list                  # Marketplace plugins installed (skills, agents, hooks)?
ls ~/.claude/scripts/                # Quality scripts present (7)?

# Services
curl -s http://host.docker.internal:11434/api/tags  # Ollama?
op --version                        # 1Password CLI?
```
