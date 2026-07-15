# nix_utils_test.rb
#
# Integration tests for the nix_utils reimplementations. Each test runs the
# tool via `ruby tool.rb` and compares stdout to the expected output.
# Prints "label:ok" or "label:FAIL expected=... got=..." for each check.
#
# Run from the repository root:
#   ruby tests/nix_utils_test.rb

TOOLS_DIR = File.expand_path("../nix_utils", File.dirname(__FILE__))

$failures = 0

def check(label, expected, actual)
  if expected == actual
    puts "#{label}:ok"
  else
    puts "#{label}:FAIL expected=#{expected.inspect} got=#{actual.inspect}"
    $failures += 1
  end
end

# Run a tool file with given arguments and optional stdin. Returns stdout.
def run(tool, args = "", stdin = nil)
  rb = "#{TOOLS_DIR}/#{tool}.rb"
  cmd = "ruby #{rb} #{args}"
  if stdin
    cmd = "echo -n #{stdin.gsub("'", "'\\''")} | #{cmd}"
  end
  `#{cmd} 2>/dev/null`
end

# Use printf-style for multiline stdin to avoid shell escaping issues.
def run_printf(tool, fmt, args = "")
  rb = "#{TOOLS_DIR}/#{tool}.rb"
  `printf '#{fmt}' | ruby #{rb} #{args} 2>/dev/null`
end

# ──────────────────────────────────────────────────────────────────
# tac
# ──────────────────────────────────────────────────────────────────
check("tac basic",
      "c\nb\na\n",
      run_printf("tac", "a\\nb\\nc\\n"))

check("tac single line",
      "a\n",
      run_printf("tac", "a\\n"))

check("tac custom separator",
      "c,b,a,",
      run_printf("tac", "a,b,c,", "-s,"))

check("tac before mode",
      "c\nb\na",
      run_printf("tac", "a\\nb\\nc", "-b"))

# ──────────────────────────────────────────────────────────────────
# seq
# ──────────────────────────────────────────────────────────────────
check("seq LAST",          "1\n2\n3\n",       run("seq", "3"))
check("seq FIRST LAST",    "3\n4\n5\n",       run("seq", "3 5"))
check("seq FIRST INC LAST","0\n2\n4\n",       run("seq", "0 2 4"))
check("seq descending",    "5\n4\n3\n",       run("seq", "5 -1 3"))
check("seq -s separator",  "1,2,3,4,5\n",     run("seq", "-s, 1 5"))
check("seq -w equal width","08\n09\n10\n",    run("seq", "-w 8 10"))
check("seq float",
      "1.0\n1.5\n2.0\n",
      run("seq", "1.0 0.5 2.0"))

# ──────────────────────────────────────────────────────────────────
# sort
# ──────────────────────────────────────────────────────────────────
check("sort basic",
      "apple\nbanana\ncherry\n",
      run_printf("sort", "banana\\ncherry\\napple\\n"))

check("sort -r reverse",
      "cherry\nbanana\napple\n",
      run_printf("sort", "apple\\nbanana\\ncherry\\n", "-r"))

check("sort -n numeric",
      "1\n3\n10\n25\n",
      run_printf("sort", "10\\n3\\n25\\n1\\n", "-n"))

check("sort -u unique",
      "a\nb\nc\n",
      run_printf("sort", "a\\nb\\na\\nc\\nb\\n", "-u"))

check("sort -f case insensitive",
      "a\nApple\nb\n",
      run_printf("sort", "Apple\\nb\\na\\n", "-f"))

check("sort -k field",
      "root:0\nuser:1000\n",
      run_printf("sort", "user:1000\\nroot:0\\n", "-t: -k2n"))

# ──────────────────────────────────────────────────────────────────
# uniq
# ──────────────────────────────────────────────────────────────────
check("uniq basic",
      "a\nb\nc\n",
      run_printf("uniq", "a\\na\\nb\\nb\\nc\\n"))

check("uniq -c count",
      "      2 a\n      1 b\n      3 c\n",
      run_printf("uniq", "a\\na\\nb\\nc\\nc\\nc\\n", "-c"))

check("uniq -d repeated only",
      "a\nc\n",
      run_printf("uniq", "a\\na\\nb\\nc\\nc\\nc\\n", "-d"))

