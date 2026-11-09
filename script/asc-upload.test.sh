#!/usr/bin/env bash
# Tests for script/asc-upload.sh using stub uploaders.
#
# Why this exists: commit 879bb55 reworked the MAS upload step to kill the
# iTMSTransporter -10814 regression (a notice-only stub that LaunchServices
# cannot launch on GitHub runners). The script header claims it is "testable
# with stubs" and that TRANSPORTER_BIN is "also used by the tests to drive both
# branches" — but no test file was ever committed. This harness is that missing
# matrix. It is plain bash (bats is not installed on the macos-15 runner).
#
# What it proves:
#   1. altool happy path (exit 0 + evidence) -> asc-upload exits 0
#   2. altool exits 0 but prints NO evidence -> asc-upload exits 1 (the
#      notice-only stub regression: "exit 0" used to mean "uploaded")
#   3. altool exits non-zero -> asc-upload fails with that code, no silent reroute
#   4. Transporter branch (TRANSPORTER_BIN) exit 0 + evidence -> asc-upload exits 0
#   5. The -10814 guard: across the altool path, xcrun iTMSTransporter is NEVER
#      invoked. A fake xcrun logs every call; the log must contain no iTMSTransporter.
#
# Hermetic assumptions:
#   * /Applications/Transporter.app is NOT installed on the runner (it is not on
#     GitHub macos-15 images, and the project relies on that). The altool cases
#     unset TRANSPORTER_BIN so only the app-path candidate could match — and it
#     does not exist. If a real Transporter.app ever lands on a runner, the
#     altool cases would need TRANSPORTER_BIN pointed at a throwaway stub.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASC="$SCRIPT_DIR/asc-upload.sh"

pass=0
fail=0
WORK=""
STUB_BIN=""
PKG=""
CALL_LOG=""
ALTOOL_STUB=""

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"
    pass=$((pass + 1))
  else
    echo "  ✗ $desc (expected [$expected], got [$actual])"
    fail=$((fail + 1))
  fi
}

assert_log_absent() {
  local desc="$1" pattern="$2" log="$3"
  if ! grep -qF "$pattern" "$log" 2>/dev/null; then
    echo "  ✓ $desc"
    pass=$((pass + 1))
  else
    echo "  ✗ $desc (pattern [$pattern] found in log)"
    fail=$((fail + 1))
  fi
}

assert_log_present() {
  local desc="$1" pattern="$2" log="$3"
  if grep -qF "$pattern" "$log" 2>/dev/null; then
    echo "  ✓ $desc"
    pass=$((pass + 1))
  else
    echo "  ✗ $desc (pattern [$pattern] NOT found in log)"
    fail=$((fail + 1))
  fi
}

# Build a hermetic scenario: a temp dir with a fake xcrun (routes altool to a
# controllable stub and logs every call) plus an optional transporter stub.
#   $1 = altool mode: success | silent | fail
#   $2 = transporter stub source path (optional; empty disables)
make_scenario() {
  local altool_mode="$1" transporter_src="${2:-}"
  ASC_ALTOOL_MODE="$altool_mode"
  WORK="$(mktemp -d)"
  STUB_BIN="$WORK/bin"
  mkdir -p "$STUB_BIN"
  PKG="$WORK/pkg.dummy"
  : > "$PKG"
  CALL_LOG="$WORK/calls.log"
  : > "$CALL_LOG"

  ALTOOL_STUB="$STUB_BIN/altool"
  cat > "$ALTOOL_STUB" <<'STUB'
#!/bin/bash
# Behaviour driven by env vars exported by run_asc().
case "${ASC_ALTOOL_MODE:-}" in
  success) printf "No errors uploading\n"; exit 0 ;;
  silent)  exit 0 ;;
  fail)    exit "${ASC_ALTOOL_RC:-3}" ;;
  *)       exit 0 ;;
