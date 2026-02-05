# Vision & Objectives

## Purpose

Kodflow DevContainer Template provides a batteries-included VS Code Dev Container configuration for consistent, secure development environments across languages and tools.

## Goals

1. **Instant onboarding** - New projects bootstrap a complete dev workstation in seconds
2. **Consistency** - Same tooling, policies, and workflows across all projects
3. **Security-first** - Secrets management, compliance checks, and audit trails built-in
4. **AI-native** - Claude CLI integration with MCP servers for automated workflows

## Success Criteria

| Criterion | Target |
|-----------|--------|
| Container startup | < 60s on cached rebuild |
| Language support | Go, Python, Node, Rust, Java, PHP, Ruby, Elixir, Dart, Scala, C++, Carbon |
| MCP servers | GitHub, Codacy, Taskwarrior pre-configured |
| Security scans | Automatic on every edit (Codacy) |

## Design Principles

- **Progressive disclosure** - Basic info at root, details in subdirectories
- **Convention over configuration** - Sensible defaults, override when needed
- **Tooling transparency** - Document what's available, let devs choose
- **Fail-safe hooks** - Hooks protect files but never block legitimate work

## Non-Goals

- Not a deployment platform (dev environment only)
- Not prescriptive about application architecture
- Not a monorepo solution (single project focus)

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Ubuntu 24.04 base | LTS stability, wide package support |
| Named volumes for caches | Persist tooling state across rebuilds |
| MCP-first for integrations | Structured auth, no manual token handling |
| Specialist agents per language | Language experts know current best practices |