check("uniq -u unique only",
      "b\n",
      run_printf("uniq", "a\\na\\nb\\nc\\nc\\n", "-u"))

check("uniq -i ignore case",
      "a\nb\n",
      run_printf("uniq", "a\\nA\\nb\\n", "-i"))

# ──────────────────────────────────────────────────────────────────
# cut
# ──────────────────────────────────────────────────────────────────
check("cut -f fields tab",
      "a\n1\n",
      run_printf("cut", "a\\tb\\tc\\n1\\t2\\t3\\n", "-f1"))

check("cut -d: -f1,3",
      "root:0\nuser:1000\n",
      run_printf("cut", "root:x:0:0\\nuser:x:1000:1000\\n", "-d: -f1,3"))

check("cut -c range",
      "bcd\nhij\n",
      run_printf("cut", "abcdef\\nghijkl\\n", "-c2-4"))

check("cut -c open end",
      "cdef\nijkl\n",
      run_printf("cut", "abcdef\\nghijkl\\n", "-c3-"))

check("cut -f complement",
      "b\n2\n",
      run_printf("cut", "a\\tb\\tc\\n1\\t2\\t3\\n", "-f1,3 --complement"))

check("cut -s suppress no-delim",
      "a:b\n",
      run_printf("cut", "a:b\\nnodeli\\n", "-d: -f1,2 -s"))

# ──────────────────────────────────────────────────────────────────
# tr
# ──────────────────────────────────────────────────────────────────
check("tr uppercase",
      "HELLO WORLD\n",
      run_printf("tr", "hello world\\n", "'a-z' 'A-Z'"))

check("tr -d delete",
      "Hll Wrld\n",
      run_printf("tr", "Hello World\\n", "-d 'aeiouAEIOU'"))

check("tr -s squeeze",
      "abc\n",
      run_printf("tr", "aabbcc\\n", "-s 'a-c'"))

check("tr -d -s delete and squeeze",
      "bc\n",
      run_printf("tr", "aabbc\\n", "-ds 'a' 'b-c'"))

check("tr escape sequences",
      "a b\n",
      run_printf("tr", "a\\tb\\n", "'\\t' ' '"))

# ──────────────────────────────────────────────────────────────────
# tee (output to file)
# ──────────────────────────────────────────────────────────────────
require "tmpdir"
tee_tmp = File.join(Dir.tmpdir, "nix_utils_tee_test.txt")
File.delete(tee_tmp) if File.exist?(tee_tmp)

rb = "#{TOOLS_DIR}/tee.rb"
stdout = `printf 'hello\n' | ruby #{rb} #{tee_tmp} 2>/dev/null`
check("tee stdout", "hello\n", stdout)
check("tee file",   "hello\n", File.exist?(tee_tmp) ? File.read(tee_tmp) : "(missing)")

# Append mode.
`printf 'world\n' | ruby #{rb} -a #{tee_tmp} 2>/dev/null`
check("tee append", "hello\nworld\n", File.exist?(tee_tmp) ? File.read(tee_tmp) : "(missing)")
File.delete(tee_tmp) if File.exist?(tee_tmp)

# ──────────────────────────────────────────────────────────────────
# paste
# ──────────────────────────────────────────────────────────────────
require "tempfile"
pa_file = Tempfile.new("nix_utils_paste")
pb_file = Tempfile.new("nix_utils_paste")
pa_file.write("a\nb\nc\n"); pa_file.flush
pb_file.write("1\n2\n3\n"); pb_file.flush

rb = "#{TOOLS_DIR}/paste.rb"
check("paste parallel",
      "a\t1\nb\t2\nc\t3\n",
      `ruby #{rb} #{pa_file.path} #{pb_file.path} 2>/dev/null`)

check("paste -d delimiter",
      "a,1\nb,2\nc,3\n",
      `ruby #{rb} -d, #{pa_file.path} #{pb_file.path} 2>/dev/null`)

check("paste -s serial",
      "a\tb\tc\n",
      `ruby #{rb} -s #{pa_file.path} 2>/dev/null`)

pa_file.close; pa_file.unlink
pb_file.close; pb_file.unlink

