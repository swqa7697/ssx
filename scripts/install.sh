#!/bin/bash
#
# Installs ssx for the current user:
#   1. requires a prepared ss-configs.jsonc in the repo root (aborts otherwise)
#   2. ensures dependencies (brew, shadowsocks-libev, jq)
#   3. deploys the config to ~/.config/ssx/ss-configs.jsonc
#   4. installs bin/ssx to ~/.local/bin
#
# Overridable via env (exported by the Makefile): BIN_NAME, BIN_DIR, CONFIG_DIR.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly BIN_NAME="${BIN_NAME:-ssx}"
readonly BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
readonly CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/ssx}"
readonly CONFIG_SRC="${REPO_ROOT}/ss-configs.jsonc"
readonly CONFIG_DEST="${CONFIG_DIR}/ss-configs.jsonc"

readonly C_RED=$'\033[31m'
readonly C_GREEN=$'\033[32m'
readonly C_YELLOW=$'\033[33m'
readonly C_RESET=$'\033[0m'

die() {
  echo "${C_RED}error:${C_RESET} $*" >&2
  exit 1
}

ok() {
  echo "${C_GREEN}ok:${C_RESET} $*"
}

notice() {
  echo "${C_YELLOW}notice:${C_RESET} $*"
}

# Aborts unless the repo's ss-configs.jsonc exists and is non-empty. Runs
# before ensure_deps so a missing config never triggers brew installs.
require_config() {
  [[ -s "${CONFIG_SRC}" ]] ||
    die "ss-configs.jsonc not found (or empty) in ${REPO_ROOT} — set up your profiles first:
  cp ss-configs.example.jsonc ss-configs.jsonc
  \${EDITOR:-vi} ss-configs.jsonc   # fill in your real servers
then re-run 'make install'."
}

# Strips full-line // comments so jq can parse the JSONC.
strip_comments() {
  grep -vE '^[[:space:]]*//' "$1" || true
}

# Validates that ss-configs.jsonc is a JSON object with at least one profile.
# Needs jq, so it runs after ensure_deps.
validate_config() {
  strip_comments "${CONFIG_SRC}" | jq -e 'type == "object"' >/dev/null 2>&1 ||
    die "ss-configs.jsonc does not parse — it must be a JSON object; only full-line // comments are allowed and trailing commas are not"
  strip_comments "${CONFIG_SRC}" | jq -e 'length > 0' >/dev/null 2>&1 ||
    die "ss-configs.jsonc defines no profiles — add at least one (see ss-configs.example.jsonc), then re-run 'make install'."
}

seed_config() {
  local backup
  if [[ ! -f "${CONFIG_DEST}" ]]; then
    install -m 600 "${CONFIG_SRC}" "${CONFIG_DEST}"
    ok "config seeded from ${CONFIG_SRC#"${REPO_ROOT}"/} -> ${CONFIG_DEST}"
  elif cmp -s "${CONFIG_SRC}" "${CONFIG_DEST}"; then
    ok "config unchanged (${CONFIG_DEST})"
  else
    backup="${CONFIG_DEST}.bak.$(date +%Y%m%d-%H%M%S)"
    cp -p "${CONFIG_DEST}" "${backup}"
    install -m 600 "${CONFIG_SRC}" "${CONFIG_DEST}"
    notice "config replaced from ${CONFIG_SRC#"${REPO_ROOT}"/} — previous version backed up to ${backup}"
  fi
}

install_bin() {
  install -m 755 "${REPO_ROOT}/bin/ssx" "${BIN_DIR}/${BIN_NAME}"
  ok "CLI installed: ${BIN_DIR}/${BIN_NAME}"
  case ":${PATH}:" in
    *":${BIN_DIR}:"*) ;;
    *)
      notice "${BIN_DIR} is not on your PATH — add this to ~/.zshrc:
  export PATH=\"${BIN_DIR}:\$PATH\""
      ;;
  esac
}

main() {
  require_config

  "${REPO_ROOT}/scripts/ensure_deps.sh"

  validate_config

  mkdir -p "${CONFIG_DIR}"
  chmod 700 "${CONFIG_DIR}"
  mkdir -p "${BIN_DIR}"

  seed_config
  install_bin

  echo ""
  echo "Done. Next steps:"
  echo "  ${BIN_NAME} list             # see available profiles"
  echo "  ${BIN_NAME} use <profile>    # pick one"
  echo "  ${BIN_NAME} on               # connect (SOCKS5 listener)"
  echo "  eval \"\$(${BIN_NAME} env)\"    # route curl/git/etc. through it"
}

main "$@"
