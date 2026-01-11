# Language Features

## Purpose

Language-specific installation scripts. Conventions handled by specialist agents.

## Available Languages

| Language | Version | Agent |
|----------|---------|-------|
| Go | >= 1.25.0 | `developer-specialist-go` |
| Node.js | >= 25.0.0 | `developer-specialist-nodejs` |
| Python | >= 3.14.0 | `developer-specialist-python` |
| Rust | >= 1.92.0 | `developer-specialist-rust` |
| Elixir | >= 1.19.0 | `developer-specialist-elixir` |
| Java | >= 25 | `developer-specialist-java` |
| PHP | >= 8.5.0 | `developer-specialist-php` |
| Ruby | >= 4.0.0 | `developer-specialist-ruby` |
| Scala | >= 3.7.0 | `developer-specialist-scala` |
| Dart/Flutter | >= 3.10/3.38 | `developer-specialist-dart` |
| C++ | >= C++23 | `developer-specialist-cpp` |
| Carbon | >= 0.1.0 | `developer-specialist-carbon` |

## Per-Language Structure

```text
<language>/
└── install.sh    # Installation script
```

## Version Discovery

Agents use WebFetch on official sources to get latest versions dynamically.
No static version files needed.

## Conventions

- All code in /src regardless of language
- Tests in /tests (except Go: alongside code)
- Specialist agents enforce academic standards