# ──────────────────────────────────────────────────────────────────
# fold
# ──────────────────────────────────────────────────────────────────
check("fold -w wrap",
      "abcde\nfghij\n",
      run_printf("fold", "abcdefghij\\n", "-w5"))

check("fold -w -s break at space",
      "hello \nworld\n",
      run_printf("fold", "hello world\\n", "-w7 -s"))

check("fold short line no wrap",
      "abc\n",
      run_printf("fold", "abc\\n", "-w10"))

# ──────────────────────────────────────────────────────────────────
# nl
# ──────────────────────────────────────────────────────────────────
check("nl default (nonempty)",
      "     1\tfoo\n       \n     2\tbar\n",
      run_printf("nl", "foo\\n\\nbar\\n"))

check("nl -ba all lines",
      "     1\tfoo\n     2\t\n     3\tbar\n",
      run_printf("nl", "foo\\n\\nbar\\n", "-ba"))

check("nl -v start -i increment",
      "    10\ta\n    15\tb\n",
      run_printf("nl", "a\\nb\\n", "-v10 -i5"))

check("nl -nrz zero padded",
      "000001\tfoo\n",
      run_printf("nl", "foo\\n", "-nrz -w6"))

# ──────────────────────────────────────────────────────────────────
# basename / dirname
# ──────────────────────────────────────────────────────────────────
check("basename path",   "ruby\n",        run("basename", "/usr/bin/ruby"))
check("basename suffix", "libfoo\n",      run("basename", "/lib/libfoo.so .so"))
check("basename -a",     "a\nb\n",        run("basename", "-a /x/a /y/b"))
check("dirname path",    "/usr/bin\n",    run("dirname", "/usr/bin/ruby"))
check("dirname no dir",  ".\n",           run("dirname", "foo"))
check("dirname root",    "/\n",           run("dirname", "/"))

# ──────────────────────────────────────────────────────────────────
# pwd
# ──────────────────────────────────────────────────────────────────
# We just check that it outputs a non-empty absolute path.
pwd_out = run("pwd").chomp
check("pwd is absolute", true, pwd_out.length > 0 && pwd_out[0] == "/")

# ──────────────────────────────────────────────────────────────────
# sleep
# ──────────────────────────────────────────────────────────────────
start = Time.now
run("sleep", "0.1")
elapsed = Time.now - start
check("sleep duration", true, elapsed >= 0.05)

# ──────────────────────────────────────────────────────────────────
# echo
# ──────────────────────────────────────────────────────────────────
check("echo basic",
      "hello world\n",
      `ruby #{TOOLS_DIR}/echo.rb hello world 2>/dev/null`)

check("echo -n no newline",
      "hello",
      `ruby #{TOOLS_DIR}/echo.rb -n hello 2>/dev/null`)

check("echo -e escape sequences",
      "a\tb\n",
      `ruby #{TOOLS_DIR}/echo.rb -e 'a\\tb' 2>/dev/null`)

check("echo -e newline escape",
      "a\nb\n",
      `ruby #{TOOLS_DIR}/echo.rb -e 'a\\nb' 2>/dev/null`)

# ──────────────────────────────────────────────────────────────────
# yes
# ──────────────────────────────────────────────────────────────────
yes_out = `ruby #{TOOLS_DIR}/yes.rb | head -3 2>/dev/null`
check("yes outputs y lines",
      "y\ny\ny\n",
      yes_out)

yes_custom = `ruby #{TOOLS_DIR}/yes.rb no | head -2 2>/dev/null`
check("yes custom string",
      "no\nno\n",
      yes_custom)

# ──────────────────────────────────────────────────────────────────
# true / false
# ──────────────────────────────────────────────────────────────────
system("ruby #{TOOLS_DIR}/true.rb")
check("true exit 0", 0, $?.exitstatus)
system("ruby #{TOOLS_DIR}/false.rb")
check("false exit 1", 1, $?.exitstatus)

# ──────────────────────────────────────────────────────────────────
# cat -v / -A / -e / -t (show-nonprinting)
# ──────────────────────────────────────────────────────────────────

# \x01 = SOH (^A), \x80 = 0x80 (M-^@)
cat_rb = "#{TOOLS_DIR}/cat.rb"
check("cat -v control char",
      "Hello^AWorld\n",
      `printf 'Hello\001World\n' | ruby #{cat_rb} -v 2>/dev/null`)

