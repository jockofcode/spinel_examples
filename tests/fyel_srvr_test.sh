# fyel_srvr_test.sh -- black-box tests for the FyelSrvr static file server.
#
# Boots the server from the repo root and exercises it with curl: the root
# index.html is served (200), a real file downloads, a missing path is 404,
# a path-traversal attempt is safely 404, and --no-index forces a directory
# listing instead of index.html. Runs against BOTH the compiled Spinel binary
# (bin/fyel_srvr) and the CRuby source (via socket_shim), each on its own port,
# proving dual-runtime parity.
#
# Usage: sh tests/fyel_srvr_test.sh
# Requires curl. Exit 0 and "fyel_srvr: ALL GREEN" only if every check passed.

cd "$(dirname "$0")/.."

BIN="./bin/fyel_srvr"
SRC="source/fyel_srvr_6.rb"
FAILED=0
SRV_PID=""

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"; echo "        expected: [$2]"; echo "        actual:   [$3]"; fi
}

cleanup() { [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null; }
trap cleanup EXIT

if [ ! -x "$BIN" ]; then
  echo "== building fyel_srvr (bin missing) =="
  mkdir -p bin
  spinel "$SRC" -o "$BIN" || { echo "FAIL - build"; exit 1; }
fi

# code URL [curl-args...] -- HTTP status code only (path kept as-is for the
# traversal check so curl does not normalize ../ away before sending).
code() { U="$1"; shift; curl -s -o /dev/null -w '%{http_code}' "$@" "$U"; }

run_suite() {
  RT="$1"; PORT="$2"
  BASE="http://localhost:$PORT"

  # Start the server for this runtime from the repo root and let it bind.
  if [ "$RT" = "bin" ]; then "$BIN" -p "$PORT" >/dev/null 2>&1 &
  else ruby "$SRC" -p "$PORT" >/dev/null 2>&1 & fi
  SRV_PID=$!
  sleep 1

  # GET / -> 200 and serves the root index.html (inline HTML).
  assert_eq "$RT GET / -> 200" "200" "$(code "$BASE/")"
  CT=$(curl -s -D - -o /dev/null "$BASE/" | tr -d '\r' \
       | awk 'tolower($1)=="content-type:"{print $2}')
  assert_eq "$RT / content-type text/html" "text/html" "$CT"

  # A real tracked file under public/ is served.
  assert_eq "$RT GET public/*.txt -> 200" "200" \
    "$(code "$BASE/public/why_the_world_loves_matz.txt")"
  BODY=$(curl -s "$BASE/public/why_the_world_loves_matz.txt")
  [ -n "$BODY" ] && pass "$RT text file has a body" \
                 || fail "$RT text file body empty"

  # Missing path -> 404 with the server's not-found page.
  assert_eq "$RT missing path -> 404" "404" "$(code "$BASE/nope/missing.html")"

  # Path traversal is defused: --path-as-is keeps ../ in the request so we test
  # the SERVER's sanitizer, not curl's. It must not escape the root -> 404.
  assert_eq "$RT traversal -> 404" "404" \
    "$(code "$BASE/../../../../etc/passwd" --path-as-is)"
  # And the response must not contain a real /etc/passwd line.
  LEAK=$(curl -s --path-as-is "$BASE/../../../../etc/passwd" | grep -c 'root:')
  assert_eq "$RT traversal leaks nothing" "0" "$LEAK"

  kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; SRV_PID=""

  # --no-index: the root now renders a directory listing instead of index.html.
  if [ "$RT" = "bin" ]; then "$BIN" -p "$PORT" --no-index >/dev/null 2>&1 &
  else ruby "$SRC" -p "$PORT" --no-index >/dev/null 2>&1 & fi
  SRV_PID=$!
  sleep 1
  LISTING=$(curl -s "$BASE/")
  echo "$LISTING" | grep -q 'Index of /' \
    && pass "$RT --no-index shows directory listing" \
    || fail "$RT --no-index did not show a listing"
  kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; SRV_PID=""
}

echo "== fyel_srvr: native binary =="
run_suite bin 8271
echo "== fyel_srvr: CRuby source (via socket_shim) =="
run_suite cruby 8272

echo ""
if [ "$FAILED" = "0" ]; then echo "fyel_srvr: ALL GREEN"; exit 0; fi
echo "fyel_srvr: FAILURES ABOVE"; exit 1
