# sed.rb, stream editor (GNU sed, Spinel port).
#
# Flags:
#   -n, --quiet, --silent       suppress auto-print
#   -e SCRIPT, --expression=SCRIPT
#   -f FILE, --file=FILE
#   -i[SUFFIX], --in-place[=SUFFIX]
#   -E, -r, --regexp-extended   ERE
#   -s, --separate              treat files as separate streams
#   -u, --unbuffered            flush after each line (no-op here)
#   --posix, --sandbox
#   --help, --version
#
# Compile: spinel nix_utils/sed.rb -o nix_utils/bin/sed

USAGE = "Usage: sed [OPTION]... {script-only-if-no-other-script} [input-file]...\n" \
        "  -n, --quiet      suppress automatic printing\n" \
        "  -e script        add the script to the commands\n" \
        "  -f file          add contents of file to commands\n" \
        "  -i[SUFFIX]       edit files in-place (optional backup SUFFIX)\n" \
        "  -E, -r           use extended regular expressions\n" \
        "  -s               consider files separately rather than as a single stream\n" \
        "  --sandbox        disable file-writing and shell commands\n" \
        "  --help    --version\n" \
        "  -z/--null-data unsupported (NUL bytes not possible in this build)"

VERSION = "sed (nix_utils) 1.0"

require_relative "nix_helpers"

quiet        = false
extended_re  = false
separate     = false
sandbox      = false
scripts      = []
files        = []
in_place     = false
in_place_sfx = nil
options_done = false

# Capture mode: nil = write to stdout, array = collect lines for in-place write.
# $stdout redirection is not supported in Spinel; this global is used instead.
$sed_cap = nil

def sed_puts(s)
  if $sed_cap.nil?
    puts "" + s
  else
    $sed_cap.push("" + s)
  end
end

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done
    files.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-n" || arg == "--quiet" || arg == "--silent"
    quiet = true
  elsif arg == "-E" || arg == "-r" || arg == "--regexp-extended"
    extended_re = true
  elsif arg == "-s" || arg == "--separate"
    separate = true
  elsif arg == "-u" || arg == "--unbuffered"
    # no-op
  elsif arg == "--posix"
    # no-op
  elsif arg == "--sandbox"
    sandbox = true
  elsif arg == "-z" || arg == "--null-data"
    die("sed: -z/--null-data is unsupported in this build (NUL bytes not possible in Spinel C strings)")
  elsif arg == "-e" || arg == "--expression"
    index += 1; scripts.push(coerce(ARGV[index]))
  elsif arg.length > 13 && arg[0, 13] == "--expression="
    scripts.push(arg[13, arg.length - 13])
  elsif arg.length > 2 && arg[0, 2] == "-e"
    scripts.push(arg[2, arg.length - 2])
  elsif arg == "-f" || arg == "--file"
    index += 1; scripts.push(File.read(coerce(ARGV[index])))
  elsif arg.length > 8 && arg[0, 8] == "--file="
    scripts.push(File.read(arg[8, arg.length - 8]))
  elsif arg.length > 2 && arg[0, 2] == "-f"
    scripts.push(File.read(arg[2, arg.length - 2]))
  elsif arg == "-i"
    in_place = true; in_place_sfx = nil
  elsif arg.length > 2 && arg[0, 2] == "-i"
    in_place = true; in_place_sfx = arg[2, arg.length - 2]
  elsif arg.length > 10 && arg[0, 10] == "--in-place"
    in_place = true
    in_place_sfx = arg.length > 11 ? arg[11, arg.length - 11] : nil
  elsif arg[0] != "-"
    if scripts.empty?
      scripts.push(arg)
    else
      files.push(arg)
    end
  else
    die("sed: invalid option -- '#{arg}'\nTry 'sed --help' for more information.")
  end
  index += 1
end

if scripts.empty?
  die("sed: no script command!")
end

script_text = scripts.join("\n")

# ── SedCommand ────────────────────────────────────────────────────────────────

class SedAddr
  attr_accessor :kind, :val, :re_str, :step, :step_from
  def initialize(kind, val = nil)
    @kind      = kind   # :line, :last, :regex, :step
    @val       = val
    @re_str    = nil
    @step      = nil
    @step_from = nil
  end
end

