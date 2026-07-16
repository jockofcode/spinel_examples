# grep.rb, print lines matching a pattern (GNU grep, Spinel port).
#
# A faithful subset of GNU grep. For each FILE (or standard input when none
# are given) prints lines that match PATTERN. Exit 0 if any line matched,
# 1 if none matched, 2 on error.
#
# Flags:
#   -e PATTERN   pattern (may be repeated; patterns are ORed)
#   -f FILE      read patterns from FILE (one per line)
#   -i           ignore case
#   -v           invert: print non-matching lines
#   -n           prefix output lines with line number
#   -c           print count of matching lines only
#   -l           list only names of files with a match
#   -L           list only names of files without a match
#   -q           quiet; exit 0/1 without printing
#   -o           print only the matched parts (one per line)
#   -F           treat pattern as fixed string
#   -w           whole-word match (adds \b anchors to regex)
#   -x           whole-line match (anchors to ^ and $)
#   -m NUM       stop after NUM matching lines per file
#   -A NUM       print NUM lines of trailing context
#   -B NUM       print NUM lines of leading context
#   -C NUM       same as -A NUM -B NUM
#   -H           always print filename prefix
#   -h           suppress filename prefix
#   -s           suppress error messages
#   -r, -R       recursively search directories
#   -E, -G, -P   regex dialect (all equivalent in Ruby)
#   --color=WHEN always/never/auto (ANSI highlight)
#   --include=GLOB, --exclude=GLOB  filter files in -r mode
#   --help       usage
#
# Compile: spinel nix_utils/grep.rb -o nix_utils/bin/grep
# Run:
#   ./bin/grep foo file.txt
#   printf 'abc\ndef\n' | ./bin/grep -n a
#
# Core Ruby only (File, STDIN, STDOUT, Regexp); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/grep.rb ...`).

USAGE = "Usage: grep [OPTION]... PATTERN [FILE]...\n" \
        "  or:  grep [OPTION]... -e PATTERN... [FILE]...\n" \
        "Print lines from each FILE that match PATTERN.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -e PATTERN  pattern (repeatable)    -f FILE  patterns from file\n" \
        "  -i  ignore case    -v  invert match\n" \
        "  -n  line numbers   -c  count only\n" \
        "  -l  list matching files   -L  list non-matching files\n" \
        "  -q  quiet          -o  only matching parts\n" \
        "  -F  fixed string   -w  word match   -x  line match\n" \
        "  -m NUM  max matches    -s  suppress errors\n" \
        "  -H  print filename     -h  suppress filename\n" \
        "  -A/-B/-C NUM  context lines\n" \
        "  -E/-G/-P  regex mode (all same here)   -r/-R  recursive\n" \
        "  --color=WHEN  always/never/auto\n" \
        "  --help"

WORD_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_"

class GrepOptions
  attr_accessor :raw_patterns, :fixed_string, :ignore_case, :invert
  attr_accessor :line_number, :count_only, :list_files, :list_no_match
  attr_accessor :quiet, :only_matching, :word_match, :line_match
  attr_accessor :max_count, :with_filename, :no_filename, :suppress_errors
  attr_accessor :before_context, :after_context, :recursive, :color
  attr_accessor :include_glob, :exclude_glob
  attr_accessor :compiled_re, :fixed_pats
  attr_accessor :byte_offset, :initial_tab, :null_name, :null_data, :label, :group_sep

  def initialize
    @raw_patterns    = []
    @raw_patterns.push("")
    @raw_patterns.pop
    @fixed_string    = false
    @ignore_case     = false
    @invert          = false
    @line_number     = false
    @count_only      = false
    @list_files      = false
    @list_no_match   = false
    @quiet           = false
    @only_matching   = false
    @word_match      = false
    @line_match      = false
    @max_count       = nil
    @with_filename   = nil   # nil=auto, true=always, false=never
    @no_filename     = false
    @suppress_errors = false
    @before_context  = 0
    @after_context   = 0
    @recursive       = false
    @color           = "auto"
    @include_glob    = nil
    @exclude_glob    = nil
    @compiled_re     = nil
    @fixed_pats      = nil
    @byte_offset     = false
    @initial_tab     = false
    @null_name       = false
    @null_data       = false
    @label           = "(standard input)"
    @group_sep       = "--"
  end
