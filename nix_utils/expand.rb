# expand.rb, convert tabs to spaces (GNU expand, Spinel port).
#
# Converts each TAB character in each FILE (or stdin) to the appropriate
# number of spaces to reach the next tab stop. Default tab stop is every 8
# columns; -t lets you set custom tab stops.
#
# Flags:
#   -t N, --tabs=N     set tab stop every N columns (default 8)
#   -t LIST            set individual tab stops: "1,5,10,..."
#   -i, --initial      only expand tabs at the start of each line
#   --help             usage
#
# Compile: spinel nix_utils/expand.rb -o nix_utils/bin/expand
# Run:
#   ./bin/expand file.txt
#   printf 'a\tb\tc\n' | ./bin/expand -t 4
#
# Core Ruby only; no require gate needed.

USAGE = "Usage: expand [OPTION]... [FILE]...\n" \
        "Convert tabs in each FILE to spaces, writing to stdout.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -t N         set tab stop every N columns (default 8)\n" \
        "  -t LIST      comma-separated list of explicit tab stops\n" \
        "  -i           only expand initial (leading) tabs\n" \
        "  --help"

class ExpandOptions
  attr_accessor :tab_stops, :tab_size, :initial_only
  def initialize
    @tab_stops    = nil   # nil = use uniform tab_size
    @tab_size     = 8
    @initial_only = false
  end
end

def parse_tab_spec(spec, opts)
  if spec.include?(",")
    stops = []
    spec.split(",").each { |s| stops.push(s.to_i) }
    opts.tab_stops = stops
  else
    opts.tab_size  = spec.to_i
    opts.tab_stops = nil
  end
end

def parse_argv(argv)
  opts = ExpandOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "-i" || arg == "--initial"
      opts.initial_only = true
    elsif arg == "-t" || arg == "--tabs"
      index += 1
      parse_tab_spec(argv[index], opts)
    elsif arg.length > 2 && arg[0, 2] == "-t"
      parse_tab_spec(arg[2, arg.length - 2], opts)
    elsif arg.length > 7 && arg[0, 7] == "--tabs="
      parse_tab_spec(arg[7, arg.length - 7], opts)
    else
      STDERR.puts "expand: invalid option -- '#{arg}'"
      STDERR.puts "Try 'expand --help' for more information."
      exit 1
    end
    index += 1
  end
  [opts, files]
end

# Return the next tab stop column >= col+1.
def next_stop(col, opts)
  if opts.tab_stops
    opts.tab_stops.each do |stop|
      return stop if stop > col
    end
    # Past last explicit stop: stay at next multiple of last stop width
    last = opts.tab_stops.last
    return last + (((col - last) / 1) + 1) if last <= col
    col + 1  # fallback
  else
    col + (opts.tab_size - (col % opts.tab_size))
  end
end

def expand_line(line, opts)
  result = ""
  col = 0
  in_leading = true

  i = 0
  while i < line.length
    ch = line[i]
    if ch == "\t"
      if opts.initial_only && !in_leading
        result += ch
        col += 1
      else
        stop = next_stop(col, opts)
        spaces = stop - col
        j = 0
        while j < spaces
          result += " "
          j += 1
        end
        col = stop
      end
    else
      in_leading = false if ch != " "
      result += ch
      col += 1
    end
    i += 1
  end
  result
end

def process(content, opts)
  content.lines.each do |raw|
    has_nl = raw.end_with?("\n")
    body = has_nl ? raw[0, raw.length - 1] : raw
    STDOUT.write(expand_line(body, opts))
    STDOUT.write("\n") if has_nl
  end
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "expand: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  content = (name == "-") ? STDIN.read : File.read(name)
  process(content, opts)
end
exit exit_code