class SedCommand
  attr_accessor :addr1, :addr2, :addr2_plus, :addr2_mod, :negated
  attr_accessor :cmd, :arg1, :arg2, :arg3, :arg_flags
  attr_accessor :sub_cmds
  def initialize(cmd)
    @addr1      = nil
    @addr2      = nil
    @addr2_plus = nil  # for addr1,+N
    @addr2_mod  = nil  # for addr1,~N
    @negated    = false
    @cmd        = cmd
    @arg1       = nil
    @arg2       = nil
    @arg3       = nil
    @arg_flags  = nil
    @sub_cmds   = nil
  end
end

# ── Parser ────────────────────────────────────────────────────────────────────

class SedParser
  def initialize(script, extended_re)
    @src  = "" + script
    @pos  = 0
    @ere  = extended_re
    @cmds = []
  end

  def parse
    skip_ws_and_semi
    until @pos >= @src.length
      cmd = parse_command
      @cmds.push(cmd) unless cmd.nil?
      skip_ws_and_semi
    end
    @cmds
  end

  private

  def skip_ws_and_semi
    while @pos < @src.length
      c = @src[@pos]
      if c == " " || c == "\t" || c == "\n" || c == "\r" || c == ";"
        @pos += 1
      elsif c == "#"
        while @pos < @src.length && @src[@pos] != "\n"
          @pos += 1
        end
      else
        break
      end
    end
  end

  def current
    @pos < @src.length ? @src[@pos] : nil
  end

  def advance
    c = @src[@pos]
    @pos += 1
    c
  end

  def parse_addr
    return nil if @pos >= @src.length
    c = current
    if c == "$"
      advance
      return SedAddr.new(:last)
    elsif c == "/" || c == "\\"
      if c == "\\"
        advance
        delim = advance
      else
        delim = "/"
        advance
      end
      re_str = read_until_delim(delim)
      addr = SedAddr.new(:regex)
      addr.re_str = re_str
      return addr
    elsif "0123456789".include?(c)
      n_str = ""
      while @pos < @src.length && "0123456789".include?(@src[@pos])
        n_str += @src[@pos]
        @pos += 1
      end
      n = n_str.to_i
      # Check for first~step
      if current == "~"
        advance
        step_str = ""
        while @pos < @src.length && "0123456789".include?(@src[@pos])
          step_str += @src[@pos]
          @pos += 1
        end
        addr = SedAddr.new(:step)
        addr.step_from = n
        addr.step = step_str.to_i
        return addr
      end
      return SedAddr.new(:line, n)
    end
    nil
  end

  def read_until_delim(delim)
    result = ""
    while @pos < @src.length
      c = @src[@pos]
      if c == "\\"
        @pos += 1
        if @pos < @src.length
          nc = @src[@pos]
          result += (nc == delim) ? delim : "\\" + nc
          @pos += 1
        end
      elsif c == delim
        @pos += 1
        break
      else
        result += c
        @pos += 1
      end
    end
    result
  end

  def read_to_eol
    result = ""
    while @pos < @src.length && @src[@pos] != "\n"
      result += @src[@pos]
      @pos += 1
    end
    result.strip
  end

  def read_text_arg
    # For a/i/c: text is rest of line; backslash-newline continues
    # skip optional leading backslash-newline
    @pos += 1 if current == "\\"
    @pos += 1 if current == "\n"
    result = ""
    loop do
      while @pos < @src.length && @src[@pos] != "\n"
        result += @src[@pos]
        @pos += 1
      end
      @pos += 1 if @pos < @src.length  # consume newline
      if result.end_with?("\\")
        result = result[0, result.length - 1] + "\n"
      else
        break
      end
    end
    result
  end

  def parse_command
    addr1 = parse_addr
    addr2 = nil
    addr2_plus = nil
    addr2_mod  = nil
    if !addr1.nil? && current == ","
      advance
      if current == "+"
        advance
        n_str = ""
        while @pos < @src.length && "0123456789".include?(@src[@pos])
          n_str += @src[@pos]; @pos += 1
        end
        addr2_plus = n_str.to_i
      elsif current == "~"
        advance
        n_str = ""
        while @pos < @src.length && "0123456789".include?(@src[@pos])
          n_str += @src[@pos]; @pos += 1
        end
        addr2_mod = n_str.to_i
      else
        addr2 = parse_addr
      end
    end

    skip_ws_and_semi if addr1.nil? && addr2.nil?
    return nil if current.nil?

    negated = false
    if current == "!"
      negated = true
      advance
    end
    skip_ws_and_semi

    return nil if current.nil?

    cmd_char = advance
    sc = SedCommand.new(cmd_char)
    sc.addr1      = addr1
    sc.addr2      = addr2
    sc.addr2_plus = addr2_plus
    sc.addr2_mod  = addr2_mod
    sc.negated    = negated

    case cmd_char
    when "s"
      delim = advance
      pattern = read_until_delim(delim)
      replace = read_until_delim(delim)
      flags   = ""
      while @pos < @src.length && !";\n}".include?(@src[@pos])
        flags += @src[@pos]; @pos += 1
      end
      sc.arg1 = pattern
      sc.arg2 = replace
      sc.arg_flags = flags
    when "y"
      delim   = advance
      src_str = read_until_delim(delim)
      dst_str = read_until_delim(delim)
      sc.arg1 = src_str
      sc.arg2 = dst_str
    when "a", "i", "c"
      # Skip whitespace; text can be on same line after backslash
      @pos += 1 if current == " " || current == "\t"
      sc.arg1 = read_text_arg
    when "q", "Q"
      skip_ws_and_semi
      n_str = ""
      while @pos < @src.length && "0123456789".include?(@src[@pos])
        n_str += @src[@pos]; @pos += 1
      end
      sc.arg1 = n_str == "" ? 0 : n_str.to_i
    when "l"
      skip_ws_and_semi
      n_str = ""
      while @pos < @src.length && "0123456789".include?(@src[@pos])
        n_str += @src[@pos]; @pos += 1
      end
      sc.arg1 = n_str == "" ? 70 : n_str.to_i
    when "r", "w", "R", "W"
      @pos += 1 if current == " "
      sc.arg1 = read_to_eol
    when "b", "t", "T"
      skip_ws_and_semi
      lbl = ""
      while @pos < @src.length && !";\n} \t".include?(@src[@pos])
        lbl += @src[@pos]; @pos += 1
      end
      sc.arg1 = lbl
    when ":"
      skip_ws_and_semi
      lbl = ""
      while @pos < @src.length && !";\n} \t".include?(@src[@pos])
        lbl += @src[@pos]; @pos += 1
      end
      sc.arg1 = lbl
    when "{"
      sub = []
      skip_ws_and_semi
      while @pos < @src.length && current != "}"
        c = parse_command
        sub.push(c) unless c.nil?
        skip_ws_and_semi
      end
      advance if current == "}"  # consume "}"
      sc.sub_cmds = sub
    end

    sc
  end
