#!/bin/sh
# build_all.sh -- compile all five example apps and smoke-test each one.
#
# This is the "compile and run" proof for the whole repository: it builds every
# app into bin/ and then exercises each binary end to end. It prints ALL GREEN
# only if every build and every check passed. Run it live at the meetup and
# before every commit.
#
# Usage:
#   sh scripts/build_all.sh          # fast build + smoke tests (the demo path)
#   sh scripts/build_all.sh --full   # also run tests/run_app_tests.sh, the
#                                     # thorough dual-runtime behavior suite
#                                     # (TEST_ALL=1 has the same effect)
# Assumes spinel, curl, and shasum are on PATH. Installs nothing.

set -e

# Run from the repo root regardless of where the script is invoked from.
cd "$(dirname "$0")/.."

PIDS=""
# Always kill any background servers we started, even if a check fails midway.
trap 'kill $PIDS 2>/dev/null || true' EXIT

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; exit 1; }

# Opt-in thorough suite: --full (or TEST_ALL=1) runs the full per-app tests
# after the smoke checks. The default run stays fast for the live demo.
RUN_FULL="${TEST_ALL:-0}"
[ "$1" = "--full" ] && RUN_FULL=1

mkdir -p bin

# --- build ----------------------------------------------------------------
# simple_server_6 links only the sp_net FFI via socket_shim, so it needs no
# require gate. The other four use require-gated packages (json/optparse/
# strscan/set/digest), so they compile with SPINEL_REQUIRE_GATE=1.

echo "== building fyel_srvr =="
spinel source/simple_server_6.rb -o bin/fyel_srvr

echo "== building todo_cli =="
SPINEL_REQUIRE_GATE=1 spinel source/todo_cli.rb -o bin/todo_cli

echo "== building log_report =="
SPINEL_REQUIRE_GATE=1 spinel source/log_report.rb -o bin/log_report

echo "== building token_api =="
SPINEL_REQUIRE_GATE=1 spinel source/token_api.rb -o bin/token_api

echo "== building parallel_digest =="
SPINEL_REQUIRE_GATE=1 spinel source/parallel_digest.rb -o bin/parallel_digest

# --- smoke tests ----------------------------------------------------------

echo "== smoke: fyel_srvr =="
./bin/fyel_srvr -p 8231 >/dev/null 2>&1 &
PIDS="$PIDS $!"
sleep 1
code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8231/)
[ "$code" = "200" ] && pass "fyel_srvr GET / -> 200" || fail "fyel_srvr GET / -> $code"
code=$(curl -s -o /dev/null -w '%{http_code}' --path-as-is http://localhost:8231/../../etc/passwd)
[ "$code" = "404" ] && pass "fyel_srvr path traversal -> 404" || fail "fyel_srvr traversal -> $code"

echo "== smoke: todo_cli =="
TODO_DIR=$(mktemp -d)
BIN_TODO="$(pwd)/bin/todo_cli"
( cd "$TODO_DIR" && "$BIN_TODO" add "meetup demo" >/dev/null && "$BIN_TODO" done 1 >/dev/null && "$BIN_TODO" list >list.txt )
grep -q '\[x\]' "$TODO_DIR/list.txt" && pass "todo_cli add/done/list shows [x]" || fail "todo_cli list missing [x]"
rm -rf "$TODO_DIR"

echo "== smoke: log_report =="
./bin/log_report data/sample_access.log >/tmp/ba_log.txt 2>&1
grep -q 'Total requests' /tmp/ba_log.txt && pass "log_report prints totals" || fail "log_report missing totals"

echo "== smoke: token_api =="
./bin/token_api -p 8232 >/dev/null 2>&1 &
PIDS="$PIDS $!"
sleep 1
# Extract the token from {"token":"..."} without any Ruby dependency.
TOKEN=$(curl -s -X POST http://localhost:8232/login -d '{"user":"matz"}' \
  | sed 's/.*"token":"//; s/".*//')
[ -n "$TOKEN" ] && pass "token_api login returned a token" || fail "token_api login gave no token"
code=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8232/notes)
[ "$code" = "401" ] && pass "token_api GET /notes no auth -> 401" || fail "token_api no-auth -> $code"
code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" http://localhost:8232/notes)
[ "$code" = "200" ] && pass "token_api GET /notes with auth -> 200" || fail "token_api auth -> $code"

echo "== smoke: parallel_digest =="
./bin/parallel_digest source -w 4 >/tmp/ba_pd.txt 2>&1
APP_HASH=$(grep 'source/todo_cli.rb' /tmp/ba_pd.txt | awk '{print $1}')
REAL_HASH=$(shasum -a 256 source/todo_cli.rb | cut -c1-12)
[ "$APP_HASH" = "$REAL_HASH" ] && pass "parallel_digest hash matches shasum ($APP_HASH)" \
  || fail "parallel_digest $APP_HASH != shasum $REAL_HASH"

# --- thorough suite (opt-in) ----------------------------------------------
# With --full, hand off to the full per-app behavior suite. It boots its own
# servers on separate ports, so first stop the smoke-test servers to avoid any
# port contention, then run the runner (it self-fails with a non-zero exit).
if [ "$RUN_FULL" = "1" ]; then
  kill $PIDS 2>/dev/null || true
  PIDS=""
  echo ""
  echo "== full app test suite (tests/run_app_tests.sh) =="
  sh tests/run_app_tests.sh || fail "app test suite"
fi

echo ""
echo "ALL GREEN"
