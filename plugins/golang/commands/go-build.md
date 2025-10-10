Build Go project with optimizations and cross-compilation support.

Compile your Go application with appropriate build flags and optimizations. This command will:
- Build the main package
- Apply standard optimizations
- Support cross-compilation for different platforms
- Generate build artifacts with version information

Usage:
- `/go-build` - Build for current platform
- `/go-build linux/amd64` - Cross-compile for Linux AMD64
- `/go-build darwin/arm64` - Cross-compile for macOS Apple Silicon
- `/go-build windows/amd64` - Cross-compile for Windows

Build options:
- Add `-ldflags` for stripping debug symbols
- Include version information
- Optimize binary size
- Enable/disable CGO

Common workflows:
1. Local development: `/go-build`
2. Production build: `/go-build -prod`
3. Multi-platform: `/go-build -all`
4. Docker image: `/go-build linux/amd64`

The command will validate dependencies and suggest improvements.