end

cmds = SedParser.new(script_text, extended_re).parse

# Build label index
label_idx = {}
ci = 0
while ci < cmds.length
  c = cmds[ci]
  label_idx["" + c.arg1.to_s] = ci if !c.nil? && ("" + c.cmd) == ":"
  ci += 1
end

# ── Executor ──────────────────────────────────────────────────────────────────

class SedState
  attr_accessor :pattern, :hold, :line_num, :sub_since_last, :last_line, :output_buf
  def initialize
    @pattern        = ""
    @hold           = ""
    @line_num       = 0
    @sub_since_last = false
    @last_line      = false
    @output_buf     = [""]
  end
end

def addr_matches?(addr, state)
  return true if addr.nil?
  k = "" + addr.kind.to_s
  if k == "line"
    return state.line_num == addr.val.to_i
  elsif k == "last"
    return state.last_line
  elsif k == "regex"
    re_s = "" + addr.re_str.to_s
    return re_s != "" && !Regexp.new(re_s).match("" + state.pattern).nil?
  elsif k == "step"
    from = addr.step_from.to_i
    step = addr.step.to_i
    n    = state.line_num
    return false if n < from
    return step == 0 ? n == from : (n - from) % step == 0
  end
  false
end

def in_range?(cmd, state, active_ranges)
  cmd_id = cmd.object_id
  if cmd.addr2.nil? && cmd.addr2_plus.nil? && cmd.addr2_mod.nil?
    return addr_matches?(cmd.addr1, state)
  end
  key = cmd_id.to_s
  currently_active = active_ranges[key] || false
  if currently_active
    ends =
      if !cmd.addr2_plus.nil?
        !active_ranges[key + "_start"].nil? && state.line_num >= active_ranges[key + "_start"].to_i + cmd.addr2_plus.to_i
      elsif !cmd.addr2_mod.nil?
        state.line_num % cmd.addr2_mod.to_i == 0
      else
        addr_matches?(cmd.addr2, state)
      end
    if ends
      active_ranges[key] = false
    end
    return true
  else
    if addr_matches?(cmd.addr1, state)
      active_ranges[key] = true
      active_ranges[key + "_start"] = state.line_num
      return true
    end
    return false
  end
