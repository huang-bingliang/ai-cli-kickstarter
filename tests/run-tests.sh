#!/usr/bin/env bash
# Offline smoke tests for kickstarter.sh: drives the state machine with
# scripted stdin and a stubbed curl. No network access, no dependencies.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STUBS="$ROOT/tests/stubs"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
RC=""
OUT=""
RUN_COUNT=0
BASH_BIN="${BASH:-bash}"

# Runs kickstarter.sh with the given stdin payload and curl stub mode,
# in an isolated HOME and a minimal PATH. Kills the run after 15s so a
# regression to the old infinite redraw loop fails instead of hanging.
run_kickstarter(){
  local input="$1" mode="$2"
  RUN_COUNT=$((RUN_COUNT + 1))
  local run_home="$WORK/home-$RUN_COUNT"
  mkdir -p "$run_home"
  printf '%s' "$input" > "$WORK/stdin"
  env HOME="$run_home" PATH="$STUBS:/usr/bin:/bin" CURL_STUB_MODE="$mode" TERM=dumb \
    "$BASH_BIN" "$ROOT/kickstarter.sh" < "$WORK/stdin" > "$WORK/out" 2>&1 &
  local pid=$! waited=0
  RC="timeout"
  while :; do
    if ! kill -0 "$pid" 2>/dev/null; then
      wait "$pid"
      RC=$?
      break
    fi
    if [ "$waited" -ge 15 ]; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      RC="timeout"
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  OUT="$(cat "$WORK/out")"
}

contains(){ case "$OUT" in *"$1"*) return 0;; *) return 1;; esac; }

check(){
  local desc="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
    echo "PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  RC=$RC"
    printf '%s\n' "$OUT" | head -30 | sed 's/^/  | /'
  fi
}

not(){ ! "$@"; }
rc_is(){ [ "$RC" = "$1" ]; }
rc_nonzero(){ [ "$RC" != "timeout" ] && [ "$RC" != "0" ]; }

echo "== closed stdin exits immediately, installs nothing =="
run_kickstarter '' ok
check "exits with nonzero status" rc_nonzero
check "does not run the installer" not contains "Running the official installer"

echo "== EOF after language selection does not auto-install =="
run_kickstarter $'2\n' ok
check "exits with nonzero status" rc_nonzero
check "does not run the installer" not contains "Running the official installer"

echo "== failed download reaches the ERROR state =="
run_kickstarter $'2\n1\n3\n\n' fail
check "reports installation failure" contains "Installation failed"
check "names the download as the cause" contains "download failed"
check "does not reach VERIFY" not contains "Verifying"
check "exits cleanly after user chooses exit" rc_is 0

echo "== unexpected redirect is rejected before execution =="
run_kickstarter $'2\n1\n3\n\n' redirect
check "reports installation failure" contains "Installation failed"
check "names the redirect as the cause" contains "unexpected installer redirect"
check "does not execute the installer" not contains "installer-ran"
check "exits cleanly" rc_is 0

echo "== installer runs but missing command requires restart =="
run_kickstarter $'2\n1\ny\n2\n\n' ok
check "executes the downloaded installer" contains "installer-ran"
check "reaches VERIFY" contains "Verifying"
check "reports command not on PATH yet" contains "not visible yet"
check "does not show the handoff prompt" not contains "Copy the handoff prompt"
check "exits cleanly" rc_is 0

echo "== successful install reaches HANDOFF and exits cleanly =="
run_kickstarter $'2\n1\ny\nn\n\n' installed
check "executes the downloaded installer" contains "installer-ran"
check "reports installation success" contains "Installation succeeded"
check "shows the handoff instructions" contains "Copy the handoff prompt"
check "exits cleanly" rc_is 0

echo "== empty confirmation defaults to no =="
run_kickstarter $'2\n1\n\n\n' ok
check "does not run the installer" not contains "Running the official installer"
check "exits cleanly" rc_is 0

echo "== Kimi selection uses the current installer URL =="
run_kickstarter $'2\n2\n\n\n' ok
check "uses the current Kimi installer" contains "https://code.kimi.com/kimi-code/install.sh"
check "does not use the deprecated Kimi endpoint" not contains "https://code.kimi.com/install.sh"
check "exits cleanly" rc_is 0

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