check("cat -v high byte",
      "M-^@\n",
      `printf '\200\n' | ruby #{cat_rb} -v 2>/dev/null`)

check("cat -A (vET) tab and end",
      "^IHello^AWorld$\n",
      `printf '\tHello\001World\n' | ruby #{cat_rb} -A 2>/dev/null`)

check("cat -e (vE) end only",
      "hello$\n",
      `printf 'hello\n' | ruby #{cat_rb} -e 2>/dev/null`)

check("cat -t (vT) tab only",
      "^Ihello\n",
      `printf '\thello\n' | ruby #{cat_rb} -t 2>/dev/null`)

# ──────────────────────────────────────────────────────────────────
# tail
# ──────────────────────────────────────────────────────────────────
check("tail -n3 last lines",
      "c\nd\ne\n",
      run_printf("tail", "a\\nb\\nc\\nd\\ne\\n", "-n3"))

check("tail -n+3 from line 3",
      "c\nd\ne\n",
      run_printf("tail", "a\\nb\\nc\\nd\\ne\\n", "-n+3"))

# "a\nb\nc\nd\ne\n" = 10 bytes; last 5 start at position 5 = "\nd\ne\n"
check("tail -c5 last bytes",
      "\nd\ne\n",
      run_printf("tail", "a\\nb\\nc\\nd\\ne\\n", "-c5"))

# -c+6: from byte 6 (1-indexed) = position 5 (0-indexed) = "\nd\ne\n"
check("tail -c+6 from byte 6",
      "\nd\ne\n",
      run_printf("tail", "a\\nb\\nc\\nd\\ne\\n", "-c+6"))

# -z NUL-delimited: use a temp file to avoid NUL bytes in Ruby backtick strings.
nul_tmp = Tempfile.new("nix_nul_tail")
nul_tmp.write("a\0b\0c\0d\0e\0"); nul_tmp.flush
nul_tail = `ruby #{TOOLS_DIR}/tail.rb -z -n2 #{nul_tmp.path} 2>/dev/null`
check("tail -z NUL delimited", "d\0e\0", nul_tail)
nul_tmp.close; nul_tmp.unlink

check("tail -v always header",
      true,
      run_printf("tail", "x\\n", "-v -n1").include?("==>"))

# ──────────────────────────────────────────────────────────────────
# head -z and multiplier suffixes
# ──────────────────────────────────────────────────────────────────
# -z NUL-delimited: use a temp file to avoid NUL bytes in backtick strings.
nul_htmp = Tempfile.new("nix_nul_head")
nul_htmp.write("a\0b\0c\0"); nul_htmp.flush
nul_head = `ruby #{TOOLS_DIR}/head.rb -z -n2 #{nul_htmp.path} 2>/dev/null`
check("head -z NUL delimited", "a\0b\0", nul_head)
nul_htmp.close; nul_htmp.unlink

# multiplier: -n 1K = 1024 lines; use a short file so all lines fit
lines_1k = (1..10).map { |i| i.to_s }.join("\n") + "\n"
head_1k  = `printf '#{lines_1k.gsub("'", "'\\''")}' | ruby #{TOOLS_DIR}/head.rb -n1K 2>/dev/null`
check("head -n1K reads all 10 lines", lines_1k, head_1k)

# -c with bytes multiplier
check("head -c1K empty file",
      "",
      `ruby #{TOOLS_DIR}/head.rb -c1K /dev/null 2>/dev/null`)

# ──────────────────────────────────────────────────────────────────
# wc --files0-from and --total
# ──────────────────────────────────────────────────────────────────
require "tempfile"
wca = Tempfile.new("wc_a"); wca.write("hello\nworld\n"); wca.flush
wcb = Tempfile.new("wc_b"); wcb.write("foo\n");          wcb.flush

# --files0-from
filelist = Tempfile.new("wc_list")
filelist.write("#{wca.path}\0#{wcb.path}\0")
filelist.flush
check("wc --files0-from",
      "      2 #{wca.path}\n      1 #{wcb.path}\n      3 total\n",
      `ruby #{TOOLS_DIR}/wc.rb -l --files0-from=#{filelist.path} 2>/dev/null`)