end

# Build replacement string for sed s command.
# Takes a MatchData object directly (def functions can receive MatchData; lambdas cannot).
def apply_repl_with_match(repl_str, m)
  r   = "" + repl_str
  out = ""
  ri  = 0
  while ri < r.length
    rc = r[ri]
    if rc == "\\" && ri + 1 < r.length
      nc = r[ri + 1]
      if "123456789".include?(nc)
        cap_idx = nc.to_i
        cap = m[cap_idx]
        out += cap.nil? ? "" : ("" + cap.to_s)
        ri += 2
        next
      elsif nc == "&"
        out += "" + m[0].to_s
        ri += 2
        next
      elsif nc == "\\"
        out += "\\"
        ri += 2
        next
      else
        out += nc
        ri += 2
        next
      end
    elsif rc == "&"
      out += "" + m[0].to_s
    else
      out += rc
    end
    ri += 1
  end
  out
end

def exec_cmd(cmd, state, cmds_list, label_idx, quiet, sandbox, active_ranges)
  return [:next_cmd, 0] if cmd.nil?
  matched =
    if cmd.addr1.nil?
      true
    else
      in_range?(cmd, state, active_ranges)
    end
  matched = !matched if cmd.negated

  return [:next_cmd, 0] unless matched

  c = "" + cmd.cmd
  case c
  when "d"
    return [:delete, 0]
  when "p"
    state.output_buf.push("" + state.pattern)
  when "P"
    ps = "" + state.pattern
    nl = ps.index("\n")
    state.output_buf.push(nl.nil? ? ps : ps[0, nl])
  when "="
    state.output_buf.push(state.line_num.to_s)
  when "q"
    return [:quit, cmd.arg1.to_i]
  when "Q"
    return [:quit_no_print, cmd.arg1.to_i]
  when "n"
    return [:next_line, 0]
  when "N"
    return [:append_next, 0]
  when "a"
    return [:append_text, ("" + cmd.arg1.to_s)]
  when "i"
    state.output_buf.push("" + cmd.arg1.to_s)
  when "c"
    return [:change_text, ("" + cmd.arg1.to_s)]
  when "h"
    state.hold = "" + state.pattern
  when "H"
    state.hold = ("" + state.hold) + "\n" + ("" + state.pattern)
  when "g"
    state.pattern = "" + state.hold
  when "G"
    state.pattern = ("" + state.pattern) + "\n" + ("" + state.hold)
  when "x"
    tmp = "" + state.hold
    state.hold    = "" + state.pattern
    state.pattern = tmp
  when "y"
    src_chars = ("" + cmd.arg1.to_s).chars
    dst_chars = ("" + cmd.arg2.to_s).chars
    ps = "" + state.pattern
    result = ""
    i = 0
    while i < ps.length
      ch  = ps[i]
      idx = src_chars.index(ch)
      result += idx.nil? ? ch : ("" + dst_chars[idx].to_s)
      i += 1
    end
    state.pattern = result
  when "s"
    pat    = "" + cmd.arg1.to_s
    flags  = "" + cmd.arg_flags.to_s
    re_f   = (flags.include?("i") || flags.include?("I")) ? Regexp::IGNORECASE : 0
    re     = Regexp.new(pat, re_f)
    repl   = "" + cmd.arg2.to_s
    ps     = "" + state.pattern
    global = flags.include?("g")
    nth    = nil
    fi = 0
    while fi < flags.length
      fc = flags[fi]
      if "0123456789".include?(fc)
        n_str = fc
        fi2 = fi + 1
        while fi2 < flags.length && "0123456789".include?(flags[fi2])
          n_str += flags[fi2]; fi2 += 1
        end
        nth = n_str.to_i
        fi = fi2
        next
      end
      fi += 1
    end
    new_str = "" + ps
    if global
      # Manual global replace using re.match() loop (String#gsub(re){} not available in Spinel)
      result = ""
      remaining = "" + ps
      sub_happened = false
      while true
        m = re.match(remaining)
        break if m.nil?
        result += remaining[0, m.begin(0)]
        result += apply_repl_with_match(repl, m)
        sub_happened = true
        adv = m.end(0)
        if adv <= m.begin(0)
          result += remaining.length > adv ? remaining[adv, 1] : ""
          adv += 1
        end
        remaining = adv < remaining.length ? remaining[adv, remaining.length - adv] : ""
      end
      result += remaining
      new_str = result
      state.sub_since_last = sub_happened
    elsif !nth.nil?
      # Find and replace the nth occurrence using re.match() loop
      count     = 0
      pos       = 0
      found_nth = false
      result    = ""
      while pos <= ps.length
        sub_str = pos < ps.length ? ps[pos, ps.length - pos] : ""
        break if ("" + sub_str.to_s) == ""
        m = re.match(sub_str)
        break if m.nil?
        count += 1
        abs_begin = pos + m.begin(0)
        abs_end   = pos + m.end(0)
        if count == nth
          result = ps[0, abs_begin] + apply_repl_with_match(repl, m) + ps[abs_end, ps.length - abs_end]
          found_nth = true
          break
        end
        pos = abs_end
        pos += 1 if m.begin(0) == m.end(0)
      end
      if found_nth
        new_str = result
        state.sub_since_last = true
      else
        new_str = ps
        state.sub_since_last = false
      end
    else
      # Single substitution using re.match() (String#match(re) not available in Spinel)
      m = re.match(ps)
      if m.nil?
        new_str = ps
        state.sub_since_last = false
      else
        new_str = ps[0, m.begin(0)] + apply_repl_with_match(repl, m) + ps[m.end(0), ps.length - m.end(0)]
        state.sub_since_last = true
      end
    end
    state.pattern = "" + new_str.to_s
    if flags.include?("p") && state.sub_since_last
      state.output_buf.push("" + state.pattern)
    end
  when "l"
    width = cmd.arg1.to_i
    width = 70 if width == 0
    ps = "" + state.pattern
    vis = ""
    i = 0
    while i < ps.length
      ch = ps[i]
      code = ch.ord
      if ch == "\\"
        vis += "\\\\"
      elsif ch == "\a"
        vis += "\\a"
      elsif ch == "\b"
        vis += "\\b"
      elsif ch == "\f"
        vis += "\\f"
      elsif ch == "\r"
        vis += "\\r"
      elsif ch == "\t"
        vis += "\\t"
      elsif code < 32 || code == 127
        hex = code.to_s(16)
        vis += "\\x" + hex.rjust(2, "0")
      else
        vis += ch
      end
      i += 1
    end
    vis += "$"
    # wrap at width
    li = 0
    while li + width < vis.length
      state.output_buf.push(vis[li, width] + "\\")
      li += width
    end
    state.output_buf.push(vis[li, vis.length - li])
  when "b"
    lbl = "" + cmd.arg1.to_s
    if lbl == ""
      return [:end_cycle, 0]
    end
    target = label_idx[lbl]
    return [:branch, target || cmds_list.length]
  when "t"
    if state.sub_since_last
      state.sub_since_last = false
      lbl = "" + cmd.arg1.to_s
      if lbl == ""
        return [:end_cycle, 0]
      end
      target = label_idx[lbl]
      return [:branch, target || cmds_list.length]
    end
  when "T"
    unless state.sub_since_last
      state.sub_since_last = false
      lbl = "" + cmd.arg1.to_s
      if lbl == ""
        return [:end_cycle, 0]
      end
      target = label_idx[lbl]
      return [:branch, target || cmds_list.length]
    end
  when "r"
    path = "" + cmd.arg1.to_s
    return [:append_text, (sandbox ? "" : (File.exist?(path) ? File.read(path) : ""))]
  when "w"
    unless sandbox
      path = "" + cmd.arg1.to_s
      File.open(path, "a") { |f| f.puts("" + state.pattern) } unless path == ""
    end
  when "{"
    sub_cmds = cmd.sub_cmds || []
    si = 0
    while si < sub_cmds.length
      result, val = exec_cmd(sub_cmds[si], state, sub_cmds, label_idx, quiet, sandbox, active_ranges)
      rs = "" + result.to_s
      if rs == "delete" || rs == "quit" || rs == "quit_no_print" ||
         rs == "next_line" || rs == "append_next" || rs == "end_cycle" || rs == "change_text"
        return [result, val]
      elsif rs == "branch"
        return [result, val]
      elsif rs == "append_text"
        # queue the text to output after pattern space
        state.output_buf.push("" + val.to_s)
      end
      si += 1
    end
  end
  [:next_cmd, 0]
