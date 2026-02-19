# Langages supportés

25 langages sont installés via des features DevContainer. Chacun est un script `install.sh` indépendant dans `.devcontainer/features/languages/`.

## Vue d'ensemble

| Langage | Linter | Formatter | Tests | Sécurité |
|---------|--------|-----------|-------|----------|
| **Python** | ruff, pylint | ruff | pytest | bandit |
| **Go** | golangci-lint | gofumpt | go test, gotestsum | gosec |
| **Node.js** | eslint | prettier | jest | npm audit |
| **Rust** | clippy | rustfmt | cargo test, cargo-nextest | cargo-deny |
| **Java** | checkstyle | — | junit | — |
| **C/C++** | clang-tidy | clang-format | googletest | cppcheck, valgrind |
| **C#** | fxcop | dotnet-format | nunit | — |
| **Ruby** | rubocop | rubocop | rspec | bundler-audit |
| **PHP** | phpstan | php-cs-fixer | phpunit | composer audit |
| **Kotlin** | detekt | ktlint | junit | — |
| **Swift** | swiftlint | swiftformat | xtest | — |
| **Scala** | scalastyle | scalafmt | scalatest | — |
| **Elixir** | credo | mix format | exunit | — |
| **Dart/Flutter** | dart analyzer | dartfmt | flutter test | — |
| **R** | lintr | styler | testthat | — |
| **Perl** | perl::critic | perl::tidy | — | — |
| **Lua** | luacheck | stylua | — | — |
| **Fortran** | fprettify | fprettify | — | — |
| **Ada** | — | — | — | — |
| **Pascal** | — | — | — | — |
| **Assembly** | — | — | — | — |
| **MATLAB/Octave** | — | — | — | — |
| **COBOL** | — | — | — | — |
| **VB.NET** | — | — | xunit | — |

## Fonctionnalités avancées

### Support WebAssembly

Go (via TinyGo), Rust, Node.js (via AssemblyScript), et C# supportent la compilation WebAssembly.

### Support Desktop

Go (Wails), Rust (Tauri), Node.js (Electron), C#, Swift, et Dart/Flutter supportent le développement d'applications desktop.

### Gestion de versions

Python (pyenv), Ruby (rbenv), PHP, Node.js (nvm), et Swift permettent de choisir la version via les options de la feature dans `devcontainer.json`.

## Comment ça s'installe

Chaque langage est un script `install.sh` qui :

1. Détecte l'architecture (amd64/arm64)
2. Télécharge les binaires précompilés (ou compile si indisponible)
3. Installe le linter, formatter, et outils de test en parallèle
4. Utilise `feature-utils.sh` pour la détection de version via l'API GitHub

Les installations sont parallélisées (`&` + `wait`) pour réduire le temps de build.
