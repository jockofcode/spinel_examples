# log_report_test.sh -- black-box tests for the log_report example.
#
# Runs the analyzer over the tracked sample log and asserts the aggregate
# figures and section headings, plus the missing-file error path. Every check
# runs against BOTH the compiled Spinel binary (bin/log_report) and the CRuby
# source, and a final check asserts the two runtimes produce byte-identical
# reports (dual-runtime parity).
#
# Usage: sh tests/log_report_test.sh
# Exit 0 and "log_report: ALL GREEN" only if every check passed.

cd "$(dirname "$0")/.."

BIN="./bin/log_report"
SRC="source/log_report.rb"
LOG="data/sample_access.log"
FAILED=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }

assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"; echo "        expected: [$2]"; echo "        actual:   [$3]"; fi
}

# Pull the number off a "Label : N" report line, given the label prefix.
field() { grep "$2" "$1" | sed 's/[^0-9]*//' | tr -d ' '; }

if [ ! -x "$BIN" ]; then
  echo "== building log_report (bin missing) =="
  mkdir -p bin
  SPINEL_REQUIRE_GATE=1 spinel "$SRC" -o "$BIN" || { echo "FAIL - build"; exit 1; }
fi

app_cmd() { if [ "$1" = "bin" ]; then echo "$BIN"; else echo "ruby $SRC"; fi; }

run_suite() {
  RT="$1"; APP="$(app_cmd "$RT")"
  REP="$(mktemp)"
  $APP "$LOG" >"$REP" 2>&1
  assert_eq "$RT exit 0 on good log"       "0" "$?"

  # Known-good aggregates for the tracked sample log (28 valid, 2 malformed,
  # 5 unique IPs). These are asserted exactly so a regression in parsing or a
  # change to the sample file is caught immediately.
  assert_eq "$RT total requests = 28"      "28" "$(field "$REP" 'Total requests')"
  assert_eq "$RT malformed lines = 2"      "2"  "$(field "$REP" 'Malformed lines')"
  assert_eq "$RT unique IPs = 5"           "5"  "$(field "$REP" 'Unique IPs')"

  # Section headings are present and spelled exactly.
  grep -q '^Requests by status code:$' "$REP" \
    && pass "$RT has status section" || fail "$RT missing status section"
  grep -q '^Top 5 paths by hits:$' "$REP" \
    && pass "$RT has top-paths section" || fail "$RT missing top-paths section"

  # Bytes served is a positive integer (sum of the size fields).
  BYTES="$(field "$REP" 'Bytes served')"
  case "$BYTES" in
    ''|*[!0-9]*) fail "$RT bytes served numeric" ;;
    *) [ "$BYTES" -gt 0 ] && pass "$RT bytes served > 0 ($BYTES)" \
         || fail "$RT bytes served > 0" ;;
  esac

  # Missing file -> stderr message + exit 1.
  OUT=$($APP /no/such/file.log 2>&1 >/dev/null); RC=$?
  assert_eq "$RT missing-file stderr" "error: no such file: /no/such/file.log" "$OUT"
  assert_eq "$RT missing-file exit 1" "1" "$RC"

  rm -f "$REP"
}

echo "== log_report: native binary =="
run_suite bin
echo "== log_report: CRuby source =="
run_suite cruby

# Dual-runtime parity: the binary and CRuby must emit identical reports.
echo "== log_report: bin vs CRuby parity =="
"$BIN" "$LOG" >/tmp/lr_bin.txt 2>&1
ruby "$SRC" "$LOG" >/tmp/lr_cruby.txt 2>&1
if diff -q /tmp/lr_bin.txt /tmp/lr_cruby.txt >/dev/null; then
  pass "bin and CRuby reports identical"
else
  fail "bin and CRuby reports differ"; diff /tmp/lr_bin.txt /tmp/lr_cruby.txt
fi
rm -f /tmp/lr_bin.txt /tmp/lr_cruby.txt

echo ""
if [ "$FAILED" = "0" ]; then echo "log_report: ALL GREEN"; exit 0; fi
echo "log_report: FAILURES ABOVE"; exit 1
