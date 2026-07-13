# todo_cli_test.sh -- black-box tests for the todo_cli example.
#
# Exercises every subcommand (add/list/done/remove/clear), the -f/--file and
# -h flags, and the error/exit-code paths, asserting exact output. Each check
# runs against BOTH runtimes: the compiled Spinel binary (bin/todo_cli) and
# the CRuby source (ruby source/todo_cli.rb), proving dual-runtime parity.
#
# Usage: sh tests/todo_cli_test.sh
# Exit 0 and "todo_cli: ALL GREEN" only if every check passed.

# Run from the repo root regardless of where this is invoked from.
cd "$(dirname "$0")/.."

BIN="./bin/todo_cli"
SRC="source/todo_cli.rb"
FAILED=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; FAILED=1; }

# assert_eq LABEL EXPECTED ACTUAL
assert_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else
    fail "$1"; echo "        expected: [$2]"; echo "        actual:   [$3]"; fi
}

# Build the binary if it is missing so the test is self-contained.
if [ ! -x "$BIN" ]; then
  echo "== building todo_cli (bin missing) =="
  mkdir -p bin
  SPINEL_REQUIRE_GATE=1 spinel "$SRC" -o "$BIN" || { echo "FAIL - build"; exit 1; }
fi

# run_app RUNTIME -- prints the command prefix for the given runtime.
# "bin"   -> the native binary; "cruby" -> ruby on the source file.
app_cmd() { if [ "$1" = "bin" ]; then echo "$BIN"; else echo "ruby $SRC"; fi; }

# Full functional sweep, parameterized by runtime so we test bin/ and CRuby
# with the identical assertions.
run_suite() {
  RT="$1"
  APP="$(app_cmd "$RT")"
  WORK="$(mktemp -d)"
  DF="$WORK/todo.json"

  # add: prints "Added #1: TITLE", exit 0
  OUT=$($APP -f "$DF" add "write slides"); RC=$?
  assert_eq "$RT add prints Added #1"        "Added #1: write slides" "$OUT"
  assert_eq "$RT add exit 0"                 "0" "$RC"

  # add a second, then list shows both open with aligned ids
  $APP -f "$DF" add "book venue" >/dev/null
  OUT=$($APP -f "$DF" list)
  EXP="$(printf '  1 [ ] write slides\n  2 [ ] book venue')"
  assert_eq "$RT list shows two open tasks"  "$EXP" "$OUT"

  # done 1: marks complete, list shows [x]
  OUT=$($APP -f "$DF" done 1)
  assert_eq "$RT done prints Completed"      "Completed #1: write slides" "$OUT"
  OUT=$($APP -f "$DF" list | head -1)
  assert_eq "$RT list shows [x] after done"  "  1 [x] write slides" "$OUT"

  # remove 2: deletes, then only task 1 remains
  OUT=$($APP -f "$DF" remove 2)
  assert_eq "$RT remove prints Removed"      "Removed #2: book venue" "$OUT"

  # clear: drops the completed task 1
  OUT=$($APP -f "$DF" clear)
  assert_eq "$RT clear prints count"         "Cleared 1 completed task(s)" "$OUT"

  # list on an empty file: friendly hint
  OUT=$($APP -f "$DF" list)
  assert_eq "$RT empty-list hint" \
    'No tasks yet. Add one with: todo_cli add "..."' "$OUT"

  # --file (long form) works the same as -f. The file is empty at this point
  # (cleared above), so the new task gets id 1 -- this proves --file targets
  # the same path -f does.
  $APP --file "$DF" add "long flag" >/dev/null
  OUT=$($APP --file "$DF" list)
  assert_eq "$RT --file long flag"           "  1 [ ] long flag" "$OUT"

  # -h prints usage and exits 0
  OUT=$($APP -h | head -1); RC=$?
  assert_eq "$RT -h first line" "Usage: todo_cli [options] COMMAND [args]" "$OUT"
  $APP -h >/dev/null; assert_eq "$RT -h exit 0" "0" "$?"

  # error: add with no title -> stderr + exit 1
  OUT=$($APP -f "$DF" add 2>&1 >/dev/null); RC=$?
  assert_eq "$RT add-no-title stderr"        'usage: todo_cli add "TITLE"' "$OUT"
  assert_eq "$RT add-no-title exit 1"        "1" "$RC"

  # error: unknown id -> stderr + exit 1
  OUT=$($APP -f "$DF" done 99 2>&1 >/dev/null); RC=$?
  assert_eq "$RT unknown-id stderr"          "error: no task with id 99" "$OUT"
  assert_eq "$RT unknown-id exit 1"          "1" "$RC"

  # error: unknown command -> exit 1
  $APP -f "$DF" frobnicate >/dev/null 2>&1
  assert_eq "$RT unknown-command exit 1"     "1" "$?"

  # persisted file is valid JSON (parse with CRuby, always available here)
  $APP -f "$DF" add "persist" >/dev/null
  ruby -rjson -e "JSON.parse(File.read(ARGV[0]))" "$DF" 2>/dev/null
  assert_eq "$RT writes valid JSON"          "0" "$?"

  rm -rf "$WORK"
}

echo "== todo_cli: native binary =="
run_suite bin
echo "== todo_cli: CRuby source =="
run_suite cruby

echo ""
if [ "$FAILED" = "0" ]; then echo "todo_cli: ALL GREEN"; exit 0; fi
echo "todo_cli: FAILURES ABOVE"; exit 1