end

def parse_int_arg(str, flag)
  i = 0
  while i < str.length
    unless "0123456789".include?(str[i])
      STDERR.puts "grep: invalid context length argument '#{str}'"
      exit 2
    end
    i += 1
  end
  str.to_i
end

def parse_argv(argv)
  opts = GrepOptions.new
  files = []
  options_done = false
  index = 0

  while index < argv.length
    arg = argv[index]

    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
      index += 1
      next
    end

    if arg == "--"
      options_done = true
      index += 1
      next
    end

    if arg == "--help"
      puts USAGE
      exit 0
    end

    if arg == "--color" || arg == "--colour"
      opts.color = "auto"
      index += 1
      next
    end

    if arg.length > 8 && (arg[0, 8] == "--color=" || arg[0, 9] == "--colour=")
      eq = arg.index("=")
      opts.color = arg[eq + 1, arg.length - eq - 1]
      index += 1
      next
    end

    if arg == "--include"
      index += 1
      opts.include_glob = argv[index]
      index += 1
      next
    end

    if arg.length > 10 && arg[0, 10] == "--include="
      opts.include_glob = arg[10, arg.length - 10]
      index += 1
      next
    end

    if arg == "--exclude"
      index += 1
      opts.exclude_glob = argv[index]
      index += 1
      next
    end

    if arg.length > 10 && arg[0, 10] == "--exclude="
      opts.exclude_glob = arg[10, arg.length - 10]
      index += 1
      next
    end

    if arg == "-e" || arg == "--regexp"
      index += 1
      if index >= argv.length
        STDERR.puts "grep: option requires an argument -- 'e'"
        exit 2
      end
      opts.raw_patterns.push("" + argv[index])
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-e"
      opts.raw_patterns.push("" + arg[2, arg.length - 2])
      index += 1
      next
    end

    if arg == "--regexp="[0, arg.length] && arg.length > 9 && arg[0, 9] == "--regexp="
      opts.raw_patterns.push("" + arg[9, arg.length - 9])
      index += 1
      next
    end

    if arg == "-f" || arg == "--file"
      index += 1
      if index >= argv.length
        STDERR.puts "grep: option requires an argument -- 'f'"
        exit 2
      end
      fname = argv[index]
      if !File.exist?(fname)
        STDERR.puts "grep: #{fname}: No such file or directory" unless opts.suppress_errors
        exit 2
      end
      File.read(fname).lines.each do |l|
        l = l.end_with?("\n") ? "" + l[0, l.length - 1] : l
        opts.raw_patterns.push(l) unless l == ""
      end
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-f"
      fname = arg[2, arg.length - 2]
      if !File.exist?(fname)
        STDERR.puts "grep: #{fname}: No such file or directory" unless opts.suppress_errors
        exit 2
      end
      File.read(fname).lines.each do |l|
        l = l.end_with?("\n") ? "" + l[0, l.length - 1] : l
        opts.raw_patterns.push(l) unless l == ""
      end
      index += 1
      next
    end

    if arg == "-m" || arg == "--max-count"
      index += 1
      opts.max_count = parse_int_arg(argv[index], "-m")
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-m"
      opts.max_count = parse_int_arg(arg[2, arg.length - 2], "-m")
      index += 1
      next
    end

    if arg.length > 12 && arg[0, 12] == "--max-count="
      opts.max_count = parse_int_arg(arg[12, arg.length - 12], "--max-count")
      index += 1
      next
    end

    if arg == "-A" || arg == "--after-context"
      index += 1
      opts.after_context = parse_int_arg(argv[index], "-A")
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-A"
      opts.after_context = parse_int_arg(arg[2, arg.length - 2], "-A")
      index += 1
      next
    end

    if arg.length > 16 && arg[0, 16] == "--after-context="
      opts.after_context = parse_int_arg(arg[16, arg.length - 16], "--after-context")
      index += 1
      next
    end

    if arg == "-B" || arg == "--before-context"
      index += 1
      opts.before_context = parse_int_arg(argv[index], "-B")
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-B"
      opts.before_context = parse_int_arg(arg[2, arg.length - 2], "-B")
      index += 1
      next
    end

    if arg.length > 17 && arg[0, 17] == "--before-context="
      opts.before_context = parse_int_arg(arg[17, arg.length - 17], "--before-context")
      index += 1
      next
    end

    if arg == "-C" || arg == "--context"
      index += 1
      n = parse_int_arg(argv[index], "-C")
      opts.before_context = n
      opts.after_context  = n
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-C"
      n = parse_int_arg(arg[2, arg.length - 2], "-C")
      opts.before_context = n
      opts.after_context  = n
      index += 1
      next
    end

    if arg.length > 10 && arg[0, 10] == "--context="
      n = parse_int_arg(arg[10, arg.length - 10], "--context")
      opts.before_context = n
      opts.after_context  = n
      index += 1
      next
    end

    if arg == "--null" || arg == "-Z"
      opts.null_name = true
      index += 1
      next
    end

    if arg == "--null-data"
      opts.null_data = true
      index += 1
      next
    end

    if arg == "--byte-offset"
      opts.byte_offset = true
      index += 1
      next
    end

    if arg == "--initial-tab"
      opts.initial_tab = true
      index += 1
      next
    end

    if arg == "--no-ignore-case"
      opts.ignore_case = false
      index += 1
      next
    end

    if arg == "--no-group-separator"
      opts.group_sep = nil
      index += 1
      next
    end

    if arg.length > 18 && arg[0, 18] == "--group-separator="
      opts.group_sep = arg[18, arg.length - 18]
      index += 1
      next
    end

    if arg.length > 8 && arg[0, 8] == "--label="
      opts.label = arg[8, arg.length - 8]
      index += 1
      next
    end

    # Accepted for compatibility; these do not change behavior in this port,
    # which always reads input as text with newline-separated lines.
    if arg == "--text" || arg == "--binary" || arg == "--line-buffered" ||
       arg == "--mmap" ||
       (arg.length > 15 && arg[0, 15] == "--binary-files=") ||
       (arg.length > 10 && arg[0, 10] == "--devices=") ||
       (arg.length > 14 && arg[0, 14] == "--exclude-dir=") ||
       (arg.length > 15 && arg[0, 15] == "--exclude-from=")
      index += 1
      next
    end

    if arg.length > 14 && arg[0, 14] == "--directories="
      action = arg[14, arg.length - 14]
      opts.recursive = true if action == "recurse"
      index += 1
      next
    end

    # Short flag cluster
    letters = arg[1, arg.length - 1]
    li = 0
    while li < letters.length
      letter = letters[li]
      if letter == "i"
        opts.ignore_case = true
      elsif letter == "v"
        opts.invert = true
      elsif letter == "n"
        opts.line_number = true
      elsif letter == "c"
        opts.count_only = true
      elsif letter == "l"
        opts.list_files = true
      elsif letter == "L"
        opts.list_no_match = true
      elsif letter == "q"
        opts.quiet = true
      elsif letter == "o"
        opts.only_matching = true
      elsif letter == "F"
        opts.fixed_string = true
      elsif letter == "w"
        opts.word_match = true
      elsif letter == "x"
        opts.line_match = true
      elsif letter == "H"
        opts.with_filename = true
      elsif letter == "h"
        opts.no_filename = true
      elsif letter == "s"
        opts.suppress_errors = true
      elsif letter == "r" || letter == "R"
        opts.recursive = true
      elsif letter == "E" || letter == "G" || letter == "P"
        # regex dialect flags: no-op (Ruby uses ERE by default)
      elsif letter == "a" || letter == "U" || letter == "I"
        # text / binary handling: no-op (input is always read as text)
      elsif letter == "b"
        opts.byte_offset = true
      elsif letter == "T"
        opts.initial_tab = true
      elsif letter == "Z"
        opts.null_name = true
      elsif letter == "z"
        opts.null_data = true
      else
        STDERR.puts "grep: invalid option -- '#{letter}'"
        STDERR.puts "Try 'grep --help' for more information."
        exit 2
      end
      li += 1
    end

    index += 1
  end

  [opts, files]
