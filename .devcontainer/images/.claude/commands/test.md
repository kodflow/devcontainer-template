---
name: test
description: |
  E2E and frontend testing with Playwright MCP.
  Automates browser interactions, visual testing, and debugging.
  Use when: running E2E tests, debugging frontend, generating test code.
allowed-tools:
  - "mcp__playwright__*"
  - "Bash(npm:*)"
  - "Bash(npx:*)"
  - "Read(**/*)"
  - "Write(**/*)"
  - "Glob(**/*)"
  - "Task(*)"
---

# Test - E2E & Frontend Testing (Playwright MCP)

$ARGUMENTS

---

## Description

Tests E2E et debugging frontend via **Playwright MCP**.

**Capacités :**

- **Navigation** - Ouvrir URLs, naviguer, screenshots
- **Interaction** - Click, type, select, hover, drag
- **Assertions** - Vérifier texte, éléments, états
- **Tracing** - Enregistrer les sessions pour debug
- **PDF** - Générer des PDFs de pages
- **Codegen** - Générer du code de test

---

## Arguments

| Pattern | Action |
|---------|--------|
| `<url>` | Ouvre l'URL et explore la page |
| `--run` | Exécute les tests Playwright du projet |
| `--debug <url>` | Mode debug interactif |
| `--trace` | Active le tracing pour la session |
| `--screenshot <url>` | Capture d'écran de la page |
| `--pdf <url>` | Génère un PDF de la page |
| `--codegen <url>` | Génère du code de test |
| `--help` | Affiche l'aide |

---

## --help

```
═══════════════════════════════════════════════
  /test - E2E & Frontend Testing (Playwright)
═══════════════════════════════════════════════

Usage: /test <url|action> [options]

Actions:
  <url>               Ouvre et explore la page
  --run               Exécute les tests du projet
  --debug <url>       Mode debug interactif
  --trace             Active le tracing
  --screenshot <url>  Capture d'écran
  --pdf <url>         Génère un PDF
  --codegen <url>     Génère du code de test

MCP Tools disponibles:
  browser_navigate    Ouvrir une URL
  browser_click       Cliquer sur un élément
  browser_type        Saisir du texte
  browser_snapshot    Capturer l'état de la page
  browser_screenshot  Capture d'écran
  browser_pdf_save    Générer un PDF
  browser_start_trace Démarrer le tracing
  browser_stop_trace  Arrêter et sauver la trace

Exemples:
  /test https://example.com
  /test --screenshot https://myapp.com/login
  /test --run
  /test --codegen https://myapp.com

═══════════════════════════════════════════════
```

---

## Workflow

### 1. Exploration de page

```yaml
workflow_explore:
  1_navigate:
    tool: mcp__playwright__browser_navigate
    params:
      url: "<url>"

  2_snapshot:
    tool: mcp__playwright__browser_snapshot
    output: "Accessibility tree de la page"

  3_analyze:
    action: "Analyser la structure, identifier les éléments"
```

### 2. Interaction

```yaml
workflow_interact:
  click:
    tool: mcp__playwright__browser_click
    params:
      element: "Submit button"
      ref: "<element_ref>"

  type:
    tool: mcp__playwright__browser_type
    params:
      element: "Email input"
      ref: "<element_ref>"
      text: "user@example.com"

  select:
    tool: mcp__playwright__browser_select_option
    params:
      element: "Country dropdown"
      ref: "<element_ref>"
      values: ["FR"]
```

### 3. Assertions (--caps testing)

```yaml
workflow_assert:
  expect_visible:
    tool: mcp__playwright__browser_expect
    params:
      expectation: "to_be_visible"
      ref: "<element_ref>"

  expect_text:
    tool: mcp__playwright__browser_expect
    params:
      expectation: "to_have_text"
      ref: "<element_ref>"
      expected: "Welcome"
```

### 4. Tracing (--caps tracing)

```yaml
workflow_trace:
  start:
    tool: mcp__playwright__browser_start_tracing
    params:
      name: "debug-session"

  # ... interactions ...

  stop:
    tool: mcp__playwright__browser_stop_tracing
    output: "trace.zip (viewable in trace.playwright.dev)"
```

---

## MCP Tools Reference

### Navigation

| Tool | Description |
|------|-------------|
| `browser_navigate` | Ouvrir une URL |
| `browser_go_back` | Page précédente |
| `browser_go_forward` | Page suivante |
| `browser_reload` | Rafraîchir |

### Interaction

| Tool | Description |
|------|-------------|
| `browser_click` | Cliquer sur élément |
| `browser_type` | Saisir du texte |
| `browser_fill` | Remplir un champ |
| `browser_select_option` | Sélectionner option |
| `browser_hover` | Survoler élément |
| `browser_drag` | Glisser-déposer |
| `browser_press_key` | Appuyer touche |

### Capture

| Tool | Description |
|------|-------------|
| `browser_snapshot` | Accessibility tree |
| `browser_screenshot` | Capture d'écran |
| `browser_pdf_save` | Générer PDF |

### Testing

| Tool | Description |
|------|-------------|
| `browser_expect` | Assertions |
| `browser_generate_locator` | Générer sélecteur |
| `browser_start_tracing` | Démarrer trace |
| `browser_stop_tracing` | Arrêter trace |

### Tabs

| Tool | Description |
|------|-------------|
| `browser_tab_list` | Lister onglets |
| `browser_tab_new` | Nouvel onglet |
| `browser_tab_select` | Changer onglet |
| `browser_tab_close` | Fermer onglet |

---

## Exemples d'utilisation

### Test de login

```
/test https://myapp.com/login

→ browser_navigate (url: https://myapp.com/login)
→ browser_snapshot (analyser le formulaire)
→ browser_type (email: user@test.com)
→ browser_type (password: ******)
→ browser_click (submit button)
→ browser_expect (dashboard visible)
```

### Debug avec trace

```
/test --trace https://myapp.com

→ browser_start_tracing (name: debug)
→ browser_navigate (url)
→ ... interactions ...
→ browser_stop_tracing
→ Output: trace.zip (open in trace.playwright.dev)
```

### Générer code de test

```
/test --codegen https://myapp.com

→ browser_navigate (url)
→ browser_snapshot
→ Générer code Playwright basé sur les interactions
```

---

## Configuration

Le MCP Playwright est configuré dans `mcp.json` :

```json
{
  "playwright": {
    "command": "npx",
    "args": [
      "-y",
      "@playwright/mcp@latest",
      "--headless",
      "--caps", "core,pdf,testing,tracing"
    ]
  }
}
```

**Capabilities activées :**

| Cap | Description |
|-----|-------------|
| `core` | Navigation, interaction, snapshots |
| `pdf` | Génération de PDFs |
| `testing` | Assertions, locator generation |
| `tracing` | Enregistrement de sessions |

---

## GARDE-FOUS

| Action | Status |
|--------|--------|
| Naviguer vers sites malveillants | ❌ **INTERDIT** |
| Saisir des credentials réels | ⚠ **WARNING** |
| Modifier des données en production | ❌ **INTERDIT** |

---

## Voir aussi

- `/review` - Review de code (peut inclure tests visuels)
- `/plan` - Planifier des tests E2E
- [Playwright Docs](https://playwright.dev)

