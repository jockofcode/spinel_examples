# tac.rb, concatenate and print files in reverse (GNU tac, Spinel port).
#
# Prints each FILE (or standard input when FILE is "-" or none given) with
# the order of the records reversed.  The default record separator is newline.
#
# Flags:
#   -b, --before             attach the separator before instead of after
#   -r, --regex              interpret the separator as a regular expression
#   -s SEP, --separator=SEP  use SEP as the record separator instead of newline
#   --help                   usage
#
# Compile: spinel nix_utils/tac.rb -o nix_utils/bin/tac
# Run:
#   ./bin/tac file.txt
#   printf 'a\nb\nc\n' | ./bin/tac
#   ./bin/tac -s, comma-records.txt
#   printf 'a1b22c\n' | ./bin/tac -r -s '[0-9]+'
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); the -r flag additionally
# uses Regexp, matching grep.rb/od.rb (needs Spinel's regex support).
# Runs unmodified under CRuby (`ruby nix_utils/tac.rb ...`).

USAGE = "Usage: tac [OPTION]... [FILE]...\n" \
        "Write each FILE to standard output, last line first.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -b         attach separator before instead of after\n" \
        "  -r         interpret the separator as a regular expression\n" \
        "  -s SEP     use SEP as record separator instead of newline\n" \
        "  --help"

class TacOptions
  attr_accessor :before, :separator, :regex, :compiled_re
  def initialize
    @before      = false
    @separator   = "\n"
    @regex       = false
    @compiled_re = Regexp.new("\n")
  end
end

def parse_argv(argv)
  opts = TacOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || (arg.length < 2 || arg[0] != "-")
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "-b" || arg == "--before"
      opts.before = true
    elsif arg == "-r" || arg == "--regex"
      opts.regex = true
    elsif arg == "-s" || arg == "--separator"
      index += 1
      if index >= argv.length
        STDERR.puts "tac: option requires an argument -- 's'"
        exit 1
      end
      opts.separator = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.separator = arg[2, arg.length - 2]
    elsif arg.length > 12 && arg[0, 12] == "--separator="
      opts.separator = arg[12, arg.length - 12]
    else
      STDERR.puts "tac: invalid option -- '#{arg}'"
      STDERR.puts "Try 'tac --help' for more information."
      exit 1
    end
    index += 1
  end
  # Compile the regex here while opts is still typed (not sp_RbVal).
  opts.compiled_re = Regexp.new(opts.separator)
  [opts, files]
end

def read_source(name)
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

# Break content into record bodies and the separators between them. Returns
# [bodies, seps] where seps[i] is the separator that sits between bodies[i] and
# bodies[i+1]. A trailing separator does not create a final empty record, which
# matches GNU tac. When opts.regex is set the separator is a regular expression.
def segment(content, opts)
  bodies = []
  seps   = []
  rest   = content
  # Use opts.compiled_re (typed as Regexp*) instead of a local ternary variable
  # to avoid sp_RbVal dispatch failure on .match().
  sep    = opts.separator
  while true
    if opts.regex
      m = opts.compiled_re.match(rest)
      if m.nil?
        bodies.push(rest)
        break
      end
      pre  = m.pre_match.length
      mlen = m[0].length
      mlen = 1 if mlen == 0            # guard against zero-width matches
      bodies.push(rest[0, pre])
      seps.push(rest[pre, mlen])
      rest = rest[pre + mlen, rest.length - pre - mlen]
    else
      pos = rest.index(sep)
      if pos.nil?
        bodies.push(rest)
        break
      end
      bodies.push(rest[0, pos])
      seps.push(sep)
      rest = rest[pos + sep.length, rest.length - pos - sep.length]
    end
  end
  # Drop the empty trailing record produced when content ends with a separator.
  bodies.pop if bodies.length > 0 && bodies.last == "" && bodies.length == seps.length + 1
  [bodies, seps]
end

def tac_content(content, opts)
  bodies, seps = segment(content, opts)
  return "" if bodies.empty?

  result = ""
  last = bodies.length - 1
  if opts.before
    # The separator leads the record that follows it, so reversed output keeps
    # each separator in front of the (now earlier) body it preceded.
    result = result + bodies[last]
    i = last - 1
    while i >= 0
      result = result + seps[i] if i < seps.length
      result = result + bodies[i]
      i -= 1
    end
  else
    # Default: the separator trails its own body.
    i = last
    while i >= 0
      result = result + bodies[i]
      result = result + seps[i] if i < seps.length
      i -= 1
    end
  end
  result
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "tac: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  if cname != "-" && File.directory?(cname)
    STDERR.puts "tac: #{cname}: Is a directory"
    exit_code = 1
    next
  end
  STDOUT.write(tac_content(read_source(cname), opts))
end

exit exit_code