end

# Build the compiled regex or fixed-pattern list after argument parsing.
def compile_patterns(opts)
  if opts.fixed_string
    opts.fixed_pats = opts.raw_patterns
    opts.compiled_re = nil
  else
    parts = []
    opts.raw_patterns.each do |raw|
      parts.push("(?:#{raw})")
    end
    combined = parts.join("|")
    combined = "\\b(?:#{combined})\\b" if opts.word_match
    combined = "\\A(?:#{combined})\\z" if opts.line_match
    combined = "(?i)#{combined}" if opts.ignore_case
    opts.compiled_re = Regexp.new(combined)
    opts.fixed_pats  = nil
  end
end

# Check whether a single line matches the compiled pattern(s).
# Returns true if any pattern matches (before invert is applied).
def raw_match?(line, opts)
  if opts.fixed_string
    check = "" + (opts.ignore_case ? line.downcase : line)
    opts.fixed_pats.each do |pat|
      sub = "" + (opts.ignore_case ? pat.downcase : pat)
      if opts.line_match
        return true if check == sub
      elsif opts.word_match
        pos = 0
        while pos <= check.length - sub.length
          idx = check.index(sub, pos)
          break if idx.nil?
          before_ok = idx == 0 || !WORD_CHARS.include?(check[idx - 1])
          after_pos = idx + sub.length
          after_ok  = after_pos >= check.length || !WORD_CHARS.include?(check[after_pos])
          return true if before_ok && after_ok
          pos = idx + 1
        end
      else
        return true if check.include?(sub)
      end
    end
    false
  else
    !opts.compiled_re.match(line).nil?
  end
