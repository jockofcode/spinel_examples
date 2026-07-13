# token_api_test.sh -- black-box tests for the token_api example.
#
# Boots the server, then exercises the auth flow end to end with curl:
# /login issues an HMAC-signed bearer token, /notes requires it (401 without,
# 200 with), a tampered token is rejected, POST /notes creates (201), and an
# unknown route is 404. The whole suite runs against BOTH the compiled Spinel
# binary and the CRuby source (dual-runtime parity), each on its own port.
#
# Usage: sh tests/token_api_test.sh
# Requires curl. Exit 0 and "token_api: ALL GREEN" only if every check passed.

cd "$(dirname "$0")/.."

BIN="./bin/token_api"
SRC="source/token_api.rb"
FAILED=0
SRV_PID=""

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"; echo "        expected: [$2]"; echo "        actual:   [$3]"; fi
}

# Always stop any server we started, even if a check aborts the script.
cleanup() { [ -n "$SRV_PID" ] && kill "$SRV_PID" 2>/dev/null; }
trap cleanup EXIT

if [ ! -x "$BIN" ]; then
  echo "== building token_api (bin missing) =="
  mkdir -p bin
  SPINEL_REQUIRE_GATE=1 spinel "$SRC" -o "$BIN" || { echo "FAIL - build"; exit 1; }
fi

# code URL [curl-args...] -- HTTP status code only.
code() { U="$1"; shift; curl -s -o /dev/null -w '%{http_code}' "$@" "$U"; }

run_suite() {
  RT="$1"; PORT="$2"
  BASE="http://localhost:$PORT"

  # Start the server for this runtime and give it a moment to bind.
  if [ "$RT" = "bin" ]; then "$BIN" -p "$PORT" >/dev/null 2>&1 &
  else ruby "$SRC" -p "$PORT" >/dev/null 2>&1 & fi
  SRV_PID=$!
  sleep 1

  # /login returns a token of the form user.signature
  TOK=$(curl -s -X POST "$BASE/login" -d '{"user":"matz"}' \
        | sed 's/.*"token":"//; s/".*//')
  [ -n "$TOK" ] && pass "$RT login returns a token" \
                || fail "$RT login returned no token"
  case "$TOK" in
    matz.*) pass "$RT token shape user.signature" ;;
    *) fail "$RT token shape user.signature (got [$TOK])" ;;
  esac

  # /login without a user -> 400
  assert_eq "$RT login no-user -> 400" "400" \
    "$(code "$BASE/login" -X POST -d '{}')"

  # GET /notes with no auth -> 401
  assert_eq "$RT GET /notes no-auth -> 401" "401" "$(code "$BASE/notes")"

  # GET /notes with a tampered token -> 401
  assert_eq "$RT GET /notes tampered -> 401" "401" \
    "$(code "$BASE/notes" -H "Authorization: Bearer ${TOK}x")"

  # GET /notes with a valid token -> 200, and the seeded notes come back
  assert_eq "$RT GET /notes auth -> 200" "200" \
    "$(code "$BASE/notes" -H "Authorization: Bearer $TOK")"
  BODY=$(curl -s "$BASE/notes" -H "Authorization: Bearer $TOK")
  echo "$BODY" | grep -q 'programmer happiness' \
    && pass "$RT seeded note present" || fail "$RT seeded note missing"

  # POST /notes creates a note -> 201, and the count grows to 3
  assert_eq "$RT POST /notes -> 201" "201" \
    "$(code "$BASE/notes" -H "Authorization: Bearer $TOK" \
        -X POST -d '{"text":"from the test suite"}')"
  COUNT=$(curl -s "$BASE/notes" -H "Authorization: Bearer $TOK" \
          | grep -o '"id"' | wc -l | tr -d ' ')
  assert_eq "$RT note count after POST = 3" "3" "$COUNT"

  # POST /notes without auth -> 401
  assert_eq "$RT POST /notes no-auth -> 401" "401" \
    "$(code "$BASE/notes" -X POST -d '{"text":"x"}')"

  # Unknown route -> 404
  assert_eq "$RT unknown route -> 404" "404" "$(code "$BASE/nope")"

  kill "$SRV_PID" 2>/dev/null; wait "$SRV_PID" 2>/dev/null; SRV_PID=""
}

echo "== token_api: native binary =="
run_suite bin 8241
echo "== token_api: CRuby source =="
run_suite cruby 8242

echo ""
if [ "$FAILED" = "0" ]; then echo "token_api: ALL GREEN"; exit 0; fi
echo "token_api: FAILURES ABOVE"; exit 1