# --total=always: prints total even for a single file
check("wc --total=always single file",
      "      2 #{wca.path}\n      2 total\n",
      `ruby #{TOOLS_DIR}/wc.rb -l --total=always #{wca.path} 2>/dev/null`)

# --total=never: never prints total even for multiple files
check("wc --total=never",
      "      2 #{wca.path}\n      1 #{wcb.path}\n",
      `ruby #{TOOLS_DIR}/wc.rb -l --total=never #{wca.path} #{wcb.path} 2>/dev/null`)

# --total=only: only prints the total, suppresses individual rows
check("wc --total=only",
      "      3 total\n",
      `ruby #{TOOLS_DIR}/wc.rb -l --total=only #{wca.path} #{wcb.path} 2>/dev/null`)

wca.close; wca.unlink
wcb.close; wcb.unlink
filelist.close; filelist.unlink

# ──────────────────────────────────────────────────────────────────
# grep
# ──────────────────────────────────────────────────────────────────
check("grep basic match",
      "hello\n",
      run_printf("grep", "hello\\nworld\\n", "hello"))

check("grep no match exits 1",
      "",
      run_printf("grep", "hello\\nworld\\n", "xyz"))

check("grep -i case insensitive",
      "Hello\n",
      run_printf("grep", "Hello\\nworld\\n", "-i hello"))

check("grep -v invert",
      "world\n",
      run_printf("grep", "hello\\nworld\\n", "-v hello"))

check("grep -n line numbers",
      "1:hello\n",
      run_printf("grep", "hello\\nworld\\n", "-n hello"))

check("grep -c count",
      "2\n",
      run_printf("grep", "a\\nb\\na\\nc\\n", "-c a"))

check("grep -F fixed string",
      "a.b\n",
      run_printf("grep", "a.b\\naXb\\n", "-F a.b"))

check("grep -w word match",
      "foo bar\n",
      run_printf("grep", "foo bar\\nfoobar\\n", "-w foo"))

check("grep -x whole line",
      "exact\n",
      run_printf("grep", "exact\\nexact match\\n", "-x exact"))

check("grep -o only matching",
      "ell\n",
      run_printf("grep", "hello\\nworld\\n", "-o ell"))

check("grep -m max count",
      "a\na\n",
      run_printf("grep", "a\\nb\\na\\na\\n", "-m 2 a"))

check("grep regex",
      "abc\nabc\n",
      run_printf("grep", "abc\\ndef\\nabc\\n", "a.c"))

# ──────────────────────────────────────────────────────────────────
# comm
# ──────────────────────────────────────────────────────────────────
require "tempfile"

comm_f1 = Tempfile.new("comm1")
comm_f1.write("a\nb\nc\n")
comm_f1.flush

comm_f2 = Tempfile.new("comm2")
comm_f2.write("b\nc\nd\n")
comm_f2.flush

check("comm default",
      "a\n\t\tb\n\t\tc\n\td\n",
      `ruby #{TOOLS_DIR}/comm.rb #{comm_f1.path} #{comm_f2.path} 2>/dev/null`)

check("comm -12 common only",
      "b\nc\n",
      `ruby #{TOOLS_DIR}/comm.rb -12 #{comm_f1.path} #{comm_f2.path} 2>/dev/null`)

check("comm -3 no common",
      "a\n\td\n",
      `ruby #{TOOLS_DIR}/comm.rb -3 #{comm_f1.path} #{comm_f2.path} 2>/dev/null`)

comm_f1.close; comm_f1.unlink
comm_f2.close; comm_f2.unlink

# ──────────────────────────────────────────────────────────────────
# strings
# ──────────────────────────────────────────────────────────────────
check("strings basic",
      "hello\n",
      run_printf("strings", "\\x01\\x02hello\\x03\\x04"))

check("strings -n min length",
      "abcde\n",
      run_printf("strings", "abc\\x01abcde\\x02", "-n 5"))

# ──────────────────────────────────────────────────────────────────
# expand / unexpand
# ──────────────────────────────────────────────────────────────────
check("expand default tab=8",
      "a       b\n",
      run_printf("expand", "a\\tb\\n"))