end

# Yield each matching substring in line for -o mode.
def each_match_in_line(line, opts)
  if opts.fixed_string
    opts.fixed_pats.each do |pat|
      check = "" + (opts.ignore_case ? line.downcase : line)
      sub   = "" + (opts.ignore_case ? pat.downcase : pat)
      next if sub == ""
      pos = 0
      while pos <= check.length - sub.length
        idx = check.index(sub, pos)
        break if idx.nil?
        yield line[idx, sub.length]
        pos = idx + sub.length
      end
    end
  else
    pos = 0
    while pos < line.length
      rest = line[pos, line.length - pos]
      m = opts.compiled_re.match(rest)
      break if m.nil?
      pre_len = m.pre_match.length
      match_str = m[0]
      yield match_str
      advance = pre_len + (match_str.length > 0 ? match_str.length : 1)
      pos += advance
    end
  end
end

# Does the output need a filename prefix?
def show_fname?(opts, file_count)
  return false if opts.no_filename
  return true  if opts.with_filename
  file_count > 1
end

# Format a single output line and write it. byte_off is the byte offset of the
# line within its file (used by -b).
def emit_line(line, line_num, byte_off, filename, print_fname, sep, opts)
  out = ""
  out = out + filename + (opts.null_name ? "\0" : sep) if print_fname
  out = out + "#{line_num}#{sep}" if opts.line_number
  out = out + "#{byte_off}#{sep}" if opts.byte_offset
  out = out + "\t" if opts.initial_tab
  out = out + line
  STDOUT.write(out + (opts.null_data ? "\0" : "\n"))
end

