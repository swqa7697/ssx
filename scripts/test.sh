#!/bin/bash
#
# Frameworkless smoke test suite for ssx. Runs entirely against a sandbox
# config dir (SSX_CONFIG_DIR) — never touches ~/.config/ssx — and uses an
# unreachable upstream (127.0.0.1:9), which ss-local tolerates: the local
# SOCKS listener still comes up. Offline-safe.
#
# No `set -e`: failed checks are counted, reported, and turn into exit 1.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SSX="${REPO_ROOT}/bin/ssx"
readonly SANDBOX="${REPO_ROOT}/.tmp/test-$$"
export SSX_CONFIG_DIR="${SANDBOX}"

cleanup() {
  "${SSX}" off >/dev/null 2>&1 || true
  rm -rf "${SANDBOX}"
}
trap cleanup EXIT

TESTS=0
FAILS=0
OUT=""
RC=0

# Runs a command, capturing combined output into OUT and exit code into RC.
run() {
  OUT="$("$@" 2>&1)"
  RC=$?
}

# check <description> <predicate command...> — counts and reports one check.
check() {
  local desc="$1"
  shift
  TESTS=$((TESTS + 1))
  if "$@"; then
    echo "  PASS  ${desc}"
  else
    FAILS=$((FAILS + 1))
    echo "  FAIL  ${desc}"
    echo "        last rc=${RC}, output:"
    printf '%s\n' "${OUT}" | sed 's/^/        | /' | head -6
  fi
}

rc_is() { [[ "${RC}" -eq "$1" ]]; }
out_has() { [[ "${OUT}" == *"$1"* ]]; }
port_open() { nc -z 127.0.0.1 "$1" >/dev/null 2>&1; }
port_closed() { ! nc -z 127.0.0.1 "$1" >/dev/null 2>&1; }
proc_dead() { ! kill -0 "$1" 2>/dev/null; }

pick_free_port() {
  local p
  for ((p = $1; p < $1 + 200; p++)); do
    if port_closed "${p}"; then
      echo "${p}"
      return 0
    fi
  done
  echo "no free port found from $1" >&2
  return 1
}

# --- sandbox setup -----------------------------------------------------------

P1="$(pick_free_port 18388)" || exit 1
P2="$(pick_free_port $((P1 + 1)))" || exit 1

mkdir -p "${SANDBOX}"
cat >"${SANDBOX}/ss-configs.jsonc" <<EOF
// sandbox config — this full-line comment exercises the JSONC stripping
{
  "t1": {"server": "127.0.0.1", "server_port": 9, "local_port": ${P1}, "password": "x", "timeout": 60, "method": "aes-128-gcm"},
  "t2": {"server": "127.0.0.1", "server_port": 9, "local_port": ${P2}, "password": "x", "timeout": 60, "method": "aes-128-gcm"}
}
EOF

echo "ssx smoke tests (sandbox: ${SANDBOX}, ports: ${P1}/${P2})"

# --- static checks -----------------------------------------------------------

for f in bin/ssx scripts/ensure_deps.sh scripts/install.sh scripts/uninstall.sh scripts/test.sh tidy.sh; do
  run bash -n "${REPO_ROOT}/${f}"
  check "syntax: ${f}" rc_is 0
done

run bash -c "(grep -vE '^[[:space:]]*//' '${REPO_ROOT}/ss-configs.example.jsonc' || true) | jq -e 'type == \"object\"'"
check "ss-configs.example.jsonc parses as JSONC" rc_is 0

run "${SSX}" version
check "version matches VERSION file" out_has "$(cat "${REPO_ROOT}/VERSION")"

# Simulates install.sh's version freeze: a frozen copy in the sandbox has no
# ../VERSION beside it, so it must report the baked-in version, not a fallback.
FROZEN="${SANDBOX}/ssx-frozen"
sed 's/^SSX_VERSION=""$/SSX_VERSION="9.9.9-test"/' "${SSX}" >"${FROZEN}"
chmod +x "${FROZEN}"
run "${FROZEN}" version
check "frozen bin reports baked-in version" out_has "9.9.9-test"
check "  ...and exits 0" rc_is 0

# --- install config guard ----------------------------------------------------
# install.sh aborts before ensure_deps.sh when ss-configs.jsonc is missing or
# empty, so these paths are safe to exercise offline from a fake repo root.

FAKE_REPO="${SANDBOX}/fake-repo"
mkdir -p "${FAKE_REPO}/scripts"
cp "${REPO_ROOT}/scripts/install.sh" "${FAKE_REPO}/scripts/"

