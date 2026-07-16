# unexpand.rb, convert spaces to tabs (GNU unexpand, Spinel port).
#
# Converts runs of spaces in each FILE (or stdin) to tabs where possible,
# writing to stdout. Only converts leading spaces by default; -a converts
# spaces throughout each line.
#
# Flags:
#   -a, --all       convert all spaces, not just leading
#   -t N, --tabs=N  set tab stop every N columns (default 8)
#   -t LIST         comma-separated list of explicit tab stops
#   --first-only    only convert leading spaces (default; opposite of -a)
#   --help          usage
#
# Compile: spinel nix_utils/unexpand.rb -o nix_utils/bin/unexpand
# Run:
#   ./bin/unexpand -a file.txt
#   printf '        hello\n' | ./bin/unexpand
#
# Core Ruby only; no require gate needed.

USAGE = "Usage: unexpand [OPTION]... [FILE]...\n" \
        "Convert spaces in each FILE to tabs, writing to stdout.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -a           convert all spaces (not just leading)\n" \
        "  -t N         tab stop every N columns (default 8)\n" \
        "  -t LIST      comma-separated list of explicit tab stops\n" \
        "  --first-only only convert leading spaces (default)\n" \
        "  --help"

class UnexpandOptions
  attr_accessor :all_spaces, :tab_stops, :tab_size
  def initialize
    @all_spaces = false
    @tab_stops  = nil
    @tab_size   = 8
  end
end

def parse_tab_spec(spec, opts)
  if spec.include?(",")
    stops = []
    spec.split(",").each { |s| stops.push(s.to_i) }
    opts.tab_stops = stops
    opts.all_spaces = true  # explicit stops implies -a
  else
    opts.tab_size  = spec.to_i
    opts.tab_stops = nil
    opts.all_spaces = true  # explicit -t implies -a
  end
end

def parse_argv(argv)
  opts = UnexpandOptions.new
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
    elsif arg == "-a" || arg == "--all"
      opts.all_spaces = true
    elsif arg == "--first-only"
      opts.all_spaces = false
    elsif arg == "-t" || arg == "--tabs"
      index += 1
      parse_tab_spec(argv[index], opts)
    elsif arg.length > 2 && arg[0, 2] == "-t"
      parse_tab_spec(arg[2, arg.length - 2], opts)
    elsif arg.length > 7 && arg[0, 7] == "--tabs="
      parse_tab_spec(arg[7, arg.length - 7], opts)
    else
      STDERR.puts "unexpand: invalid option -- '#{arg}'"
      STDERR.puts "Try 'unexpand --help' for more information."
      exit 1
    end
    index += 1
  end
  [opts, files]
end

def next_stop(col, opts)
  if opts.tab_stops
    opts.tab_stops.each { |s| return s if s > col }
    last = opts.tab_stops.last
    col + 1
  else
    col + (opts.tab_size - (col % opts.tab_size))
  end
end

def flush_spaces_helper(result, col, space_start_col, opts)
  end_col = col
  c = space_start_col
  while true
    ns = next_stop(c, opts)
    break if ns > end_col
    result = result + "\t"
    c = ns
  end
  while c < end_col
    result = result + " "
    c += 1
  end
  result
end

def unexpand_line(line, opts)
  result = ""
  col = 0
  space_run = 0
  space_start_col = 0
  in_leading = true

  i = 0
  while i < line.length
    ch = line[i]
    if ch == " " && (opts.all_spaces || in_leading)
      if space_run == 0
        space_start_col = col
      end
      space_run += 1
      col += 1
    else
      if space_run > 0
        result = flush_spaces_helper(result, col, space_start_col, opts)
        space_run = 0
      end
      if ch == "\t"
        stop = next_stop(col, opts)
        in_leading = false if !opts.all_spaces && col > 0 && result.length > 0
        result = result + "\t"
        col = stop
      else
        in_leading = false if ch != " "
        result = result + ch
        col += 1
      end
      space_run = 0
    end
    i += 1
  end
  if space_run > 0
    result = flush_spaces_helper(result, col, space_start_col, opts)
  end
  result
end

def process(content, opts)
  content.lines.each do |raw|
    has_nl = raw.end_with?("\n")
    body = has_nl ? raw[0, raw.length - 1] : raw
    STDOUT.write(unexpand_line(body, opts))
    STDOUT.write("\n") if has_nl
  end
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "unexpand: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  content = (cname == "-") ? STDIN.read : File.read(cname)
  process(content, opts)
end
exit exit_code
