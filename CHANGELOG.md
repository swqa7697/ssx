# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.1.1] - 2026-06-10

### Added

- Add GitHub Actions CI running format check, lint, and the offline test suite on macOS

### Changed

- Resolve the CLI version from the `VERSION` file at runtime in a repo checkout, and freeze it into the installed copy during install so it no longer depends on the repo

## [0.1.0] - 2026-06-10

### Added

- Add `ssx` CLI to manage shadowsocks-libev (`ss-local`) client connections on macOS: `on`, `off`, `use`, `list`, `status`, `env`, `version`, `help`
- Add named server profiles via `~/.config/ssx/ss-configs.jsonc` (JSONC with full-line `//` comments), with `ss-configs.example.jsonc` as the committed template
- Add `env` command emitting `socks5h://` proxy exports so terminal tools resolve DNS through the tunnel
- Add `make install` / `make uninstall` with automatic dependency installation (`shadowsocks-libev`, `jq` via Homebrew), config validation, and idempotent profile deployment with backups
- Add sandboxed offline smoke test suite (`make test`) that never touches `~/.config/ssx`
- Add `make format` / `make lint` developer tooling via `tidy.sh` (shfmt, shellcheck)