run bash "${FAKE_REPO}/scripts/install.sh"
check "install aborts when ss-configs.jsonc is missing" rc_is 1
check "  ...with setup guidance" out_has "cp ss-configs.example.jsonc ss-configs.jsonc"

: >"${FAKE_REPO}/ss-configs.jsonc"
run bash "${FAKE_REPO}/scripts/install.sh"
check "install aborts when ss-configs.jsonc is empty" rc_is 1
check "  ...with setup guidance" out_has "set up your profiles first"

# --- disconnected behavior ---------------------------------------------------

run "${SSX}" list
check "list shows t1" out_has "t1"
check "list shows t2" out_has "t2"

run "${SSX}" status
check "status exits 1 when disconnected" rc_is 1
check "status reports disconnected" out_has "disconnected"

run "${SSX}" on
check "on without a selected profile fails" rc_is 1
check "  ...with guidance" out_has "no profile selected"

run "${SSX}" use bogus
check "use of unknown profile fails" rc_is 1
check "  ...listing available profiles" out_has "available: t1, t2"

run "${SSX}" env
check "env fails when disconnected" rc_is 1

# --- connect lifecycle -------------------------------------------------------

run "${SSX}" use t1
check "use t1 succeeds" rc_is 0
check "  ...current file written" test "$(cat "${SANDBOX}/current")" = "t1"

run "${SSX}" on
check "on connects t1" rc_is 0
check "  ...SOCKS port ${P1} listening" port_open "${P1}"
check "  ...active.json is mode 600" test "$(stat -f '%Lp' "${SANDBOX}/active.json")" = "600"

PID1="$(cat "${SANDBOX}/ss-local.pid")"
run "${SSX}" on
check "second on is idempotent" rc_is 0
check "  ...says already connected" out_has "already connected"
check "  ...same daemon pid" test "$(cat "${SANDBOX}/ss-local.pid")" = "${PID1}"

run "${SSX}" status
check "status exits 0 when connected" rc_is 0
check "  ...reports listening" out_has "listening: yes"

run "${SSX}" env
check "env prints ALL_PROXY" out_has "export ALL_PROXY=\"socks5h://127.0.0.1:${P1}\""
check "env prints lowercase all_proxy" out_has "export all_proxy=\"socks5h://127.0.0.1:${P1}\""

run "${SSX}" use t2
check "use t2 while running reconnects" rc_is 0
check "  ...port ${P2} now listening" port_open "${P2}"
check "  ...port ${P1} released" port_closed "${P1}"

PID2="$(cat "${SANDBOX}/ss-local.pid")"
run "${SSX}" off
check "off disconnects" rc_is 0
check "  ...daemon gone" proc_dead "${PID2}"
check "  ...pidfile removed" test ! -f "${SANDBOX}/ss-local.pid"
check "  ...port ${P2} released" port_closed "${P2}"

run "${SSX}" off
check "off when already disconnected is friendly" rc_is 0
check "  ...says nothing to do" out_has "nothing to do"

# --- failure / recovery paths ------------------------------------------------

sleep 0.1 &
STALE_PID=$!
wait "${STALE_PID}" 2>/dev/null
echo "${STALE_PID}" >"${SANDBOX}/ss-local.pid"
run "${SSX}" status
check "stale pidfile reports disconnected" rc_is 1
check "  ...stale pidfile cleaned up" test ! -f "${SANDBOX}/ss-local.pid"

run "${SSX}" on
check "on recovers after stale pidfile" rc_is 0
run "${SSX}" off
check "  ...and off cleans up" rc_is 0

cp "${SANDBOX}/ss-configs.jsonc" "${SANDBOX}/good.jsonc"
echo '{ this is not json' >"${SANDBOX}/ss-configs.jsonc"
run "${SSX}" list
check "broken config fails" rc_is 1
check "  ...with parse guidance" out_has "cannot parse"

echo '{}' >"${SANDBOX}/ss-configs.jsonc"
run "${SSX}" list
check "empty config fails" rc_is 1
check "  ...with no-profiles guidance" out_has "no profiles defined"
mv "${SANDBOX}/good.jsonc" "${SANDBOX}/ss-configs.jsonc"

# --- summary -----------------------------------------------------------------

echo ""
if [[ "${FAILS}" -gt 0 ]]; then
  echo "FAILED: ${FAILS}/${TESTS} checks"
  exit 1
fi
echo "all ${TESTS} checks passed"
