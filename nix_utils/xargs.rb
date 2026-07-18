# xargs.rb, build and execute command lines from standard input (GNU xargs, Spinel port).
#
# Flags:
#   -a FILE, --arg-file=FILE    read from file instead of stdin
#   -d DELIM, --delimiter=DELIM custom input delimiter
#   -I REPLACE, --replace[=R]   replace-string mode; implies -L 1
#   -L N, --max-lines=N         at most N nonblank input lines per command
#   -n N, --max-args=N          at most N arguments per command
#   -r, --no-run-if-empty       don't run if no input
#   -t, --verbose               print command to stderr before running
#   -p, --interactive           prompt before each command
#   -E STR                      end-of-file string
#   -s N, --max-chars=N         max characters per command line
#   -x, --exit                  exit if size exceeded
#   --show-limits               print system limits
#   --help, --version
#
# Skip: -P/--max-procs (fork/waitpid), -0/--null (NUL input)
#
# Compile: spinel nix_utils/xargs.rb -o nix_utils/bin/xargs

USAGE = "Usage: xargs [OPTION]... [COMMAND [INITIAL-ARGS]...]\n" \
        "Run COMMAND with arguments from standard input.\n" \
        "  -a FILE   read arguments from FILE\n" \
        "  -d DELIM  input delimiter (default: whitespace)\n" \
        "  -I REPL   replace REPL in COMMAND with each line\n" \
        "  -L N      at most N lines per command\n" \
        "  -n N      at most N arguments per command\n" \
        "  -r        don't run if no input\n" \
        "  -t        verbose: print command to stderr\n" \
        "  -p        interactive: prompt before each command\n" \
        "  -E STR    end-of-file string\n" \
        "  -s N      max characters per command\n" \
        "  -x        exit if size exceeded\n" \
        "  --show-limits\n" \
        "  --help    --version\n" \
        "  -0/--null unsupported (NUL bytes not possible in this build)\n" \
        "  -P/--max-procs unsupported (parallel execution not available)"

VERSION = "xargs (nix_utils) 1.0"

require_relative "nix_helpers"

class XargsOptions
  attr_accessor :arg_file, :delimiter, :replace_str, :max_lines
  attr_accessor :max_args, :no_run_empty, :verbose, :interactive
  attr_accessor :eof_str, :max_chars, :exit_on_size, :command_args
  def initialize
    @arg_file      = nil
    @delimiter     = nil    # nil = whitespace
    @replace_str   = nil
    @max_lines     = nil
    @max_args      = nil
    @no_run_empty  = false
    @verbose       = false
    @interactive   = false
    @eof_str       = nil
    @max_chars     = nil
    @exit_on_size  = false
    @command_args  = []
  end
end

opts = XargsOptions.new
options_done = false
reading_cmd  = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || reading_cmd
    opts.command_args.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "--show-limits"
    puts "Your environment variables take up 0 bytes"
    puts "POSIX upper limit on argument length (this system): 262144"
    puts "POSIX smallest allowable upper limit on argument length (all systems): 4096"
    puts "Maximum length of command we could actually use: 262144"
    exit 0
  elsif arg == "-0" || arg == "--null"
    die("xargs: -0/--null is unsupported in this build (NUL bytes not possible in Spinel C strings)")
  elsif arg == "-P" || arg == "--max-procs"
    die("xargs: -P/--max-procs is unsupported (parallel execution not available)")
  elsif arg == "-a" || arg == "--arg-file"
    index += 1; opts.arg_file = coerce(ARGV[index])
  elsif arg.length > 11 && arg[0, 11] == "--arg-file="
    opts.arg_file = arg[11, arg.length - 11]
  elsif arg == "-d" || arg == "--delimiter"
    index += 1; opts.delimiter = coerce(ARGV[index])
  elsif arg.length > 12 && arg[0, 12] == "--delimiter="
    opts.delimiter = arg[12, arg.length - 12]
  elsif arg.length > 2 && arg[0, 2] == "-d"
    opts.delimiter = arg[2, arg.length - 2]
  elsif arg == "-I"
    index += 1; opts.replace_str = coerce(ARGV[index])
    opts.max_lines = 1
  elsif arg.length > 2 && arg[0, 2] == "-I"
    opts.replace_str = arg[2, arg.length - 2]
    opts.max_lines = 1
  elsif arg == "--replace" || arg == "-i"
    opts.replace_str = "{}"
    opts.max_lines = 1
  elsif arg.length > 10 && arg[0, 10] == "--replace="
    opts.replace_str = arg[10, arg.length - 10]
    opts.max_lines = 1
  elsif arg == "-L" || arg == "--max-lines"
    index += 1; opts.max_lines = coerce(ARGV[index]).to_i
  elsif arg.length > 12 && arg[0, 12] == "--max-lines="
    opts.max_lines = arg[12, arg.length - 12].to_i
  elsif arg.length > 2 && arg[0, 2] == "-L"
    opts.max_lines = arg[2, arg.length - 2].to_i
  elsif arg == "-n" || arg == "--max-args"
    index += 1; opts.max_args = coerce(ARGV[index]).to_i
  elsif arg.length > 11 && arg[0, 11] == "--max-args="
    opts.max_args = arg[11, arg.length - 11].to_i
  elsif arg.length > 2 && arg[0, 2] == "-n"
    opts.max_args = arg[2, arg.length - 2].to_i
  elsif arg == "-r" || arg == "--no-run-if-empty"
    opts.no_run_empty = true
  elsif arg == "-t" || arg == "--verbose"
    opts.verbose = true
  elsif arg == "-p" || arg == "--interactive"
    opts.interactive = true
    opts.verbose     = true
  elsif arg == "-E"
    index += 1; opts.eof_str = coerce(ARGV[index])
  elsif arg == "-s" || arg == "--max-chars"
    index += 1; opts.max_chars = coerce(ARGV[index]).to_i
  elsif arg.length > 12 && arg[0, 12] == "--max-chars="
    opts.max_chars = arg[12, arg.length - 12].to_i
  elsif arg.length > 2 && arg[0, 2] == "-s"
    opts.max_chars = arg[2, arg.length - 2].to_i
  elsif arg == "-x" || arg == "--exit"
    opts.exit_on_size = true
  elsif arg[0] != "-"
    opts.command_args.push(arg)
    reading_cmd = true
  else
    die("xargs: invalid option -- '#{arg}'\nTry 'xargs --help' for more information.")
  end
  index += 1