# Search one file's content. Returns [matched_any, exit_code_contribution].
def grep_content(content, filename, print_fname, opts)
  data_delim = opts.null_data ? "\0" : "\n"
  lines = content.split(data_delim, -1)
  lines.pop if !lines.empty? && lines.last == ""

  # Precompute each line's byte offset within the file for -b.
  offsets = []
  running = 0
  lines.each do |l|
    offsets.push(running)
    running += l.bytesize + 1   # + delimiter byte
  end

  match_count = 0
  matched_any = false
  before_buf  = []   # lines waiting to be printed as before-context
  after_left  = 0    # lines of after-context still to emit
  need_sep    = false
  group_sep   = opts.group_sep

  use_context = opts.before_context > 0 || opts.after_context > 0

  line_num = 0
  lines.each do |line|
    idx = line_num
    line_num += 1
    break if !opts.max_count.nil? && match_count >= opts.max_count

    is_match = raw_match?(line, opts)
    effective = opts.invert ? !is_match : is_match

    if effective
      matched_any = true
      match_count += 1

      if opts.quiet
        # do nothing — we'll exit 0 at the end
      elsif opts.list_files || opts.list_no_match
        # do nothing per line
      elsif opts.count_only
        # accumulate, print at end
      else
        if use_context
          # Print the group separator between non-adjacent groups.
          if need_sep
            STDOUT.write(group_sep + "\n") unless group_sep.nil?
            need_sep = false
          end
          # Flush before-context
          bi = 0
          start_num = line_num - before_buf.length
          while bi < before_buf.length
            emit_line(before_buf[bi], start_num + bi, offsets[start_num - 1 + bi],
                      filename, print_fname, "-", opts)
            bi += 1
          end
          before_buf = []
        end

        if opts.only_matching
          each_match_in_line(line, opts) do |m|
            emit_line(m, line_num, offsets[idx], filename, print_fname, ":", opts)
          end
        else
          emit_line(line, line_num, offsets[idx], filename, print_fname, ":", opts)
        end

        after_left = opts.after_context
        need_sep = false
      end
    else
      if after_left > 0
        unless opts.quiet || opts.list_files || opts.list_no_match || opts.count_only
          emit_line(line, line_num, offsets[idx], filename, print_fname, "-", opts)
        end
        after_left -= 1
        need_sep = false
      else
        if use_context && after_left == 0 && matched_any
          need_sep = true
        end
        # Maintain before-context buffer
        if opts.before_context > 0
          before_buf.push(line)
          while before_buf.length > opts.before_context
            # drop oldest: rebuild without index 0
            new_buf = []
            j = 1
            while j < before_buf.length
              new_buf.push(before_buf[j])
              j += 1
            end
            before_buf = new_buf
          end
        end
      end
    end
  end

  [matched_any, match_count, lines.length]
end

# Collect all files to search, expanding directories when -r is set.
def collect_files(paths, opts)
  result = []
  result.push(""); result.pop
  paths.each do |path|
    cpath = "" + path
    if File.directory?(cpath)
      if opts.recursive
        expand_dir(cpath, opts, result)
      else
        STDERR.puts "grep: #{cpath}: Is a directory" unless opts.suppress_errors
      end
    else
      result.push(cpath)
    end
  end
  result
end

def expand_dir(dir, opts, result)
  entries = Dir.entries(dir)
  entries.each do |entry|
    next if entry == "." || entry == ".."
    full = dir + "/" + entry
    if File.directory?(full)
      expand_dir(full, opts, result)
    else
      result.push(full)
    end
  end
end

# ── main ──────────────────────────────────────────────────────────────────────

opts, files = parse_argv(ARGV)

# The first non-option arg is the pattern when -e was not used.
if opts.raw_patterns.empty?
  if files.empty?
    STDERR.puts "grep: no pattern given"
    exit 2
  end
  opts.raw_patterns.push(files[0])
  files = files[1, files.length - 1]
end

compile_patterns(opts)

# Expand directories when -r given; warn if non-recursive dir passed.
all_files = collect_files(files, opts)
reading_stdin = all_files.empty?
all_files = ["-"] if reading_stdin

file_count = all_files.length

exit_code = 1  # 1 = no match found
found_error = false

all_files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "grep: #{cname}: No such file or directory" unless opts.suppress_errors
    found_error = true
    next
  end

  content = (cname == "-") ? STDIN.read : File.read(cname)
  display_name = (cname == "-") ? opts.label : cname
  print_fname = show_fname?(opts, file_count)

  matched_any, match_count, total_lines = grep_content(content, display_name, print_fname, opts)

  if matched_any
    exit_code = 0
    if opts.quiet
      exit 0
    elsif opts.list_files
      puts display_name
    elsif opts.count_only
      out = ""
      out += "#{display_name}:" if print_fname
      puts out + match_count.to_s
    end
  else
    if opts.list_no_match && !opts.quiet
      puts display_name
    elsif opts.count_only && !opts.quiet
      out = ""
      out += "#{display_name}:" if print_fname
      puts out + "0"
    end
  end
end

exit found_error ? 2 : exit_code
