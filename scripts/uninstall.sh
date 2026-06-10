#!/bin/bash
#
# Uninstalls ssx: disconnects the proxy, then removes the installed CLI and
# config directory. KEEP_CONFIG=1 preserves ~/.config/ssx. Idempotent.
#
# Overridable via env (exported by the Makefile): BIN_NAME, BIN_DIR, CONFIG_DIR.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly BIN_NAME="${BIN_NAME:-ssx}"
readonly BIN_DIR="${BIN_DIR:-${HOME}/.local/bin}"
readonly CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/ssx}"
readonly KEEP_CONFIG="${KEEP_CONFIG:-0}"

readonly C_GREEN=$'\033[32m'
readonly C_YELLOW=$'\033[33m'
readonly C_RESET=$'\033[0m'

ok() {
  echo "${C_GREEN}ok:${C_RESET} $*"
}

notice() {
  echo "${C_YELLOW}notice:${C_RESET} $*"
}

# Ensures the proxy is disconnected: prefer the CLI's own off, then fall back
# to killing the recorded pid directly (only if it still is ss-local).
disconnect() {
  local pid_file="${CONFIG_DIR}/ss-local.pid" pid comm
  if [[ -x "${REPO_ROOT}/bin/ssx" ]]; then
    SSX_CONFIG_DIR="${CONFIG_DIR}" "${REPO_ROOT}/bin/ssx" off || true
  fi
  if [[ -f "${pid_file}" ]]; then
    pid="$(cat "${pid_file}" 2>/dev/null)"
    comm="$(ps -p "${pid}" -o comm= 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && [[ "${comm}" == *ss-local ]]; then
      kill "${pid}" 2>/dev/null || true
      notice "killed leftover ss-local (pid ${pid})"
    fi
    rm -f "${pid_file}"
  fi
}

main() {
  disconnect

  if [[ -e "${BIN_DIR}/${BIN_NAME}" ]]; then
    rm -f "${BIN_DIR}/${BIN_NAME}"
    ok "removed ${BIN_DIR}/${BIN_NAME}"
  else
    ok "no CLI at ${BIN_DIR}/${BIN_NAME} (already removed)"
  fi

  if [[ "${KEEP_CONFIG}" == "1" ]]; then
    notice "kept ${CONFIG_DIR} (KEEP_CONFIG=1)"
  elif [[ -d "${CONFIG_DIR}" ]]; then
    rm -rf "${CONFIG_DIR}"
    ok "removed ${CONFIG_DIR} (configs incl. server passwords)"
  else
    ok "no config dir at ${CONFIG_DIR} (already removed)"
  fi

  echo ""
  echo "ssx uninstalled. shadowsocks-libev itself was kept; remove it with:"
  echo "  brew uninstall shadowsocks-libev"
}

main "$@"
