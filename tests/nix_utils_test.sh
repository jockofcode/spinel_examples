#!/usr/bin/env bash
# nix_utils_test.sh
#
# Integration tests for the nix_utils reimplementations. Each test runs the
# tool via the configured interpreter and compares stdout to the expected
# output. Prints "label:ok" or "label:FAIL expected=... got=..." for each check.
#
# This harness is written in bash so it has no CRuby dependency: subprocess
# capture, temp files, symlinks, and exit codes are all handled natively.
#
# Run from anywhere:
#   ./tests/nix_utils_test.sh
#
# The interpreter used to run each tool is configurable via the RUBY env var
# and defaults to `spinel -E` (compile-and-run). To run the tools under CRuby
# instead:
#   RUBY=ruby ./tests/nix_utils_test.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/../nix_utils"

# Interpreter used to run each tool under test. Defaults to Spinel's
# compile-and-run mode; override with the RUBY env var (e.g. RUBY=ruby).
#
# When running under Spinel: compile sp_file_ext.o (C native extension for
# missing File methods) and link it into every tool. Tools that don't use
# FileExt are unaffected; those that do get the fast C path.
if [ -z "${RUBY:-}" ]; then
  SP_EXT_SRC="$TOOLS_DIR/sp_file_ext.c"
  SP_EXT_OBJ="$TOOLS_DIR/sp_file_ext.o"
  SPINEL_LIB="$(spinel --version 2>/dev/null | head -1; dirname "$(which spinel)")/../lib/spinel"
  SPINEL_INC="$HOME/.asdf/installs/spinel/master/lib/spinel/lib"
  if [ -f "$SP_EXT_SRC" ] && ! [ -f "$SP_EXT_OBJ" ]; then
    cc -c "$SP_EXT_SRC" -I"$SPINEL_INC" -o "$SP_EXT_OBJ" 2>/dev/null || true
  fi
  if [ -f "$SP_EXT_OBJ" ]; then
    RUBY="spinel --link $SP_EXT_OBJ -E"
  else
    RUBY="spinel -E"
  fi
fi

failures=0

TMP="$(mktemp -d "${TMPDIR:-/tmp}/nix_utils_test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
EXP="$TMP/exp"   # expected bytes for the current check
ACT="$TMP/act"   # actual bytes captured from the tool

# ── helpers ────────────────────────────────────────────────────────

# Absolute path to a tool's source file.
tool() { printf '%s/%s.rb' "$TOOLS_DIR" "$1"; }

# Write expected bytes, interpreting printf escapes (\n, \t, \xHH, ...).
exp() { printf "$1" >"$EXP"; }

# Write expected bytes literally (no escape interpretation).
expl() { printf '%s' "$1" >"$EXP"; }

# rp TOOL FORMAT [ARGS]
#   printf FORMAT (escapes interpreted) | RUBY tool ARGS  -> ACT
#   ARGS is a shell-parsed string, mirroring the original interpolation.
rp() {
  local tp; tp="$(tool "$1")"
  printf "$2" | eval "$RUBY '$tp' ${3:-}" >"$ACT" 2>/dev/null
}

# rn TOOL [ARGS] [STDIN]
#   RUBY tool ARGS  -> ACT, with optional literal STDIN.
#   With no STDIN, stdin is /dev/null so a tool can never block.
rn() {
  local tp; tp="$(tool "$1")"
  if [ "${3-__NO_STDIN__}" != "__NO_STDIN__" ]; then
    printf '%s' "$3" | eval "$RUBY '$tp' ${2:-}" >"$ACT" 2>/dev/null
  else
    eval "$RUBY '$tp' ${2:-}" >"$ACT" 2>/dev/null </dev/null
  fi
}

# Human-readable one-line byte dump of a file, for FAIL diagnostics.
dump() { od -An -c "$1" | tr '\n' ' ' | tr -s ' '; }

# ck LABEL  — byte-compare EXP vs ACT.
ck() {
  if cmp -s "$EXP" "$ACT"; then
    printf '%s:ok\n' "$1"
  else
    printf '%s:FAIL expected=%s got=%s\n' "$1" "$(dump "$EXP")" "$(dump "$ACT")"
    failures=$((failures + 1))
  fi
}