end

def process_stream(lines_arr, cmds, label_idx, quiet, sandbox)
  state         = SedState.new
  active_ranges = {}
  total         = lines_arr.length
  after_texts   = []   # texts to print after the current cycle's output

  li = 0
  while li < total
    line = "" + lines_arr[li]
    state.line_num       += 1
    state.pattern         = line
    state.last_line       = (li == total - 1)
    state.sub_since_last  = false
    after_texts           = []

    skip_to_next = false
    do_delete    = false
    quit_code    = nil
    quit_print   = true

    ci = 0
    while ci < cmds.length
      result, val = exec_cmd(cmds[ci], state, cmds, label_idx, quiet, sandbox, active_ranges)
      rs = "" + result.to_s
      if rs == "delete"
        do_delete = true; break
      elsif rs == "quit"
        quit_code = val.to_i; quit_print = true; break
      elsif rs == "quit_no_print"
        quit_code = val.to_i; quit_print = false; break
      elsif rs == "next_line"
        sed_puts("" + state.pattern) unless quiet
        obi = 1; while obi < state.output_buf.length; sed_puts "" + state.output_buf[obi]; obi += 1; end
        state.output_buf = [""]
        li += 1
        break if li >= total
        state.line_num += 1
        state.pattern   = "" + lines_arr[li]
        state.last_line = (li == total - 1)
        state.sub_since_last = false
        ci += 1
        next
      elsif rs == "append_next"
        li += 1
        if li < total
          state.pattern = ("" + state.pattern) + "\n" + ("" + lines_arr[li])
          state.last_line = (li == total - 1)
        end
      elsif rs == "end_cycle"
        break
      elsif rs == "branch"
        ci = val.to_i
        next
      elsif rs == "append_text"
        after_texts.push("" + val.to_s)
      elsif rs == "change_text"
        do_delete = true
        after_texts.push("" + val.to_s)
        break
      end
      ci += 1
    end

    unless do_delete
      obi = 1; while obi < state.output_buf.length; sed_puts "" + state.output_buf[obi]; obi += 1; end
      state.output_buf = [""]
      sed_puts("" + state.pattern) unless quiet
    else
      state.output_buf = [""]
    end
    after_texts.each { |t| sed_puts "" + t.to_s }

    unless quit_code.nil?
      sed_puts("" + state.pattern) if quit_print && !quiet && !do_delete
      exit quit_code.to_i
    end

    li += 1
  end
