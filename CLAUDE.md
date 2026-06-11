# CLAUDE.md

Development guidelines for `ssx` — a bash CLI managing shadowsocks-libev
(`ss-local`) client connections on macOS.

## Project Structure

- `bin/ssx` — the single self-contained CLI. **Must stay macOS system bash 3.2
  compatible**: no associative arrays, no `${var,,}`, no `mapfile`/`readarray`,
  no `&>>`, no bash-4+ features.
- `scripts/` — `install.sh`, `uninstall.sh`, `ensure_deps.sh`, `test.sh`.
- `Makefile` — entry point for everything (`make help` lists targets).
- `VERSION` — single source of truth for the version. `bin/ssx` resolves it at
  runtime in a repo checkout; `install.sh` freezes it into the installed copy.
- `ss-configs.jsonc` is gitignored (holds passwords); edit
  `ss-configs.example.jsonc` for template changes.

## Shell Style

- Every script: `#!/bin/bash` + `set -euo pipefail`, `readonly` for constants,
  lowercase `snake_case` functions, a `main "$@"` entry point.
- Formatting is shfmt with `-i 2 -ci` (2-space indent, indented case branches).
- New shell scripts must be added to the `FILES` array in `tidy.sh` or they
  are silently skipped by format/lint.
- Keep `bin/ssx` self-contained — it must work when copied alone to
  `~/.local/bin`. Shared logic with `scripts/` is duplicated deliberately.
- YAGNI: this is a small tool; do not add abstractions, flags, or config
  options beyond what is needed now. Delete dead code, never comment it out.

## Quality Assurance

Run in order before every commit; fix code (not tests) until green:

1. `make format` — shfmt (brew-installed lazily)
2. `make lint` — shellcheck, must be clean
3. `make test` — sandboxed offline smoke suite

Tests live in `scripts/test.sh`. They are **sandboxed and offline**: they use
`SSX_CONFIG_DIR` pointed at `.tmp/` and must never touch `~/.config/ssx`,
start real network connections, or require a server. Add a test case for any
new command or changed behavior, following the existing assert helpers.

## Git Workflow

- Never commit directly to `main` — branch first, open a PR.
- Branch names: `feat/<topic>`, `fix/<topic>`, `chore/<topic>`, `<user.name>/<topic>`.

## Commit Messages

Conventional Commits (commitizen style):

```
<type>(<scope>): <short summary>
```

- **type:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
  `build`, `ci`, `chore`, `revert`.
- **scope** (optional): `cli` (bin/ssx), `install`, `uninstall`, `deps`,
  `test`, `make`, `config`.
- Summary: imperative mood, lowercase, no period, ≤ 72 chars. Optional body
  after a blank line explains what and why, wrapped at 72 chars.

Examples:

```
feat(cli): add reconnect-on-use when a different profile is active

fix(install): back up deployed config before overwriting on re-install
```

## Changelog

`CHANGELOG.md` follows Keep a Changelog + Semantic Versioning.

- Every user-visible change (feature, fix, removal, behavior change) gets a
  bullet under `## [Unreleased]` in the same commit. Create that section at
  the top if it doesn't exist. Skip internal refactors and formatting-only
  changes.
- Categories (only those that apply): `Added`, `Changed`, `Deprecated`,
  `Removed`, `Fixed`, `Security`. Bullets start with an imperative verb.
- **Release rule:** when releasing a version, substitute the `[Unreleased]`
  section title with `[X.Y.Z] - YYYY-MM-DD` in place — do **not** append a
  new version section below it while keeping `[Unreleased]`. A fresh
  `[Unreleased]` section is created later, when the next unreleased change
  lands.

## Releasing a Version

1. Bump `VERSION` (the only file carrying the version; Makefile, `bin/ssx`,
   and `install.sh` all read it).
2. Rename `[Unreleased]` in `CHANGELOG.md` to the new version per the release
   rule above.
3. `make format && make lint && make test` must pass.
4. Commit as `chore: release vX.Y.Z`.