check("expand -t4",
      "a   b\n",
      run_printf("expand", "a\\tb\\n", "-t 4"))

check("expand -t4 two tabs",
      "a   b   c\n",
      run_printf("expand", "a\\tb\\tc\\n", "-t 4"))

check("unexpand default",
      "\ta\n",
      run_printf("unexpand", "        a\\n"))

check("unexpand -a spaces mid-line",
      "\ta\tb\n",
      run_printf("unexpand", "        a       b\\n", "-a"))

# ──────────────────────────────────────────────────────────────────
# printf (the tool, not Ruby's)
# ──────────────────────────────────────────────────────────────────
check("printf %d",
      "42\n",
      `ruby #{TOOLS_DIR}/printf.rb '%d\n' 42 2>/dev/null`)

check("printf %s",
      "hello world\n",
      `ruby #{TOOLS_DIR}/printf.rb '%s %s\n' hello world 2>/dev/null`)

check("printf %f",
      "3.140000\n",
      `ruby #{TOOLS_DIR}/printf.rb '%f\n' 3.14 2>/dev/null`)

check("printf %x hex",
      "ff\n",
      `ruby #{TOOLS_DIR}/printf.rb '%x\n' 255 2>/dev/null`)

check("printf %o octal",
      "17\n",
      `ruby #{TOOLS_DIR}/printf.rb '%o\n' 15 2>/dev/null`)

check("printf width",
      "  42\n",
      `ruby #{TOOLS_DIR}/printf.rb '%4d\n' 42 2>/dev/null`)

check("printf repeat format",
      "1\n2\n3\n",
      `ruby #{TOOLS_DIR}/printf.rb '%d\n' 1 2 3 2>/dev/null`)

# ──────────────────────────────────────────────────────────────────
# shuf
# ──────────────────────────────────────────────────────────────────
shuf_out = run_printf("shuf", "a\\nb\\nc\\nd\\n")
shuf_lines = shuf_out.lines.map { |l| l.chomp }.sort
check("shuf outputs same lines sorted",
      ["a", "b", "c", "d"],
      shuf_lines)

check("shuf -n limits output",
      2,
      run_printf("shuf", "a\\nb\\nc\\nd\\n", "-n 2").lines.length)

check("shuf -e treats args as lines",
      3,
      `ruby #{TOOLS_DIR}/shuf.rb -e x y z 2>/dev/null`.lines.length)

# ──────────────────────────────────────────────────────────────────
# fmt
# ──────────────────────────────────────────────────────────────────
check("fmt wraps at 75",
      true,
      run_printf("fmt", "the quick brown fox jumped over the lazy dog the quick brown fox\\n").lines.all? { |l| l.chomp.length <= 75 })

check("fmt -w wraps at width",
      "hello\nworld\n",
      run_printf("fmt", "hello world\\n", "-w 6"))

check("fmt preserves blank lines",
      true,
      run_printf("fmt", "a\\n\\nb\\n").include?("\n\n"))

# ──────────────────────────────────────────────────────────────────
# join
# ──────────────────────────────────────────────────────────────────
join_f1 = Tempfile.new("join1")
join_f1.write("1 a\n2 b\n3 c\n")
join_f1.flush

join_f2 = Tempfile.new("join2")
join_f2.write("1 x\n2 y\n4 z\n")
join_f2.flush

check("join default",
      "1 a x\n2 b y\n",
      `ruby #{TOOLS_DIR}/join.rb #{join_f1.path} #{join_f2.path} 2>/dev/null`)

check("join -a1 unpaired from file1",
      "1 a x\n2 b y\n3 c\n",
      `ruby #{TOOLS_DIR}/join.rb -a 1 #{join_f1.path} #{join_f2.path} 2>/dev/null`)

join_f1.close; join_f1.unlink
join_f2.close; join_f2.unlink

# ──────────────────────────────────────────────────────────────────
# od
# ──────────────────────────────────────────────────────────────────
check("od -c character dump",
      true,
      run_printf("od", "ABC\\n", "-c").include?("A"))

check("od default octal",
      true,
      run_printf("od", "\\x01\\x02", "").length > 0)

check("od -A x hex addresses",
      true,
      run_printf("od", "ABC\\n", "-A x -t x1").start_with?("0"))