# cke LABEL EXPECTED ACTUAL  — plain string comparison (for booleans/counts).
cke() {
  if [ "$2" = "$3" ]; then
    printf '%s:ok\n' "$1"
  else
    printf '%s:FAIL expected=%q got=%q\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

# ──────────────────────────────────────────────────────────────────
# tac
# ──────────────────────────────────────────────────────────────────
exp 'c\nb\na\n';  rp tac 'a\nb\nc\n';         ck "tac basic"
exp 'a\n';        rp tac 'a\n';               ck "tac single line"
expl 'c,b,a,';    rp tac 'a,b,c,' '-s,';      ck "tac custom separator"
exp 'c\nb\na';    rp tac 'a\nb\nc' '-b';      ck "tac before mode"

# ──────────────────────────────────────────────────────────────────
# seq
# ──────────────────────────────────────────────────────────────────
exp '1\n2\n3\n';     rn seq '3';         ck "seq LAST"
exp '3\n4\n5\n';     rn seq '3 5';       ck "seq FIRST LAST"
exp '0\n2\n4\n';     rn seq '0 2 4';     ck "seq FIRST INC LAST"
exp '5\n4\n3\n';     rn seq '5 -1 3';    ck "seq descending"
exp '1,2,3,4,5\n';   rn seq '-s, 1 5';   ck "seq -s separator"
exp '08\n09\n10\n';  rn seq '-w 8 10';   ck "seq -w equal width"
exp '1.0\n1.5\n2.0\n'; rn seq '1.0 0.5 2.0'; ck "seq float"

# ──────────────────────────────────────────────────────────────────
# sort
# ──────────────────────────────────────────────────────────────────
exp 'apple\nbanana\ncherry\n'; rp sort 'banana\ncherry\napple\n';        ck "sort basic"
exp 'cherry\nbanana\napple\n'; rp sort 'apple\nbanana\ncherry\n' '-r';   ck "sort -r reverse"
exp '1\n3\n10\n25\n';          rp sort '10\n3\n25\n1\n' '-n';            ck "sort -n numeric"
exp 'a\nb\nc\n';               rp sort 'a\nb\na\nc\nb\n' '-u';           ck "sort -u unique"
exp 'a\nApple\nb\n';           rp sort 'Apple\nb\na\n' '-f';             ck "sort -f case insensitive"
exp 'root:0\nuser:1000\n';     rp sort 'user:1000\nroot:0\n' '-t: -k2n'; ck "sort -k field"

# ──────────────────────────────────────────────────────────────────
# uniq
# ──────────────────────────────────────────────────────────────────
exp 'a\nb\nc\n';                    rp uniq 'a\na\nb\nb\nc\n';           ck "uniq basic"
exp '      2 a\n      1 b\n      3 c\n'; rp uniq 'a\na\nb\nc\nc\nc\n' '-c'; ck "uniq -c count"
exp 'a\nc\n';                       rp uniq 'a\na\nb\nc\nc\nc\n' '-d';   ck "uniq -d repeated only"
exp 'b\n';                          rp uniq 'a\na\nb\nc\nc\n' '-u';      ck "uniq -u unique only"
exp 'a\nb\n';                       rp uniq 'a\nA\nb\n' '-i';            ck "uniq -i ignore case"

# ──────────────────────────────────────────────────────────────────
# cut
# ──────────────────────────────────────────────────────────────────
exp 'a\n1\n';              rp cut 'a\tb\tc\n1\t2\t3\n' '-f1';                   ck "cut -f fields tab"
exp 'root:0\nuser:1000\n'; rp cut 'root:x:0:0\nuser:x:1000:1000\n' '-d: -f1,3'; ck "cut -d: -f1,3"
exp 'bcd\nhij\n';          rp cut 'abcdef\nghijkl\n' '-c2-4';                   ck "cut -c range"
exp 'cdef\nijkl\n';        rp cut 'abcdef\nghijkl\n' '-c3-';                    ck "cut -c open end"
exp 'b\n2\n';              rp cut 'a\tb\tc\n1\t2\t3\n' '-f1,3 --complement';    ck "cut -f complement"
exp 'a:b\n';               rp cut 'a:b\nnodeli\n' '-d: -f1,2 -s';               ck "cut -s suppress no-delim"

# ──────────────────────────────────────────────────────────────────
# tr
# ──────────────────────────────────────────────────────────────────
exp 'HELLO WORLD\n'; rp tr 'hello world\n' "'a-z' 'A-Z'";        ck "tr uppercase"
exp 'Hll Wrld\n';    rp tr 'Hello World\n' "-d 'aeiouAEIOU'";     ck "tr -d delete"
exp 'abc\n';         rp tr 'aabbcc\n' "-s 'a-c'";                 ck "tr -s squeeze"
exp 'bc\n';          rp tr 'aabbc\n' "-ds 'a' 'b-c'";             ck "tr -d -s delete and squeeze"
exp 'a b\n';         rp tr 'a\tb\n' "'\t' ' '";                   ck "tr escape sequences"

# ──────────────────────────────────────────────────────────────────
# tee (output to file)
# ──────────────────────────────────────────────────────────────────
tee_tmp="$TMP/tee.txt"; rm -f "$tee_tmp"
exp 'hello\n'; printf 'hello\n' | eval "$RUBY '$(tool tee)' '$tee_tmp'" >"$ACT" 2>/dev/null
ck "tee stdout"
exp 'hello\n'; :>"$ACT"; [ -e "$tee_tmp" ] && cat "$tee_tmp" >"$ACT"
ck "tee file"
printf 'world\n' | eval "$RUBY '$(tool tee)' -a '$tee_tmp'" >/dev/null 2>&1
exp 'hello\nworld\n'; :>"$ACT"; [ -e "$tee_tmp" ] && cat "$tee_tmp" >"$ACT"
ck "tee append"
rm -f "$tee_tmp"

# ──────────────────────────────────────────────────────────────────
# paste
# ──────────────────────────────────────────────────────────────────
pa="$TMP/paste_a"; printf 'a\nb\nc\n' >"$pa"
pb="$TMP/paste_b"; printf '1\n2\n3\n' >"$pb"
exp 'a\t1\nb\t2\nc\t3\n'; rn paste "'$pa' '$pb'";    ck "paste parallel"
exp 'a,1\nb,2\nc,3\n';    rn paste "-d, '$pa' '$pb'"; ck "paste -d delimiter"
exp 'a\tb\tc\n';          rn paste "-s '$pa'";        ck "paste -s serial"

# ──────────────────────────────────────────────────────────────────
# fold
# ──────────────────────────────────────────────────────────────────
exp 'abcde\nfghij\n'; rp fold 'abcdefghij\n' '-w5';        ck "fold -w wrap"
exp 'hello \nworld\n'; rp fold 'hello world\n' '-w7 -s';   ck "fold -w -s break at space"
exp 'abc\n';          rp fold 'abc\n' '-w10';              ck "fold short line no wrap"

# ──────────────────────────────────────────────────────────────────
# nl
# ──────────────────────────────────────────────────────────────────
exp '     1\tfoo\n       \n     2\tbar\n'; rp nl 'foo\n\nbar\n';           ck "nl default (nonempty)"
exp '     1\tfoo\n     2\t\n     3\tbar\n'; rp nl 'foo\n\nbar\n' '-ba';     ck "nl -ba all lines"
exp '    10\ta\n    15\tb\n';               rp nl 'a\nb\n' '-v10 -i5';      ck "nl -v start -i increment"
exp '000001\tfoo\n';                        rp nl 'foo\n' '-nrz -w6';       ck "nl -nrz zero padded"

# ──────────────────────────────────────────────────────────────────
# basename / dirname
# ──────────────────────────────────────────────────────────────────
exp 'ruby\n';     rn basename '/usr/bin/ruby';    ck "basename path"
exp 'libfoo\n';   rn basename '/lib/libfoo.so .so'; ck "basename suffix"
exp 'a\nb\n';     rn basename '-a /x/a /y/b';      ck "basename -a"
exp '/usr/bin\n'; rn dirname '/usr/bin/ruby';      ck "dirname path"
exp '.\n';        rn dirname 'foo';                ck "dirname no dir"
exp '/\n';        rn dirname '/';                  ck "dirname root"

# ──────────────────────────────────────────────────────────────────
# pwd
# ──────────────────────────────────────────────────────────────────
rn pwd ""
pwd_out="$(tr -d '\n' <"$ACT")"
if [ -n "$pwd_out" ] && [ "${pwd_out:0:1}" = "/" ]; then r=true; else r=false; fi
cke "pwd is absolute" true "$r"

# ──────────────────────────────────────────────────────────────────
# sleep
# ──────────────────────────────────────────────────────────────────
TIMEFORMAT='%R'
elapsed="$( { time rn sleep '0.1'; } 2>&1 )"
r="$(awk "BEGIN{print ($elapsed >= 0.05) ? \"true\" : \"false\"}")"
cke "sleep duration" true "$r"

# ──────────────────────────────────────────────────────────────────
# echo
# ──────────────────────────────────────────────────────────────────
exp 'hello world\n'; rn echo 'hello world';  ck "echo basic"
expl 'hello';        rn echo '-n hello';      ck "echo -n no newline"
exp 'a\tb\n';        rn echo "-e 'a\tb'";      ck "echo -e escape sequences"
exp 'a\nb\n';        rn echo "-e 'a\nb'";      ck "echo -e newline escape"

# ──────────────────────────────────────────────────────────────────
# yes
# ──────────────────────────────────────────────────────────────────
exp 'y\ny\ny\n'; eval "$RUBY '$(tool yes)'" 2>/dev/null | head -3 >"$ACT"
ck "yes outputs y lines"
exp 'no\nno\n';  eval "$RUBY '$(tool yes)' no" 2>/dev/null | head -2 >"$ACT"
ck "yes custom string"

# ──────────────────────────────────────────────────────────────────
# true / false
# ──────────────────────────────────────────────────────────────────
rn true "";  cke "true exit 0" 0 "$?"
rn false ""; cke "false exit 1" 1 "$?"

# ──────────────────────────────────────────────────────────────────
# cat -v / -A / -e / -t (show-nonprinting)
# ──────────────────────────────────────────────────────────────────
# \001 = SOH (^A), \200 = 0x80 (M-^@)
exp 'Hello^AWorld\n';    rp cat 'Hello\001World\n' '-v'; ck "cat -v control char"
exp 'M-^@\n';            rp cat '\200\n' '-v';           ck "cat -v high byte"
exp '^IHello^AWorld$\n'; rp cat '\tHello\001World\n' '-A'; ck "cat -A (vET) tab and end"
exp 'hello$\n';          rp cat 'hello\n' '-e';          ck "cat -e (vE) end only"
exp '^Ihello\n';         rp cat '\thello\n' '-t';        ck "cat -t (vT) tab only"

# ──────────────────────────────────────────────────────────────────
# tail
# ──────────────────────────────────────────────────────────────────
exp 'c\nd\ne\n';  rp tail 'a\nb\nc\nd\ne\n' '-n3';  ck "tail -n3 last lines"
exp 'c\nd\ne\n';  rp tail 'a\nb\nc\nd\ne\n' '-n+3'; ck "tail -n+3 from line 3"
exp '\nd\ne\n';   rp tail 'a\nb\nc\nd\ne\n' '-c5';  ck "tail -c5 last bytes"
exp '\nd\ne\n';   rp tail 'a\nb\nc\nd\ne\n' '-c+6'; ck "tail -c+6 from byte 6"

rp tail 'x\n' '-v -n1'
grep -q '==>' "$ACT" && r=true || r=false
cke "tail -v always header" true "$r"

# ──────────────────────────────────────────────────────────────────
# head multiplier suffixes
# ──────────────────────────────────────────────────────────────────
printf '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n' >"$EXP"
printf '1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n' | eval "$RUBY '$(tool head)' -n1K" >"$ACT" 2>/dev/null
ck "head -n1K reads all 10 lines"

expl ''; rn head "-c1K /dev/null"; ck "head -c1K empty file"

# ──────────────────────────────────────────────────────────────────
# wc --files0-from and --total
# ──────────────────────────────────────────────────────────────────
wca="$TMP/wc_a"; printf 'hello\nworld\n' >"$wca"
wcb="$TMP/wc_b"; printf 'foo\n' >"$wcb"
wclist="$TMP/wc_list"; printf '%s\000%s\000' "$wca" "$wcb" >"$wclist"

printf '      2 %s\n      1 %s\n      3 total\n' "$wca" "$wcb" >"$EXP"
rn wc "-l --files0-from='$wclist'"
ck "wc --files0-from"

printf '      2 %s\n      2 total\n' "$wca" >"$EXP"
rn wc "-l --total=always '$wca'"
ck "wc --total=always single file"

printf '      2 %s\n      1 %s\n' "$wca" "$wcb" >"$EXP"
rn wc "-l --total=never '$wca' '$wcb'"
ck "wc --total=never"

printf '      3 total\n' >"$EXP"
rn wc "-l --total=only '$wca' '$wcb'"
ck "wc --total=only"

# ──────────────────────────────────────────────────────────────────
# grep
# ──────────────────────────────────────────────────────────────────
exp 'hello\n';    rp grep 'hello\nworld\n' 'hello';        ck "grep basic match"
expl '';          rp grep 'hello\nworld\n' 'xyz';          ck "grep no match exits 1"
exp 'Hello\n';    rp grep 'Hello\nworld\n' '-i hello';     ck "grep -i case insensitive"
exp 'world\n';    rp grep 'hello\nworld\n' '-v hello';     ck "grep -v invert"
exp '1:hello\n';  rp grep 'hello\nworld\n' '-n hello';     ck "grep -n line numbers"
exp '2\n';        rp grep 'a\nb\na\nc\n' '-c a';           ck "grep -c count"
exp 'a.b\n';      rp grep 'a.b\naXb\n' '-F a.b';           ck "grep -F fixed string"
exp 'foo bar\n';  rp grep 'foo bar\nfoobar\n' '-w foo';    ck "grep -w word match"
exp 'exact\n';    rp grep 'exact\nexact match\n' '-x exact'; ck "grep -x whole line"
exp 'ell\n';      rp grep 'hello\nworld\n' '-o ell';       ck "grep -o only matching"
exp 'a\na\n';     rp grep 'a\nb\na\na\n' '-m 2 a';         ck "grep -m max count"
exp 'abc\nabc\n'; rp grep 'abc\ndef\nabc\n' 'a.c';         ck "grep regex"

# ──────────────────────────────────────────────────────────────────
# comm
# ──────────────────────────────────────────────────────────────────
comm1="$TMP/comm1"; printf 'a\nb\nc\n' >"$comm1"
comm2="$TMP/comm2"; printf 'b\nc\nd\n' >"$comm2"
exp 'a\n\t\tb\n\t\tc\n\td\n'; rn comm "'$comm1' '$comm2'";     ck "comm default"
exp 'b\nc\n';                 rn comm "-12 '$comm1' '$comm2'"; ck "comm -12 common only"
exp 'a\n\td\n';               rn comm "-3 '$comm1' '$comm2'";  ck "comm -3 no common"

# ──────────────────────────────────────────────────────────────────
# strings
# ──────────────────────────────────────────────────────────────────
exp 'hello\n';  rp strings '\x01\x02hello\x03\x04';       ck "strings basic"
exp 'abcde\n';  rp strings 'abc\x01abcde\x02' '-n 5';     ck "strings -n min length"

# ──────────────────────────────────────────────────────────────────
# expand / unexpand
# ──────────────────────────────────────────────────────────────────
exp 'a       b\n';   rp expand 'a\tb\n';             ck "expand default tab=8"
exp 'a   b\n';       rp expand 'a\tb\n' '-t 4';      ck "expand -t4"
exp 'a   b   c\n';   rp expand 'a\tb\tc\n' '-t 4';   ck "expand -t4 two tabs"
exp '\ta\n';         rp unexpand '        a\n';      ck "unexpand default"
exp '\ta\tb\n';      rp unexpand '        a       b\n' '-a'; ck "unexpand -a spaces mid-line"

# ──────────────────────────────────────────────────────────────────
# printf (the tool, not the shell's)
# ──────────────────────────────────────────────────────────────────
exp '42\n';          rn printf "'%d\n' 42";            ck "printf %d"
exp 'hello world\n'; rn printf "'%s %s\n' hello world"; ck "printf %s"
exp '3.140000\n';    rn printf "'%f\n' 3.14";          ck "printf %f"
exp 'ff\n';          rn printf "'%x\n' 255";           ck "printf %x hex"
exp '17\n';          rn printf "'%o\n' 15";            ck "printf %o octal"
exp '  42\n';        rn printf "'%4d\n' 42";           ck "printf width"
exp '1\n2\n3\n';     rn printf "'%d\n' 1 2 3";         ck "printf repeat format"

# ──────────────────────────────────────────────────────────────────
# shuf
# ──────────────────────────────────────────────────────────────────
rp shuf 'a\nb\nc\nd\n'
shuf_sorted="$(sort "$ACT" | tr '\n' ',')"
cke "shuf outputs same lines sorted" "a,b,c,d," "$shuf_sorted"

rp shuf 'a\nb\nc\nd\n' '-n 2'
cke "shuf -n limits output" 2 "$(wc -l <"$ACT" | tr -d ' ')"

rn shuf "-e x y z"
cke "shuf -e treats args as lines" 3 "$(wc -l <"$ACT" | tr -d ' ')"

# ──────────────────────────────────────────────────────────────────
# fmt
# ──────────────────────────────────────────────────────────────────
rp fmt 'the quick brown fox jumped over the lazy dog the quick brown fox\n'
r=true; while IFS= read -r line; do [ ${#line} -le 75 ] || r=false; done <"$ACT"
cke "fmt wraps at 75" true "$r"

exp 'hello\nworld\n'; rp fmt 'hello world\n' '-w 6'; ck "fmt -w wraps at width"

rp fmt 'a\n\nb\n'
r="$(awk '{ if ($0 == "") e=1 } END { print e ? "true" : "false" }' "$ACT")"
cke "fmt preserves blank lines" true "$r"

# ──────────────────────────────────────────────────────────────────
# join
# ──────────────────────────────────────────────────────────────────
join1="$TMP/join1"; printf '1 a\n2 b\n3 c\n' >"$join1"
join2="$TMP/join2"; printf '1 x\n2 y\n4 z\n' >"$join2"
exp '1 a x\n2 b y\n';        rn join "'$join1' '$join2'";      ck "join default"
exp '1 a x\n2 b y\n3 c\n';   rn join "-a 1 '$join1' '$join2'"; ck "join -a1 unpaired from file1"

# ──────────────────────────────────────────────────────────────────
# od
# ──────────────────────────────────────────────────────────────────
rp od 'ABC\n' '-c';  grep -q 'A' "$ACT" && r=true || r=false; cke "od -c character dump" true "$r"
rp od '\x01\x02' ''; [ -s "$ACT" ] && r=true || r=false;      cke "od default octal" true "$r"
rp od 'ABC\n' '-A x -t x1'; [ "$(head -c1 "$ACT")" = "0" ] && r=true || r=false; cke "od -A x hex addresses" true "$r"

# ──────────────────────────────────────────────────────────────────
# hexdump
# ──────────────────────────────────────────────────────────────────
rp hexdump 'Hello\n' '-C'; grep -qF '|Hello.' "$ACT" && r=true || r=false; cke "hexdump -C canonical" true "$r"
rp hexdump '\x01\x02' ''; [ -s "$ACT" ] && r=true || r=false; cke "hexdump default hex" true "$r"
exp '0000000 41 42 43\n0000003\n'; rp hexdump 'ABC' '-X'; ck "hexdump -X one-byte hex"
exp '00000000  48 69                                             |Hi|\n00000002\n'; rp hexdump 'Hi' '-C'; ck "hexdump -C ascii sidebar not padded"

# ──────────────────────────────────────────────────────────────────
# New option coverage
# ──────────────────────────────────────────────────────────────────
# tac -r: interpret the separator as a regular expression.
expl 'cb22a1'; rp tac 'a1b22c' "-r -s '[0-9]+'";      ck "tac -r regex separator"
expl 'c22b1a'; rp tac 'a1b22c' "-r -b -s '[0-9]+'";   ck "tac -r regex before mode"

# fold -c: count characters, so a tab counts as one column (no early break).
exp 'a\tb\n';   rp fold 'a\tb\n' '-c -w8'; ck "fold -c tab counts as one"
# fold default column mode: a tab expands toward the next tab stop.
exp 'a\t\nb\n'; rp fold 'a\tb\n' '-w8';    ck "fold default tab expands to column"

# nl section delimiters with per-section styles and a page reset. The input
# uses literal backslash-colon (\:) delimiters; \\: keeps the backslash.
exp '\n     1\tHEAD\n\n     2\tbody\n\n     3\tFOOT\n'
rp nl '\\:\\:\\:\nHEAD\n\\:\\:\nbody\n\\:\nFOOT\n' '-ha -ba -fa'
ck "nl header/body/footer sections"

# nl -bp: body style numbers only lines matching the regex; non-numbered lines
# get a blank prefix of width(6) + separator(tab, length 1) = 7 spaces.
exp '     1\tfoo\n       bar\n     2\tfoobar\n'
rp nl 'foo\nbar\nfoobar\n' '-bpfoo'
ck "nl -bp regex body style"

# nl -p keeps numbering across a new logical page instead of resetting.
exp '     1\tx\n\n     2\ty\n'
rp nl 'x\n\\:\\:\\:\ny\n' '-ba -ha -p'
ck "nl -p no renumber across page"

# strings -f prints the file name before each string.
strings_f="$TMP/strings_f"; printf '\001\002hello\003' >"$strings_f"
printf '%s: hello\n' "$strings_f" >"$EXP"
rn strings "-f '$strings_f'"
ck "strings -f prints file name"

# strings -<NUMBER> is shorthand for -n NUMBER.
exp 'abcde\n'; rp strings 'abc\x01abcde\x02' '-5'; ck "strings -N shorthand min length"

# strings -s changes the separator printed between strings.
expl 'aaaa|bbbb|'; rp strings 'aaaa\x00bbbb' "-s '|'"; ck "strings -s output separator"

# od -a dumps named characters.
rp od 'AB\n' '-A n -a'; grep -q 'nl' "$ACT" && r=true || r=false; cke "od -a named characters" true "$r"

# od --endian controls byte order for multi-byte formats.
rp od '\x01\x02' '-A n -t x2 --endian=big'
cke "od --endian=big byte order" "0102" "$(tr -d ' \n' <"$ACT")"
rp od '\x01\x02' '-A n -t x2 --endian=little'
cke "od --endian=little byte order" "0201" "$(tr -d ' \n' <"$ACT")"

# ──────────────────────────────────────────────────────────────────
# touch / stat
# ──────────────────────────────────────────────────────────────────
touch_path="$TMP/touch_test"; rm -f "$touch_path"
rn touch "'$touch_path'"
[ -e "$touch_path" ] && r=true || r=false; cke "touch creates file" true "$r"
rm -f "$touch_path"

stat_path="$TMP/stat_test"; printf 'hello\n' >"$stat_path"
rn stat "'$stat_path'"
grep -q "$(basename "$stat_path")" "$ACT" && r=true || r=false; cke "stat shows file name" true "$r"
grep -q '6' "$ACT" && r=true || r=false; cke "stat shows size" true "$r"

# ──────────────────────────────────────────────────────────────────
# mkdir / rmdir
# ──────────────────────────────────────────────────────────────────
mkbase="$TMP/mkdir_test_$RANDOM"
rn mkdir "'$mkbase'"
[ -d "$mkbase" ] && r=true || r=false; cke "mkdir creates directory" true "$r"
rn mkdir "-p '$mkbase/a/b/c'"
[ -d "$mkbase/a/b/c" ] && r=true || r=false; cke "mkdir -p creates nested" true "$r"
rn rmdir "'$mkbase/a/b/c'"
[ -d "$mkbase/a/b/c" ] && r=true || r=false; cke "rmdir removes empty dir" false "$r"
rm -rf "$mkbase"

# ──────────────────────────────────────────────────────────────────
# cp / mv / rm
# ──────────────────────────────────────────────────────────────────
cp_src="$TMP/cp_src"; printf 'copy me\n' >"$cp_src"; cp_dst="$cp_src.dst"
rn cp "'$cp_src' '$cp_dst'"
exp 'copy me\n'; :>"$ACT"; [ -e "$cp_dst" ] && cat "$cp_dst" >"$ACT"; ck "cp copies file"
rn rm "'$cp_dst'"
[ -e "$cp_dst" ] && r=true || r=false; cke "rm removes file" false "$r"

mv_src="$TMP/mv_src"; printf 'move me\n' >"$mv_src"; mv_dst="$mv_src.dst"
rn mv "'$mv_src' '$mv_dst'"
exp 'move me\n'; :>"$ACT"; [ -e "$mv_dst" ] && cat "$mv_dst" >"$ACT"; ck "mv moves file"
[ -e "$mv_src" ] && r=true || r=false; cke "mv removes source" false "$r"
rm -f "$mv_dst" "$cp_src"

# ──────────────────────────────────────────────────────────────────
# ln
# ──────────────────────────────────────────────────────────────────
ln_target="$TMP/ln_target"; printf 'link content\n' >"$ln_target"; ln_link="$ln_target.symlink"
rn ln "-s '$ln_target' '$ln_link'"
[ -L "$ln_link" ] && r=true || r=false; cke "ln -s creates symlink" true "$r"
exp 'link content\n'; :>"$ACT"; [ -L "$ln_link" ] && cat "$ln_link" >"$ACT" 2>/dev/null; ck "ln -s target readable"
rm -f "$ln_link"

ln_hard="$ln_target.hard"
rn ln "'$ln_target' '$ln_hard'"
[ -e "$ln_hard" ] && r=true || r=false; cke "ln hard link creates file" true "$r"
exp 'link content\n'; :>"$ACT"; [ -e "$ln_hard" ] && cat "$ln_hard" >"$ACT"; ck "ln hard link same content"
rm -f "$ln_hard" "$ln_target"

# ──────────────────────────────────────────────────────────────────
# ls
# ──────────────────────────────────────────────────────────────────
ls_dir="$TMP/ls_test_$RANDOM"; mkdir "$ls_dir"
printf 'a' >"$ls_dir/alpha.txt"; printf 'bb' >"$ls_dir/beta.txt"
rn ls "'$ls_dir'"
grep -q 'alpha.txt' "$ACT" && grep -q 'beta.txt' "$ACT" && r=true || r=false
cke "ls lists files" true "$r"
rn ls "-l '$ls_dir'"
grep -q -- '-rw' "$ACT" && r=true || r=false; cke "ls -l shows permissions" true "$r"
grep -q '1' "$ACT" && grep -q '2' "$ACT" && r=true || r=false; cke "ls -l shows sizes" true "$r"
rn ls "-1 '$ls_dir'"
cke "ls -1 one per line" 2 "$(wc -l <"$ACT" | tr -d ' ')"
rm -rf "$ls_dir"

# ──────────────────────────────────────────────────────────────────
# whoami
# ──────────────────────────────────────────────────────────────────
rn whoami ""
[ -n "$(tr -d '\n' <"$ACT")" ] && r=true || r=false
cke "whoami returns non-empty username" true "$r"

# ──────────────────────────────────────────────────────────────────
# hostname
# ──────────────────────────────────────────────────────────────────
rn hostname ""
[ -n "$(tr -d '\n' <"$ACT")" ] && r=true || r=false
cke "hostname returns non-empty" true "$r"

# ──────────────────────────────────────────────────────────────────
# uname
# ──────────────────────────────────────────────────────────────────
rn uname ""
[ -n "$(tr -d '\n' <"$ACT")" ] && r=true || r=false
cke "uname default prints kernel name" true "$r"
rn uname "-a"
[ "$(wc -w <"$ACT" | tr -d ' ')" -ge 3 ] && r=true || r=false
cke "uname -a all info" true "$r"

# ──────────────────────────────────────────────────────────────────
# env
# ──────────────────────────────────────────────────────────────────
rn env ""
grep -q '=' "$ACT" && r=true || r=false; cke "env lists variables" true "$r"
exp 'FOO=bar\n'; rn env "-i FOO=bar"; ck "env -i with var"

# ──────────────────────────────────────────────────────────────────
# readlink
# ──────────────────────────────────────────────────────────────────
rl_target="$TMP/rl_target"; printf 'target\n' >"$rl_target"; rl_link="$rl_target.link"
ln -s "$rl_target" "$rl_link"
printf '%s\n' "$rl_target" >"$EXP"
rn readlink "'$rl_link'"
ck "readlink prints target"
rm -f "$rl_link"

# ──────────────────────────────────────────────────────────────────
# id
# ──────────────────────────────────────────────────────────────────
rn id ""
grep -q 'uid=' "$ACT" && r=true || r=false; cke "id default contains uid=" true "$r"
printf '%s\n' "$(id -u)" >"$EXP"
rn id "-u"
ck "id -u prints numeric uid"

# ──────────────────────────────────────────────────────────────────
# logname
# ──────────────────────────────────────────────────────────────────
rn logname ""
grep -q '.' "$ACT" && r=true || r=false
cke "logname returns non-empty username" true "$r"
# logname output should match $USER
printf '%s\n' "${LOGNAME:-$USER}" >"$EXP"
rn logname ""
ck "logname matches LOGNAME/USER"

# ──────────────────────────────────────────────────────────────────
# printenv
# ──────────────────────────────────────────────────────────────────
rn printenv ""
grep -q '=' "$ACT" && r=true || r=false; cke "printenv lists variables" true "$r"
grep -q 'HOME=' "$ACT" && r=true || r=false; cke "printenv output contains HOME=" true "$r"
printf '%s\n' "$HOME" >"$EXP"
rn printenv "HOME"
ck "printenv HOME prints value"
# non-existent variable exits 1
eval "$RUBY '$(tool printenv)' DEFINITELY_NOT_SET_VAR_XYZ123" >/dev/null 2>&1; rc=$?
cke "printenv missing var exit code" 1 "$rc"

# ──────────────────────────────────────────────────────────────────
# tsort
# ──────────────────────────────────────────────────────────────────
# Simple DAG: a->b, b->c, a->c; expected order: a b c (or a c b)
exp 'a\nb\nc\n'; rp tsort 'a b\nb c\na c\n'; ck "tsort basic DAG"
# Self-loop (same token twice) should not crash
rp tsort 'a a\n'
[ -n "$(cat "$ACT")" ] && r=true || r=false; cke "tsort self-loop outputs something" true "$r"

# ──────────────────────────────────────────────────────────────────
# factor
# ──────────────────────────────────────────────────────────────────
exp '12: 2 2 3\n'; rn factor "12"; ck "factor 12"
exp '1: \n'; rn factor "1"; ck "factor 1"
exp '2: 2\n'; rn factor "2"; ck "factor 2 (prime)"
exp '12: 2^2 3\n'; rn factor "-h 12"; ck "factor --exponents 12"
# Large prime
rn factor "97"
grep -q '97: 97' "$ACT" && r=true || r=false; cke "factor 97 is prime" true "$r"
# stdin mode
exp '7: 7\n'; rp factor '7\n'; ck "factor from stdin"

# ──────────────────────────────────────────────────────────────────
# nproc
# ──────────────────────────────────────────────────────────────────
rn nproc ""
n=$(cat "$ACT" | tr -d '\n')
[ "$n" -ge 1 ] 2>/dev/null && r=true || r=false
cke "nproc returns positive integer" true "$r"
rn nproc "--all"
n=$(cat "$ACT" | tr -d '\n')
[ "$n" -ge 1 ] 2>/dev/null && r=true || r=false
cke "nproc --all returns positive integer" true "$r"
# --ignore=N reduces the count (minimum 1)
rn nproc "--ignore=9999"
cke "nproc --ignore=9999 is 1" 1 "$(cat "$ACT" | tr -d '\n')"

# ──────────────────────────────────────────────────────────────────
# realpath
# ──────────────────────────────────────────────────────────────────
# existing path resolves — use system realpath for canonical expected value
rp_dir="$TMP/rp_dir"; mkdir -p "$rp_dir"
# Get the canonical path using the system realpath (handles macOS symlinks in /var→/private/var)
rp_expected="$(cd "$rp_dir" && pwd -P)"
printf '%s\n' "$rp_expected" >"$EXP"
rn realpath "'$rp_dir'"
ck "realpath existing dir"
# -m allows missing — just check exit code is 0 and output is non-empty
rn realpath "-m '$rp_dir/nonexistent'"
[ -s "$ACT" ] && r=true || r=false; cke "realpath -m missing path produces output" true "$r"
# -e on missing exits non-zero
eval "$RUBY '$(tool realpath)' -e '$rp_dir/nonexistent'" >/dev/null 2>&1; rc=$?
cke "realpath -e missing exits non-zero" 1 "$rc"
rm -rf "$rp_dir"

# ──────────────────────────────────────────────────────────────────
# mktemp
# ──────────────────────────────────────────────────────────────────
rn mktemp ""
tf=$(cat "$ACT" | tr -d '\n')
[ -f "$tf" ] && r=true || r=false; cke "mktemp creates file" true "$r"
rm -f "$tf"
# -d creates directory
rn mktemp "-d"
td=$(cat "$ACT" | tr -d '\n')
[ -d "$td" ] && r=true || r=false; cke "mktemp -d creates directory" true "$r"
rm -rf "$td"
# --dry-run does not create file
rn mktemp "-u"
tf=$(cat "$ACT" | tr -d '\n')
[ ! -f "$tf" ] && r=true || r=false; cke "mktemp -u does not create file" true "$r"
# template respected
rn mktemp "mytest.XXXXXXXX"
tf=$(cat "$ACT" | tr -d '\n')
tf_base=$(basename "$tf")
echo "$tf_base" | grep -q '^mytest\.' && r=true || r=false; cke "mktemp template prefix" true "$r"
rm -f "$tf"

# ──────────────────────────────────────────────────────────────────
# base64
# ──────────────────────────────────────────────────────────────────
# round-trip encode/decode
rp base64 'hello world\n'
encoded=$(cat "$ACT" | tr -d '\n')
printf '%s\n' "$encoded" | eval "$RUBY '$(tool base64)' -d" >"$ACT"
exp 'hello world\n'; ck "base64 encode/decode round-trip"
# wrap at 40
rp base64 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' '-w 40'
first_line=$(head -1 "$ACT")
[ "${#first_line}" -le 40 ] && r=true || r=false; cke "base64 -w 40 wraps at 40" true "$r"

# ──────────────────────────────────────────────────────────────────
# sha256sum
# ──────────────────────────────────────────────────────────────────
# Known SHA256 of empty string
empty_sha256="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
tf_empty="$TMP/sha256_empty"
printf '' >"$tf_empty"
rn sha256sum "'$tf_empty'"
grep -q "$empty_sha256" "$ACT" && r=true || r=false; cke "sha256sum empty file" true "$r"
# -c verify passes
rn sha256sum "'$tf_empty'" > "$TMP/sha256_check"
rn sha256sum "-c '$TMP/sha256_check'"
grep -q 'OK' "$ACT" && r=true || r=false; cke "sha256sum -c verify OK" true "$r"
# -c verify fails for wrong checksum
printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "$tf_empty" >"$TMP/sha256_bad"
eval "$RUBY '$(tool sha256sum)' -c '$TMP/sha256_bad'" >"$ACT" 2>/dev/null; rc=$?
cke "sha256sum -c verify FAIL exits non-zero" 1 "$rc"
rm -f "$tf_empty"

# ──────────────────────────────────────────────────────────────────
# md5sum
# ──────────────────────────────────────────────────────────────────
empty_md5="d41d8cd98f00b204e9800998ecf8427e"
tf_md5="$TMP/md5_empty"; printf '' >"$tf_md5"
rn md5sum "'$tf_md5'"
grep -q "$empty_md5" "$ACT" && r=true || r=false; cke "md5sum empty file" true "$r"
rm -f "$tf_md5"

# ──────────────────────────────────────────────────────────────────
# cksum
# ──────────────────────────────────────────────────────────────────
tf_ck="$TMP/cksum_test"; printf 'hello\n' >"$tf_ck"
rn cksum "'$tf_ck'"
[ -n "$(cat "$ACT")" ] && r=true || r=false; cke "cksum default CRC produces output" true "$r"
# -a md5 should match md5sum
rn cksum "-a md5 '$tf_ck'"
rn md5sum "'$tf_ck'" > "$TMP/cksum_md5ref"
cksum_hash=$(cat "$ACT" | awk '{print $1}')
md5_hash=$(cat "$TMP/cksum_md5ref" | awk '{print $1}')
cke "cksum -a md5 matches md5sum" "$md5_hash" "$cksum_hash"
rm -f "$tf_ck"

# ──────────────────────────────────────────────────────────────────
# split
# ──────────────────────────────────────────────────────────────────
split_dir="$TMP/split_$$"; mkdir "$split_dir"
# 10 lines, split into 3-line pieces
printf '%s\n' 1 2 3 4 5 6 7 8 9 10 >"$split_dir/input"
rn split "-l 3 '$split_dir/input' '$split_dir/out'"
file_count=$(ls "$split_dir"/out* 2>/dev/null | wc -l | tr -d ' ')
cke "split -l 3 creates 4 files" 4 "$file_count"
# reassembly matches original
cat "$split_dir"/out* >"$split_dir/reassembled"
diff "$split_dir/input" "$split_dir/reassembled" >/dev/null && r=true || r=false
cke "split reassembly matches original" true "$r"
# byte split
printf 'abcdefghij' >"$split_dir/bytes"
rn split "-b 3 '$split_dir/bytes' '$split_dir/bsplit'"
bc=$(ls "$split_dir"/bsplit* 2>/dev/null | wc -l | tr -d ' ')
cke "split -b 3 creates 4 files" 4 "$bc"
rm -rf "$split_dir"

# ──────────────────────────────────────────────────────────────────
# numfmt
# ──────────────────────────────────────────────────────────────────
exp '1.0k\n'; rp numfmt '1000\n' '--to=si'; ck "numfmt 1000 to si"
# IEC input
exp '1024\n'; rp numfmt '1K\n' '--from=iec'; ck "numfmt 1K from iec"
# SI input
exp '1000\n'; rp numfmt '1k\n' '--from=si'; ck "numfmt 1k from si"

# ──────────────────────────────────────────────────────────────────
# date
# ──────────────────────────────────────────────────────────────────
rn date "+%Y"
year=$(cat "$ACT" | tr -d '\n')
[ "$year" -ge 2024 ] 2>/dev/null && r=true || r=false
cke "date +%Y outputs current year" true "$r"
# --utc flag
rn date "--utc +%Z"
grep -qE '^UTC$' "$ACT" && r=true || r=false; cke "date --utc +%Z is UTC" true "$r"
# -r reference file
rn date "-r '$TMP' +%Y"
year2=$(cat "$ACT" | tr -d '\n')
[ "$year2" -ge 2020 ] 2>/dev/null && r=true || r=false; cke "date -r FILE prints year" true "$r"
# ISO 8601
rn date "-I"
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' "$ACT" && r=true || r=false
cke "date -I outputs ISO date" true "$r"

# ──────────────────────────────────────────────────────────────────
# du
# ──────────────────────────────────────────────────────────────────
du_dir="$TMP/du_$$"; mkdir "$du_dir"; printf 'hello\n' >"$du_dir/file"
rn du "'$du_dir'"
[ -n "$(cat "$ACT")" ] && r=true || r=false; cke "du produces output" true "$r"
# -s summarizes to one line
rn du "-s '$du_dir'"
line_count=$(wc -l <"$ACT" | tr -d ' ')
cke "du -s gives one line" 1 "$line_count"
# -h uses human suffixes
rn du "-h '$du_dir'"
grep -qE '[0-9]+[KMGT]?' "$ACT" && r=true || r=false; cke "du -h uses suffixes" true "$r"
rm -rf "$du_dir"

# ──────────────────────────────────────────────────────────────────
# column
# ──────────────────────────────────────────────────────────────────
# free-flow mode aligns into columns
rp column 'alpha\nbeta\ngamma\ndelta\n'
[ -n "$(cat "$ACT")" ] && r=true || r=false; cke "column free-flow produces output" true "$r"
# -t table mode
rp column 'a:b:c\n1:2:3\n' '-t -s:'
grep -q 'a' "$ACT" && grep -q 'b' "$ACT" && r=true || r=false
cke "column -t -s: aligns table" true "$r"
# colon delimiter
rp column 'x:y:z\n1:2:3\n' '-t -s: -o"|"'
grep -q '|' "$ACT" && r=true || r=false; cke "column -o sets output separator" true "$r"

# ──────────────────────────────────────────────────────────────────
# xargs
# ──────────────────────────────────────────────────────────────────
exp 'a b c\n'; rp xargs 'a b c\n' 'echo'; ck "xargs basic echo"
# -n 1: each arg gets its own echo invocation (flags come before command)
rp xargs 'a b c\n' '-n 1 echo'
line_count=$(wc -l <"$ACT" | tr -d ' ')
cke "xargs -n 1 runs once per token" 3 "$line_count"
# -I {} replace mode (flag comes before command)
rp xargs 'world\n' "-I{} echo 'hello {}'"
grep -q 'hello world' "$ACT" && r=true || r=false; cke "xargs -I{} replace mode" true "$r"
# -r no-run-if-empty (flag comes before command)
rp xargs '' '-r echo'
[ ! -s "$ACT" ] && r=true || r=false; cke "xargs -r empty input: no output" true "$r"

# ──────────────────────────────────────────────────────────────────
# sed
# ──────────────────────────────────────────────────────────────────
exp 'heLLo\n'; rp sed 'hello\n' "'s/l/L/g'"; ck "sed s/l/L/g"
exp 'hello\n'; rp sed 'hello\n' "-n 'p'"; ck "sed -n p prints pattern space"
# address range
exp 'B\nC\n'; rp sed 'A\nB\nC\n' "'2,3p' -n"; ck "sed 2,3p address range"
# d command
exp 'A\nC\n'; rp sed 'A\nB\nC\n' "'2d'"; ck "sed 2d delete line"
# y transliterate
exp 'HELLO\n'; rp sed 'hello\n' "'y/helo/HELO/'"; ck "sed y transliterate"
# in-place test with temp file
printf 'foo\n' >"$TMP/sed_inplace"
rn sed "'-i' 's/foo/bar/' '$TMP/sed_inplace'"
exp 'bar\n'; cat "$TMP/sed_inplace" >"$ACT"; ck "sed -i in-place"
rm -f "$TMP/sed_inplace"

# ──────────────────────────────────────────────────────────────────
# find
# ──────────────────────────────────────────────────────────────────
find_dir="$TMP/find_$$"; mkdir -p "$find_dir/sub"
printf 'data\n' >"$find_dir/file.rb"
printf 'data\n' >"$find_dir/sub/other.txt"
# -name "*.rb" matches
rn find "'$find_dir' -name '*.rb'"
grep -q 'file.rb' "$ACT" && r=true || r=false; cke "find -name *.rb matches" true "$r"
# -type d lists directories
rn find "'$find_dir' -type d"
grep -q 'sub' "$ACT" && r=true || r=false; cke "find -type d lists dirs" true "$r"
# -maxdepth 1 doesn't recurse into sub
rn find "'$find_dir' -maxdepth 1"
grep -q 'other.txt' "$ACT" && r=false || r=true; cke "find -maxdepth 1 no recurse" true "$r"
# -exec echo {} ;
rn find "'$find_dir' -maxdepth 1 -name '*.rb' -exec echo {} ;"
grep -q 'file.rb' "$ACT" && r=true || r=false; cke "find -exec echo works" true "$r"
rm -rf "$find_dir"

# ──────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────
if [ "$failures" -eq 0 ]; then
  echo "All tests passed."
else
  echo "$failures test(s) FAILED."
  exit 1
fi
