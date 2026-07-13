# parallel_digest_test.sh -- black-box tests for the parallel_digest example.
#
# Hashes a small fixture tree and checks that: the printed digest matches an
# independent `shasum` for a known file, output is sorted/deterministic across
# worker counts, the summary line reports the worker count, a bad directory
# exits 1, and SPINEL_WORKERS=1 (forced cooperative mode) yields identical
# output. Runs against BOTH the compiled binary and the CRuby source, and
# asserts the two runtimes agree (dual-runtime parity under real parallelism).
#
# Usage: sh tests/parallel_digest_test.sh
# Requires shasum. Exit 0 and "parallel_digest: ALL GREEN" only if all passed.

cd "$(dirname "$0")/.."

BIN="./bin/parallel_digest"
SRC="source/parallel_digest.rb"
FAILED=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"; echo "        expected: [$2]"; echo "        actual:   [$3]"; fi
}

if [ ! -x "$BIN" ]; then
  echo "== building parallel_digest (bin missing) =="
  mkdir -p bin
  SPINEL_REQUIRE_GATE=1 spinel "$SRC" -o "$BIN" || { echo "FAIL - build"; exit 1; }
fi

app_cmd() { if [ "$1" = "bin" ]; then echo "$BIN"; else echo "ruby $SRC"; fi; }

# Build a deterministic fixture tree with known contents.
FIX="$(mktemp -d)"
mkdir -p "$FIX/sub"
printf 'alpha\n' > "$FIX/a.txt"
printf 'beta\n'  > "$FIX/sub/b.txt"
printf 'gamma\n' > "$FIX/sub/c.txt"

run_suite() {
  RT="$1"; APP="$(app_cmd "$RT")"

  # 4 workers over the fixture.
  OUT=$($APP "$FIX" -w 4); RC=$?
  assert_eq "$RT exit 0" "0" "$RC"

  # The digest column for a.txt must match an independent shasum (first 12 hex).
  APP_HASH=$(echo "$OUT" | grep 'a.txt' | awk '{print $1}')
  REAL_HASH=$(shasum -a 256 "$FIX/a.txt" | cut -c1-12)
  assert_eq "$RT a.txt digest matches shasum" "$REAL_HASH" "$APP_HASH"

  # Summary line reports 3 files and the worker count.
  SUMMARY=$(echo "$OUT" | tail -1)
  assert_eq "$RT summary line" "hashed 3 files with 4 workers" "$SUMMARY"

  # Output (excluding summary) is sorted by path -> deterministic. Each line is
  # "digest  path", so we compare the path COLUMN against its own sort (the
  # digests are unordered, so sorting whole lines would not prove path order).
  BODY=$(echo "$OUT" | grep -v '^hashed ')
  PATHS=$(echo "$BODY" | awk '{print $2}')
  SORTED=$(echo "$PATHS" | LC_ALL=C sort)
  assert_eq "$RT output sorted by path" "$SORTED" "$PATHS"

  # Worker count must not change the hashes: -w 1 and -w 4 agree on the body.
  B1=$($APP "$FIX" -w 1 | grep -v '^hashed ')
  assert_eq "$RT -w1 body == -w4 body" "$BODY" "$B1"

  # Bad directory -> stderr + exit 1.
  MSG=$($APP /no/such/dir 2>&1 >/dev/null); RC=$?
  assert_eq "$RT bad-dir stderr" "error: not a directory: /no/such/dir" "$MSG"
  assert_eq "$RT bad-dir exit 1" "1" "$RC"
}

echo "== parallel_digest: native binary =="
run_suite bin
echo "== parallel_digest: CRuby source =="
run_suite cruby

# SPINEL_WORKERS=1 forces the deterministic cooperative scheduler; the digests
# must be identical to the default parallel run (only scheduling changes).
echo "== parallel_digest: SPINEL_WORKERS parity =="
DEF=$("$BIN" "$FIX" -w 4 | grep -v '^hashed ')
COOP=$(SPINEL_WORKERS=1 "$BIN" "$FIX" -w 4 | grep -v '^hashed ')
assert_eq "SPINEL_WORKERS=1 body == default body" "$DEF" "$COOP"

# Dual-runtime parity: binary and CRuby produce the same digests.
echo "== parallel_digest: bin vs CRuby parity =="
BINB=$("$BIN" "$FIX" -w 4 | grep -v '^hashed ')
CRB=$(ruby "$SRC" "$FIX" -w 4 | grep -v '^hashed ')
assert_eq "bin body == CRuby body" "$BINB" "$CRB"

rm -rf "$FIX"

echo ""
if [ "$FAILED" = "0" ]; then echo "parallel_digest: ALL GREEN"; exit 0; fi
echo "parallel_digest: FAILURES ABOVE"; exit 1
