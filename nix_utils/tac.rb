# tac.rb, concatenate and print files in reverse (GNU tac, Spinel port).
#
# Prints each FILE (or standard input when FILE is "-" or none given) with
# the order of the records reversed.  The default record separator is newline.
#
# Flags:
#   -b, --before             attach the separator before instead of after
#   -s SEP, --separator=SEP  use SEP as the record separator instead of newline
#   --help                   usage
#
# Compile: spinel nix_utils/tac.rb -o nix_utils/bin/tac
# Run:
#   ./bin/tac file.txt
#   printf 'a\nb\nc\n' | ./bin/tac
#   ./bin/tac -s, comma-records.txt
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/tac.rb ...`).

USAGE = "Usage: tac [OPTION]... [FILE]...\n" \
        "Write each FILE to standard output, last line first.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -b         attach separator before instead of after\n" \
        "  -s SEP     use SEP as record separator instead of newline\n" \
        "  --help"

class TacOptions
  attr_accessor :before, :separator
  def initialize
    @before = false
    @separator = "\n"
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
  [opts, files]
end

def read_source(name)
  return STDIN.read if name == "-"
  File.read(name)
end

# Split content into sep-terminated records. Each element in the returned array
# includes its trailing separator, except possibly the last element (when the
# content does not end with sep).
def split_records(content, sep)
  records = []
  rest = content
  sep_len = sep.length
  while rest.length > 0
    pos = rest.index(sep)
    if pos.nil?
      records.push(rest)
      rest = ""
    else
      records.push(rest[0, pos + sep_len])
      rest = rest[pos + sep_len, rest.length - pos - sep_len]
    end
  end
  records
end

def tac_content(content, opts)
  sep = opts.separator
  if !opts.before
    if sep == "\n"
      return content.lines.reverse.join("")
    end
    split_records(content, sep).reverse.join("")
  else
    # --before: separator precedes each record. Split on sep to get the record
    # bodies, then rejoin in reverse with sep in front.
    parts = content.split(sep, -1)
    parts.pop if !parts.empty? && parts.last == ""
    result = ""
    i = parts.length - 1
    first = true
    while i >= 0
      result += sep unless first
      first = false
      result += parts[i]
      i -= 1
    end
    result
  end
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "tac: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  if name != "-" && File.directory?(name)
    STDERR.puts "tac: #{name}: Is a directory"
    exit_code = 1
    next
  end
  STDOUT.write(tac_content(read_source(name), opts))
end

exit exit_code
