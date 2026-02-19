# Changelog

Changements notables du devcontainer-template, générés depuis les commits conventionnels.

## Récent

### Features

- **update**: Profile-aware sync with git tarball download ([#201](https://github.com/kodflow/devcontainer-template/pull/201))
- **skills**: Enrich 6 skills with 16 targeted improvements ([#199](https://github.com/kodflow/devcontainer-template/pull/199))
- **hooks**: Delegate lifecycle hooks to image-embedded scripts ([#187](https://github.com/kodflow/devcontainer-template/pull/187))
- **versions**: Convert all version pins to dynamic latest resolution ([#183](https://github.com/kodflow/devcontainer-template/pull/183))
- **vpn**: Add multi-protocol VPN clients and network tools ([#174](https://github.com/kodflow/devcontainer-template/pull/174))
- **languages**: Add cross-language parity for 26 languages ([#180](https://github.com/kodflow/devcontainer-template/pull/180))

### Fixes

- **hooks**: Skip shared directory in feature validation
- **grepai**: Clean stale index.gob.lock on daemon start ([#192](https://github.com/kodflow/devcontainer-template/pull/192))
- **hooks**: Prevent exit code 1 leak and improve grepai observability ([#191](https://github.com/kodflow/devcontainer-template/pull/191))
- **grepai**: Launch watchdog even when Ollama unavailable at startup ([#190](https://github.com/kodflow/devcontainer-template/pull/190))
- **hooks**: Remove executable bit from sourced utils.sh ([#189](https://github.com/kodflow/devcontainer-template/pull/189))
- **grepai**: Add multi-factor health stamp and watchdog for robust init ([#185](https://github.com/kodflow/devcontainer-template/pull/185))
- **hooks**: Non-blocking lifecycle scripts with run_step pattern ([#175](https://github.com/kodflow/devcontainer-template/pull/175))

### Performance

- **docker**: Consolidate Dockerfile layers from ~37 to 15 ([#184](https://github.com/kodflow/devcontainer-template/pull/184))
- **features**: Optimize all 25 language install.sh scripts ([#193](https://github.com/kodflow/devcontainer-template/pull/193))

### Documentation

- **commands**: Add interview mode and complexity check ([#198](https://github.com/kodflow/devcontainer-template/pull/198))
- **claude-md**: Deep update all 15 CLAUDE.md with verified content ([#194](https://github.com/kodflow/devcontainer-template/pull/194))
- **i18n**: Translate all French content to English ([#195](https://github.com/kodflow/devcontainer-template/pull/195))
