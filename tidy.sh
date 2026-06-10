#!/bin/bash
#
# Formats (shfmt) and lints (shellcheck) the project's shell scripts.
# Tools are brew-installed lazily on first use — they are dev-only deps.
#
# Usage: ./tidy.sh [format|lint]   (no arg = both)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
readonly FILES=(bin/ssx scripts/ensure_deps.sh scripts/install.sh scripts/uninstall.sh scripts/test.sh tidy.sh)

ensure_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "installing $1 via brew (dev tool)..."
    brew install "$1"
  fi
}

run_format() {
  ensure_tool shfmt
  (cd "${REPO_ROOT}" && shfmt -i 2 -ci -w "${FILES[@]}")
  echo "formatted: ${FILES[*]}"
}

run_lint() {
  ensure_tool shellcheck
  (cd "${REPO_ROOT}" && shellcheck "${FILES[@]}")
  echo "lint clean: ${FILES[*]}"
}

main() {
  case "${1:-all}" in
    format) run_format ;;
    lint) run_lint ;;
    all)
      run_format
      run_lint
      ;;
    *)
      echo "usage: ./tidy.sh [format|lint]" >&2
      exit 2
      ;;
  esac
}

main "$@"