end

# ── Tokeniser ────────────────────────────────────────────────────────────────

def tokenize_input(input, delimiter)
  tokens = []
  s = "" + input
  if delimiter.nil?
    # Shell-style: whitespace-delimited, respecting single/double quotes and backslash
    cur   = ""
    mode  = :normal  # :normal, :single, :double
    i     = 0
    while i < s.length
      c = s[i]
      if mode == :single
        if c == "'"
          mode = :normal
        else
          cur += c
        end
      elsif mode == :double
        if c == "\\"
          i += 1
          cur += s[i] if i < s.length
        elsif c == "\""
          mode = :normal
        else
          cur += c
        end
      else
        if c == "'"
          mode = :single
        elsif c == "\""
          mode = :double
        elsif c == "\\"
          i += 1
          cur += s[i] if i < s.length
        elsif c == " " || c == "\t" || c == "\n" || c == "\r"
          tokens.push(cur) unless cur == ""
          cur = ""
        else
          cur += c
        end
      end
      i += 1
    end
    tokens.push(cur) unless cur == ""
  else
    d = "" + delimiter
    # Interpret escape sequences in delimiter
    if d == "\\n"
      d = "\n"
    elsif d == "\\t"
      d = "\t"
    end
    parts = s.split(d, -1)
    parts.each do |p|
      cp = "" + p
      cp = cp.chomp("\n")
      tokens.push(cp)
    end
    tokens.pop if !tokens.empty? && ("" + tokens.last) == ""
  end
  tokens
end

# Read input
input_data =
  if opts.arg_file.nil?
    STDIN.read
  else
    File.read("" + opts.arg_file)
  end

tokens = tokenize_input(input_data, opts.delimiter)

# Apply EOF string
unless opts.eof_str.nil?
  eof = "" + opts.eof_str
  cut = tokens.index(eof)
  tokens = tokens[0, cut] unless cut.nil?
end

if tokens.empty? && opts.no_run_empty
  exit 0
end

cmd_base = opts.command_args.empty? ? ["echo"] : opts.command_args
cmd_base_str = cmd_base.map { |a| "" + a }.join(" ")

exit_code = 0

def run_command(cmd_str, verbose, interactive)
  cs = "" + cmd_str
  if verbose
    STDERR.puts cs
  end
  if interactive
    STDERR.print "?..."
    response = STDIN.gets || ""
    return true unless ("" + response).strip.downcase.start_with?("y")
  end
  system(cs)
  if $? != 0
    return false
  end
  true
end

if !opts.replace_str.nil?
  rs = "" + opts.replace_str
  tokens.each do |token|
    t = "" + token
    cmd_str = cmd_base_str.gsub(rs, t)
    ok = run_command(cmd_str, opts.verbose, opts.interactive)
    exit_code = 1 unless ok
  end
elsif !opts.max_lines.nil?
  # Group into batches of max_lines non-blank lines
  batch = []
  line_count = 0
  tokens.each do |token|
    t = "" + token
    batch.push(t)
    line_count += 1 if t != ""
    if line_count >= opts.max_lines
      cmd_str = cmd_base_str + " " + batch.map { |a| "'" + ("" + a).gsub("'", "'\\''") + "'" }.join(" ")
      ok = run_command(cmd_str, opts.verbose, opts.interactive)
      exit_code = 1 unless ok
      batch = []
      line_count = 0
    end
  end
  unless batch.empty?
    cmd_str = cmd_base_str + " " + batch.map { |a| "'" + ("" + a).gsub("'", "'\\''") + "'" }.join(" ")
    ok = run_command(cmd_str, opts.verbose, opts.interactive)
    exit_code = 1 unless ok
  end
else
  # Batch by max_args or max_chars
  batch = []
  tokens.each do |token|
    t = "" + token
    if !opts.max_args.nil? && batch.length >= opts.max_args
      cmd_str = cmd_base_str + " " + batch.join(" ")
      if !opts.max_chars.nil? && cmd_str.length > opts.max_chars
        STDERR.puts "xargs: argument list too long" if opts.exit_on_size
        exit 1 if opts.exit_on_size
      end
      ok = run_command(cmd_str, opts.verbose, opts.interactive)
      exit_code = 1 unless ok
      batch = []
    end
    batch.push(t)
  end
  unless batch.empty?
    cmd_str = cmd_base_str + " " + batch.join(" ")
    ok = run_command(cmd_str, opts.verbose, opts.interactive)
    exit_code = 1 unless ok
  end
end

exit exit_code
