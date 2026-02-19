# Architecture

## Vue d'ensemble

Le DevContainer Template est organisé en 4 couches : l'image Docker de base, les features de langages, la configuration Claude Code, et les hooks d'automatisation.

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': {
  'primaryColor': '#9D76FB1a',
  'primaryBorderColor': '#9D76FB',
  'primaryTextColor': '#d4d8e0',
  'lineColor': '#d4d8e0',
  'textColor': '#d4d8e0',
  'secondaryColor': '#76FB9D1a',
  'secondaryBorderColor': '#76FB9D',
  'secondaryTextColor': '#d4d8e0',
  'tertiaryColor': '#FB9D761a',
  'tertiaryBorderColor': '#FB9D76',
  'tertiaryTextColor': '#d4d8e0'
}}}%%
flowchart TB
    subgraph IDE["VS Code / Codespaces"]
        U[Développeur]
    end

    subgraph DC["DevContainer"]
        subgraph BASE["Image de base (Ubuntu 24.04)"]
            TOOLS[Cloud CLIs<br/>Terraform, Vault<br/>Docker, kubectl]
            NET[VPN clients<br/>OpenVPN, WireGuard]
        end

        subgraph FEAT["Features (langages)"]
            L1[Python + ruff + pytest]
            L2[Go + golangci-lint]
            L3[Rust + clippy + cargo-nextest]
            LN[... 22 autres]
        end

        subgraph CLAUDE["Claude Code"]
            CMD[16 commandes<br/>/plan /do /review /git]
            AGT[57 agents<br/>orchestrators → specialists → executors]
            HK[8 hooks Claude<br/>format, lint, test, security]
        end

        subgraph MCP["Serveurs MCP"]
            G[grepai<br/>recherche sémantique]
            C7[context7<br/>docs à jour]
            GH[GitHub MCP<br/>PRs, issues]
            PW[Playwright<br/>tests E2E]
        end
    end

    U --> CMD
    CMD --> AGT
    AGT --> MCP
    HK -.->|auto| FEAT
    AGT --> FEAT

    classDef primary fill:#9D76FB1a,stroke:#9D76FB,color:#d4d8e0
    classDef data fill:#76FB9D1a,stroke:#76FB9D,color:#d4d8e0
    classDef async fill:#FB9D761a,stroke:#FB9D76,color:#d4d8e0
    classDef external fill:#6c76931a,stroke:#6c7693,color:#d4d8e0

    class CMD,AGT,HK primary
    class G,C7,GH,PW data
    class L1,L2,L3,LN async
    class TOOLS,NET external
```

## Structure des fichiers

```
.devcontainer/
├── devcontainer.json          # Point d'entrée VS Code
├── docker-compose.yml         # Service + 8 volumes
├── Dockerfile                 # Étend l'image de base
├── .env.tpl                   # Template des variables d'env
├── features/
│   └── languages/             # 25 installeurs (1 par langage)
│       ├── shared/            # feature-utils.sh (utilitaires partagés)
│       ├── go/install.sh
│       ├── python/install.sh
│       └── ...
├── hooks/
│   └── lifecycle/             # Stubs de délégation
│       ├── initialize.sh      # → host (Ollama, .env)
│       ├── postCreate.sh      # → /etc/devcontainer-hooks/
│       └── postStart.sh       # → /etc/devcontainer-hooks/
└── images/
    ├── Dockerfile             # Image de base (Ubuntu + outils)
    ├── mcp.json.tpl           # Template MCP (tokens injectés)
    ├── grepai.config.yaml     # Config recherche sémantique
    ├── hooks/                 # Vrais hooks (embarqués dans l'image)
    │   ├── shared/utils.sh    # 367 lignes d'utilitaires
    │   └── lifecycle/         # onCreate, postCreate, postStart
    └── .claude/
        ├── commands/          # 16 commandes (markdown)
        ├── agents/            # 57 agents (markdown)
        ├── scripts/           # 15 scripts hooks Claude
        ├── docs/              # 162 patterns de design
        └── settings.json      # Config Claude Code
```

## Système d'agents

57 agents organisés en hiérarchie à 3 niveaux :

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': {
  'primaryColor': '#9D76FB1a',
  'primaryBorderColor': '#9D76FB',
  'primaryTextColor': '#d4d8e0',
  'lineColor': '#d4d8e0',
  'textColor': '#d4d8e0'
}}}%%
flowchart TD
    subgraph ORCH["Orchestrateurs (2 — opus)"]
        DO[developer-orchestrator]
        OO[devops-orchestrator]
    end

    subgraph SPEC["Spécialistes (35 — sonnet)"]
        LS[26 langages<br/>Go, Python, Rust<br/>Java, C++, Ruby...]
        IS[9 infrastructure<br/>AWS, Azure, GCP<br/>Docker, K8s, Security]
    end

    subgraph EXEC["Exécuteurs (11 — haiku/opus)"]
        DE[5 dev executors<br/>correctness, security<br/>design, quality, shell]
        PE[6 platform executors<br/>Linux, macOS, BSD<br/>Windows, QEMU, VMware]
    end

    subgraph DOCS["Analyseurs docs (9 — haiku)"]
        DA[languages, commands<br/>agents, hooks, mcp<br/>patterns, structure<br/>config, architecture]
    end

    DO --> LS
    DO --> DE
    OO --> IS
    OO --> PE
```

| Niveau | Nombre | Modèle | Rôle |
|--------|--------|--------|------|
| Orchestrateur | 2 | Opus | Décompose la tâche, coordonne les sous-agents |
| Spécialiste | 35 | Sonnet | Expertise dans un langage ou domaine infra |
| Exécuteur | 11 | Haiku/Opus | Analyse ciblée (sécurité, qualité, correctness) |
| Analyseur docs | 9 | Haiku/Sonnet | Analyse du codebase pour `/docs` |

**Comment c'est utilisé** : quand vous tapez `/review`, le `developer-specialist-review` lance 5 exécuteurs en parallèle. Quand vous tapez `/plan`, l'orchestrateur consulte le spécialiste du langage détecté et les patterns dans `~/.claude/docs/`.

## Pattern de délégation des hooks

Les hooks de cycle de vie utilisent un pattern à deux couches :

1. **Stubs workspace** (`.devcontainer/hooks/lifecycle/`) : scripts courts qui délèguent
2. **Hooks image** (`/etc/devcontainer-hooks/lifecycle/`) : vrais scripts embarqués dans le Docker

Avantage : les hooks se mettent à jour automatiquement quand l'image est reconstruite, sans modifier le workspace.

```bash
# Exemple de stub (postStart.sh dans le workspace)
#!/bin/bash
exec /etc/devcontainer-hooks/lifecycle/postStart.sh "$@"
```

## Restauration au démarrage

`postStart.sh` restaure les fichiers Claude depuis `/etc/claude-defaults/` à chaque démarrage. Ce mécanisme garantit que les commandes, agents et scripts sont toujours à jour avec l'image, même si le volume `~/.claude` contient d'anciennes versions.

Fichiers restaurés :
- `~/.claude/commands/` (16 commandes)
- `~/.claude/scripts/` (15 scripts hooks)
- `~/.claude/agents/` (57 agents)
- `~/.claude/docs/` (162 patterns)