end

files = ["-"] if files.empty?

if in_place
  files.each do |f|
    cf = "" + f
    die("sed: cannot edit in-place on stdin") if cf == "-"
    content  = File.read(cf)
    lines    = content.split("\n", -1)
    lines.pop if !lines.empty? && ("" + lines.last) == ""
    unless in_place_sfx.nil?
      File.open(cf + ("" + in_place_sfx), "w") { |bakf| bakf.write(content) }
    end
    $sed_cap = [""]
    process_stream(lines, cmds, label_idx, quiet, sandbox)
    cap = $sed_cap
    $sed_cap = nil
    out_str = ""
    ci2 = 1
    while ci2 < cap.length
      out_str += cap[ci2] + "\n"
      ci2 += 1
    end
    File.open(cf, "w") { |outf| outf.write(out_str) }
  end
else
  if separate
    files.each do |f|
      cf      = "" + f
      content = (cf == "-") ? STDIN.read : File.read(cf)
      lines   = content.split("\n", -1)
      lines.pop if !lines.empty? && ("" + lines.last) == ""
      process_stream(lines, cmds, label_idx, quiet, sandbox)
    end
  else
    all_lines = []
    files.each do |f|
      cf      = "" + f
      content = (cf == "-") ? STDIN.read : File.read(cf)
      content.split("\n", -1).each { |l| all_lines.push("" + l) }
    end
    all_lines.pop if !all_lines.empty? && ("" + all_lines.last) == ""
    process_stream(all_lines, cmds, label_idx, quiet, sandbox)
  end
end
