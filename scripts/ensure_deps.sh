#!/bin/bash
#
# Ensures system dependencies for ssx are present, installing the
# brew-managed ones when missing. Idempotent.

set -euo pipefail

readonly C_RED=$'\033[31m'
readonly C_GREEN=$'\033[32m'
readonly C_RESET=$'\033[0m'

die() {
  echo "${C_RED}error:${C_RESET} $*" >&2
  exit 1
}

ok() {
  echo "${C_GREEN}ok:${C_RESET} $*"
}

ensure_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    die "Homebrew is required but not installed — install it first:
  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"
then re-run 'make install'."
  fi
  ok "brew $(brew --version | head -1 | awk '{print $2}') ($(command -v brew))"
}

ensure_brew_pkg() {
  local cmd="$1" pkg="$2"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "installing ${pkg} via brew..."
    brew install "${pkg}"
  fi
  command -v "${cmd}" >/dev/null 2>&1 ||
    die "${cmd} still not found after 'brew install ${pkg}'"
  ok "${cmd} ($(command -v "${cmd}"))"
}

ensure_nc() {
  command -v nc >/dev/null 2>&1 ||
    die "nc not found — it ships with macOS at /usr/bin/nc"
  ok "nc ($(command -v nc))"
}

main() {
  ensure_brew
  ensure_brew_pkg ss-local shadowsocks-libev
  ensure_brew_pkg jq jq
  ensure_nc
}

main "$@"