# ──────────────────────────────────────────────────────────────────
# hexdump
# ──────────────────────────────────────────────────────────────────
check("hexdump -C canonical",
      true,
      run_printf("hexdump", "Hello\\n", "-C").include?("|Hello."))

check("hexdump default hex",
      true,
      run_printf("hexdump", "\\x01\\x02", "").length > 0)

# ──────────────────────────────────────────────────────────────────
# touch / stat
# ──────────────────────────────────────────────────────────────────
touch_f = Tempfile.new("touch_test")
touch_path = touch_f.path
touch_f.close; touch_f.unlink  # remove so touch creates it fresh

`ruby #{TOOLS_DIR}/touch.rb #{touch_path} 2>/dev/null`
check("touch creates file",
      true,
      File.exist?(touch_path))

File.unlink(touch_path) if File.exist?(touch_path)

# stat basic
stat_tf = Tempfile.new("stat_test")
stat_tf.write("hello\n")
stat_tf.flush
stat_out = `ruby #{TOOLS_DIR}/stat.rb #{stat_tf.path} 2>/dev/null`
check("stat shows file name",
      true,
      stat_out.include?(File.basename(stat_tf.path)))
check("stat shows size",
      true,
      stat_out.include?("6"))
stat_tf.close; stat_tf.unlink

# ──────────────────────────────────────────────────────────────────
# mkdir / rmdir
# ──────────────────────────────────────────────────────────────────
require "tmpdir"
test_base = Dir.tmpdir + "/nix_utils_test_" + rand(999999).to_s

`ruby #{TOOLS_DIR}/mkdir.rb #{test_base} 2>/dev/null`
check("mkdir creates directory",
      true,
      File.directory?(test_base))

`ruby #{TOOLS_DIR}/mkdir.rb -p #{test_base}/a/b/c 2>/dev/null`
check("mkdir -p creates nested",
      true,
      File.directory?(test_base + "/a/b/c"))

`ruby #{TOOLS_DIR}/rmdir.rb #{test_base}/a/b/c 2>/dev/null`
check("rmdir removes empty dir",
      false,
      File.directory?(test_base + "/a/b/c"))

# cleanup
`rm -rf #{test_base} 2>/dev/null`

# ──────────────────────────────────────────────────────────────────
# cp / mv / rm
# ──────────────────────────────────────────────────────────────────
cp_src = Tempfile.new("cp_src")
cp_src.write("copy me\n")
cp_src.flush
cp_dst = cp_src.path + ".dst"

`ruby #{TOOLS_DIR}/cp.rb #{cp_src.path} #{cp_dst} 2>/dev/null`
check("cp copies file",
      "copy me\n",
      File.exist?(cp_dst) ? File.read(cp_dst) : "")

`ruby #{TOOLS_DIR}/rm.rb #{cp_dst} 2>/dev/null`
check("rm removes file",
      false,
      File.exist?(cp_dst))

mv_src = Tempfile.new("mv_src")
mv_src.write("move me\n")
mv_src.flush
mv_dst = mv_src.path + ".dst"
mv_src_path = mv_src.path
mv_src.close

`ruby #{TOOLS_DIR}/mv.rb #{mv_src_path} #{mv_dst} 2>/dev/null`
check("mv moves file",
      "move me\n",
      File.exist?(mv_dst) ? File.read(mv_dst) : "")
check("mv removes source",
      false,
      File.exist?(mv_src_path))

File.unlink(mv_dst) if File.exist?(mv_dst)
cp_src.close; cp_src.unlink

# ──────────────────────────────────────────────────────────────────
# ln
# ──────────────────────────────────────────────────────────────────
ln_target = Tempfile.new("ln_target")
ln_target.write("link content\n")
ln_target.flush
ln_link = ln_target.path + ".symlink"

`ruby #{TOOLS_DIR}/ln.rb -s #{ln_target.path} #{ln_link} 2>/dev/null`
check("ln -s creates symlink",
      true,
      File.symlink?(ln_link))
check("ln -s target readable",
      "link content\n",
      File.symlink?(ln_link) ? File.read(ln_link) : "")

File.unlink(ln_link) if File.symlink?(ln_link)

