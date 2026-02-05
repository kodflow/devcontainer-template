.PHONY: all build test lint fmt clean help

# {{PROJECT_NAME}} Makefile

{{#IF_GO}}
# Go targets
GO := go
GOFLAGS := -v

.PHONY: build
build:
	$(GO) build $(GOFLAGS) ./...

.PHONY: test
test:
	$(GO) test -race -cover ./...

.PHONY: lint
lint:
	golangci-lint run ./...

.PHONY: fmt
fmt:
	$(GO) fmt ./...
	goimports -w .

.PHONY: clean
clean:
	$(GO) clean
	rm -rf bin/
{{/IF_GO}}

{{#IF_RUST}}
# Rust targets
CARGO := cargo

.PHONY: build
build:
	$(CARGO) build

.PHONY: test
test:
	$(CARGO) test

.PHONY: lint
lint:
	$(CARGO) clippy -- -D warnings

.PHONY: fmt
fmt:
	$(CARGO) fmt

.PHONY: clean
clean:
	$(CARGO) clean
{{/IF_RUST}}

{{#IF_NODE}}
# Node.js targets
NPM := npm

.PHONY: build
build:
	$(NPM) run build

.PHONY: test
test:
	$(NPM) test

.PHONY: lint
lint:
	$(NPM) run lint

.PHONY: fmt
fmt:
	$(NPM) run format

.PHONY: clean
clean:
	rm -rf node_modules dist
{{/IF_NODE}}

{{#IF_PYTHON}}
# Python targets
PYTHON := python
PIP := pip

.PHONY: build
build:
	$(PIP) install -e .

.PHONY: test
test:
	pytest -v --cov

.PHONY: lint
lint:
	ruff check .
	mypy .

.PHONY: fmt
fmt:
	ruff format .

.PHONY: clean
clean:
	rm -rf __pycache__ .pytest_cache .mypy_cache dist *.egg-info
{{/IF_PYTHON}}

# Common targets
.PHONY: help
help:
	@echo "{{PROJECT_NAME}} - Available targets:"
	@echo "  make build   - Build the project"
	@echo "  make test    - Run tests"
	@echo "  make lint    - Run linters"
	@echo "  make fmt     - Format code"
	@echo "  make clean   - Clean build artifacts"