esac
STUB
  chmod +x "$ALTOOL_STUB"

  # Fake xcrun: log the call, route `altool` to our stub, delegate everything else.
  cat > "$STUB_BIN/xcrun" <<'XCRUN'
#!/bin/bash
echo "xcrun $*" >> "$ASC_CALL_LOG"
if [ "$1" = "altool" ]; then
  shift
  exec "$ASC_ALTOOL_STUB" "$@"
fi
exec /usr/bin/xcrun "$@"
XCRUN
  chmod +x "$STUB_BIN/xcrun"

  if [ -n "$transporter_src" ] && [ -f "$transporter_src" ]; then
    cp "$transporter_src" "$STUB_BIN/transporter"
    chmod +x "$STUB_BIN/transporter"
  fi
}

make_transporter_stub() {
  local f="$1"
  cat > "$f" <<'TP'
#!/bin/bash
echo "transporter-invoked" >> "$ASC_CALL_LOG"
echo "UPLOAD SUCCEEDED"
exit 0
TP
  chmod +x "$f"
}

run_asc() {
  # $1 = TRANSPORTER_BIN value (may be empty)
  # Emits ONLY the exit code; asc-upload.sh's own output goes to $WORK/asc.out.
  local tb="${1:-}"
  local out="$WORK/asc.out"
  : > "$out"
  (
    export PATH="$STUB_BIN:$PATH"
    export API_KEY_ID=TESTKEYID
    export API_ISSUER_ID=TESTISSUER
    export ASC_CALL_LOG="$CALL_LOG"
    export ASC_ALTOOL_STUB="$ALTOOL_STUB"
    export ASC_ALTOOL_MODE="${ASC_ALTOOL_MODE:-success}"
    export ASC_ALTOOL_RC=3
    if [ -n "$tb" ]; then export TRANSPORTER_BIN="$tb"; else unset TRANSPORTER_BIN; fi
    bash "$ASC" "$PKG" >>"$out" 2>&1
  )
  echo $?
}

cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; WORK=""; }
trap cleanup EXIT

echo "== asc-upload.sh stub matrix =="

# Case 1: altool success path.
echo "[1] altool success (exit 0 + evidence) -> asc-upload exits 0"
make_scenario success
rc="$(run_asc "")"
assert_eq "asc-upload exit code" "0" "$rc"
cleanup

# Case 2: altool silent (exit 0, no evidence) -> must FAIL.
echo "[2] altool exits 0 but no evidence -> asc-upload exits 1 (no silent success)"
make_scenario silent
rc="$(run_asc "")"
assert_eq "asc-upload exit code" "1" "$rc"
cleanup

# Case 3: altool failure (non-zero) -> must FAIL with that code.
echo "[3] altool exits non-zero -> asc-upload fails (no silent reroute)"
make_scenario fail
rc="$(run_asc "")"
assert_eq "asc-upload exit code" "3" "$rc"
cleanup

# Case 4: Transporter branch via TRANSPORTER_BIN, success evidence.
echo "[4] Transporter branch (TRANSPORTER_BIN) success -> asc-upload exits 0"
TP_SRC="$(mktemp)"
make_transporter_stub "$TP_SRC"
make_scenario success "$TP_SRC"
rc="$(run_asc "$STUB_BIN/transporter")"
assert_eq "asc-upload exit code" "0" "$rc"
assert_log_present "transporter was invoked" "transporter-invoked" "$CALL_LOG"
rm -f "$TP_SRC"
cleanup

# Case 5: -10814 regression guard — altool path must never call iTMSTransporter.
echo "[5] -10814 guard: altool path never invokes xcrun iTMSTransporter"
make_scenario success
rc="$(run_asc "")"
assert_eq "asc-upload exit code" "0" "$rc"
assert_log_absent "xcrun iTMSTransporter never called" "iTMSTransporter" "$CALL_LOG"
cleanup

echo ""
echo "== result: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
