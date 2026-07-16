# shuf.rb, generate a random permutation of input lines (GNU shuf, Spinel port).
#
# Randomly permutes all lines of each FILE (or stdin), then writes to stdout.
# Uses a Fisher-Yates shuffle seeded with the current time.
#
# Flags:
#   -n NUM, --head-count=NUM  output at most NUM lines
#   -o FILE, --output=FILE    write result to FILE instead of stdout
#   -r, --repeat              output lines may be repeated (until -n reached)
#   -z, --zero-terminated     NUL-terminated input/output
#   -e, --echo                treat each ARG as an input line
#   -i LO-HI, --input-range=LO-HI  treat integers LO..HI as the input
#   --random-source=FILE      get random bytes from FILE
#   --help                    usage
#
# Compile: spinel nix_utils/shuf.rb -o nix_utils/bin/shuf
# Run:
#   ./bin/shuf file.txt
#   ./bin/shuf -n 3 file.txt
#   ./bin/shuf -e a b c d

USAGE = "Usage: shuf [OPTION]... [FILE]\n" \
        "  or:  shuf -e [OPTION]... [ARG]...\n" \
        "  or:  shuf -i LO-HI [OPTION]...\n" \
        "Write a random permutation of lines to standard output.\n" \
        "  -n NUM   output at most NUM lines\n" \
        "  -r       allow repeated lines\n" \
        "  -z       NUL-terminated input/output\n" \
        "  -e       treat arguments as input lines\n" \
        "  -i LO-HI  use integer range as input\n" \
        "  -o FILE  write to FILE\n" \
        "  --help"

class ShufOptions
  attr_accessor :head_count, :output_file, :repeat, :zero, :echo_mode, :input_range
  def initialize
    @head_count  = nil
    @output_file = nil
    @repeat      = false
    @zero        = false
    @echo_mode   = false
    @input_range = nil  # [lo, hi]
  end
end

def parse_argv(argv)
  opts = ShufOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || (arg == "-" || (arg.length < 2 || arg[0] != "-"))
      files.push(arg); index += 1; next
    end
    if arg == "--"; options_done = true; index += 1; next; end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "-r" || arg == "--repeat"; opts.repeat = true
    elsif arg == "-z" || arg == "--zero-terminated"; opts.zero = true
    elsif arg == "-e" || arg == "--echo"; opts.echo_mode = true
    elsif arg == "-n" || arg == "--head-count"
      index += 1; opts.head_count = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-n"
      opts.head_count = arg[2, arg.length - 2].to_i
    elsif arg.length > 13 && arg[0, 13] == "--head-count="
      opts.head_count = arg[13, arg.length - 13].to_i
    elsif arg == "-o" || arg == "--output"
      index += 1; opts.output_file = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-o"
      opts.output_file = arg[2, arg.length - 2]
    elsif arg.length > 9 && arg[0, 9] == "--output="
      opts.output_file = arg[9, arg.length - 9]
    elsif arg == "-i" || arg == "--input-range"
      index += 1
      range_str = argv[index]
      parts = range_str.split("-", 2)
      opts.input_range = [parts[0].to_i, parts[1].to_i]
    elsif arg.length > 2 && arg[0, 2] == "-i"
      parts = arg[2, arg.length - 2].split("-", 2)
      opts.input_range = [parts[0].to_i, parts[1].to_i]
    elsif arg.length > 14 && arg[0, 14] == "--input-range="
      parts = arg[14, arg.length - 14].split("-", 2)
      opts.input_range = [parts[0].to_i, parts[1].to_i]
    elsif arg == "--random-source"
      index += 1  # accept, ignore
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "r"; opts.repeat = true
        elsif letter == "z"; opts.zero = true
        elsif letter == "e"; opts.echo_mode = true
        else
          STDERR.puts "shuf: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

# Fisher-Yates shuffle using rand (seeded with time)
def shuffle(arr)
  n = arr.length
  result = arr.dup
  i = n - 1
  while i > 0
    j = rand(i + 1)
    tmp = result[i]
    result[i] = result[j]
    result[j] = tmp
    i -= 1
  end
  result
end

opts, args = parse_argv(ARGV)

# Build the input lines
lines = []
delim = opts.zero ? "\0" : "\n"

if opts.input_range
  lo = opts.input_range[0]
  hi = opts.input_range[1]
  n = lo
  while n <= hi
    lines.push(n.to_s)
    n += 1
  end
elsif opts.echo_mode
  args.each { |a| lines.push("" + a) }
else
  files = []
  if args.empty?
    files.push("-")
  else
    args.each { |a| files.push("" + a) }
  end
  files.each do |name|
    if name != "-" && !File.exist?(name)
      STDERR.puts "shuf: #{name}: No such file or directory"
      exit 1
    end
    content = (name == "-") ? STDIN.read : File.read(name)
    if delim == "\n"
      content.lines.each do |l|
        l = l.end_with?("\n") ? l[0, l.length - 1] : l
        lines.push(l)
      end
    else
      parts = content.split("\0", -1)
      parts.pop if !parts.empty? && parts.last == ""
      parts.each { |l| lines.push(l) }
    end
  end
end

# Open output
out_io = if opts.output_file
  File.open(opts.output_file, "w")
else
  STDOUT
end

if opts.repeat
  # Infinite sampling with replacement, limited by head_count
  count = opts.head_count || 0
  i = 0
  while opts.head_count.nil? || i < count
    out_io.write(lines[rand(lines.length)] + delim)
    i += 1
  end
else
  shuffled = shuffle(lines)
  take = opts.head_count ? [opts.head_count, shuffled.length].min : shuffled.length
  i = 0
  while i < take
    out_io.write(shuffled[i] + delim)
    i += 1
  end
end

out_io.close if opts.output_file