ln_hard_dst = ln_target.path + ".hard"
`ruby #{TOOLS_DIR}/ln.rb #{ln_target.path} #{ln_hard_dst} 2>/dev/null`
check("ln hard link creates file",
      true,
      File.exist?(ln_hard_dst))
check("ln hard link same content",
      "link content\n",
      File.exist?(ln_hard_dst) ? File.read(ln_hard_dst) : "")

File.unlink(ln_hard_dst) if File.exist?(ln_hard_dst)
ln_target.close; ln_target.unlink

# ──────────────────────────────────────────────────────────────────
# ls
# ──────────────────────────────────────────────────────────────────
ls_dir = Dir.tmpdir + "/ls_test_" + rand(999999).to_s
Dir.mkdir(ls_dir)
File.write(ls_dir + "/alpha.txt", "a")
File.write(ls_dir + "/beta.txt", "bb")

ls_out = `ruby #{TOOLS_DIR}/ls.rb #{ls_dir} 2>/dev/null`
check("ls lists files",
      true,
      ls_out.include?("alpha.txt") && ls_out.include?("beta.txt"))

ls_l_out = `ruby #{TOOLS_DIR}/ls.rb -l #{ls_dir} 2>/dev/null`
check("ls -l shows permissions",
      true,
      ls_l_out.include?("-rw"))
check("ls -l shows sizes",
      true,
      ls_l_out.include?("1") && ls_l_out.include?("2"))

check("ls -1 one per line",
      2,
      `ruby #{TOOLS_DIR}/ls.rb -1 #{ls_dir} 2>/dev/null`.lines.length)

`rm -rf #{ls_dir} 2>/dev/null`

# ──────────────────────────────────────────────────────────────────
# whoami
# ──────────────────────────────────────────────────────────────────
whoami_out = `ruby #{TOOLS_DIR}/whoami.rb 2>/dev/null`.chomp
check("whoami returns non-empty username",
      true,
      whoami_out.length > 0)

# ──────────────────────────────────────────────────────────────────
# hostname
# ──────────────────────────────────────────────────────────────────
hostname_out = `ruby #{TOOLS_DIR}/hostname.rb 2>/dev/null`.chomp
check("hostname returns non-empty",
      true,
      hostname_out.length > 0)

# ──────────────────────────────────────────────────────────────────
# uname
# ──────────────────────────────────────────────────────────────────
check("uname default prints kernel name",
      true,
      `ruby #{TOOLS_DIR}/uname.rb 2>/dev/null`.chomp.length > 0)

check("uname -a all info",
      true,
      `ruby #{TOOLS_DIR}/uname.rb -a 2>/dev/null`.split(" ").length >= 3)

# ──────────────────────────────────────────────────────────────────
# env
# ──────────────────────────────────────────────────────────────────
env_out = `ruby #{TOOLS_DIR}/env.rb 2>/dev/null`
check("env lists variables",
      true,
      env_out.include?("="))

env_i_out = `ruby #{TOOLS_DIR}/env.rb -i FOO=bar 2>/dev/null`
check("env -i with var",
      "FOO=bar\n",
      env_i_out)

# ──────────────────────────────────────────────────────────────────
# readlink
# ──────────────────────────────────────────────────────────────────
rl_target = Tempfile.new("rl_target")
rl_target.write("target\n")
rl_target.flush
rl_link = rl_target.path + ".link"
File.symlink(rl_target.path, rl_link)

check("readlink prints target",
      rl_target.path + "\n",
      `ruby #{TOOLS_DIR}/readlink.rb #{rl_link} 2>/dev/null`)

File.unlink(rl_link)
rl_target.close; rl_target.unlink

# ──────────────────────────────────────────────────────────────────
# id
# ──────────────────────────────────────────────────────────────────
id_out = `ruby #{TOOLS_DIR}/id.rb 2>/dev/null`
check("id default contains uid=",
      true,
      id_out.include?("uid="))

check("id -u prints numeric uid",
      Process.uid.to_s + "\n",
      `ruby #{TOOLS_DIR}/id.rb -u 2>/dev/null`)

# ──────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────
if $failures == 0
  puts "All tests passed."
else
  puts "#{$failures} test(s) FAILED."
  exit 1
end
