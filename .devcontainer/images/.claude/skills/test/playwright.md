# Playwright MCP Integration

## MCP Tools Reference

<!-- Tool names verified against @playwright/mcp (microsoft/playwright-mcp,
     context7, 2026-06). Earlier rows named tools that never existed
     (browser_go_forward/reload, browser_fill, browser_screenshot,
     browser_expect) — challenge-setup-2026 audit, Q3. -->

### Navigation (`core-navigation`)

| Tool | Description |
|------|-------------|
| `browser_navigate` | Open a URL |
| `browser_navigate_back` | Previous page |

### Interaction (`core-input`)

| Tool | Description |
|------|-------------|
| `browser_click` | Click element |
| `browser_type` | Type text |
| `browser_fill_form` | Fill multiple form fields |
| `browser_select_option` | Select option |
| `browser_hover` | Hover element |
| `browser_press_key` | Press key |
| `browser_drag` | Drag and drop |
| `browser_file_upload` | Upload file(s) |

### Capture (`core`, `pdf`)

| Tool | Description |
|------|-------------|
| `browser_snapshot` | Accessibility tree (use this to act on elements) |
| `browser_take_screenshot` | Screenshot (visual only; cannot act from it) |
| `browser_pdf_save` | Generate PDF (requires `pdf` capability) |

### Inspect (`core`, `network`)

| Tool | Description |
|------|-------------|
| `browser_wait_for` | Wait for text/element/time |
| `browser_evaluate` | Run JS in the page |
| `browser_console_messages` | Read console output |
| `browser_network_requests` | List network requests (requires `network`) |

### Testing & tracing (`testing`)

| Tool | Description |
|------|-------------|
| `browser_verify_element_visible` | Assert an element (role + name) is visible |
| `browser_verify_text_visible` | Assert text is visible |
| `browser_verify_value` | Assert an input/control value |
| `browser_generate_locator` | Generate a reusable locator for tests |
| `browser_start_tracing` | Start trace recording |
| `browser_stop_tracing` | Stop trace recording |

> Assertions live in the `testing` capability; enable it in the MCP config
> (`capabilities: ['core','testing',…]`). There is **no** `browser_expect` —
> use the `browser_verify_*` family.

---

## Playwright MCP Capabilities

- **Navigation** - Open URLs, navigate, screenshots
- **Interaction** - Click, type, select, hover, drag
- **Assertions** - Verify text, elements, states
- **Tracing** - Record sessions for debugging
- **PDF** - Generate PDFs from pages
- **Codegen** - Generate test code

---

## Guardrails (ABSOLUTE)

| Action | Status | Reason |
|--------|--------|--------|
| Skip Phase 1 (Peek/Snapshot) | **FORBIDDEN** | Analyze page before interaction |
| Navigate to malicious sites | **FORBIDDEN** | Security |
| Enter real credentials | **WARNING** | Use fixtures |
| Modify production data | **FORBIDDEN** | Test environment only |

### Legitimate parallelization

| Element | Parallel? | Reason |
|---------|-----------|--------|
| E2E steps (navigate->fill->click) | No - Sequential | Interaction order required |
| Independent final assertions | Yes - Parallel | No dependency between checks |
| Screenshots + validations | Yes - Parallel | Independent operations |
