SHELL := /bin/bash
.DEFAULT_GOAL := help

VERSION := $(shell cat VERSION 2>/dev/null | tr -d '\n' || echo "0.1.0")

# User-overridable install locations, e.g. `make install BIN_DIR=~/bin`.
BIN_NAME ?= ssx
BIN_DIR ?= $(HOME)/.local/bin
CONFIG_DIR ?= $(HOME)/.config/ssx

export BIN_NAME BIN_DIR CONFIG_DIR

.PHONY: help install setup uninstall test format tidy lint clean

help: ## Show this help message
	@echo "ssx $(VERSION) — shadowsocks-libev connection manager for macOS"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

install: ## Ensure brew deps, seed configs, install the ssx CLI
	@./scripts/install.sh

setup: install ## Alias for install

uninstall: ## Disconnect, remove the CLI and configs (KEEP_CONFIG=1 to keep configs)
	@./scripts/uninstall.sh

test: ## Run the smoke test suite (sandboxed, offline)
	@./scripts/test.sh

format: ## Format shell scripts with shfmt
	@./tidy.sh format

tidy: format ## Alias for format

lint: ## Lint shell scripts with shellcheck
	@./tidy.sh lint

clean: ## Remove test sandboxes and scratch files
	@rm -rf .tmp
	@echo "cleaned .tmp/"
