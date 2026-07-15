# seq.rb, print a sequence of numbers (GNU seq, Spinel port).
#
# Print numbers from FIRST to LAST (inclusive) with step INCREMENT.
# Numbers that are whole values print without a decimal point when all
# arguments are integers; otherwise they are formatted to match the
# decimal precision of the argument with the most decimal places.
#
# Synopsis:
#   seq LAST
#   seq FIRST LAST
#   seq FIRST INCREMENT LAST
#
# Flags:
#   -s SEP, --separator=SEP  use SEP to separate numbers (default: newline)
#   -w, --equal-width        pad with leading zeros so all values are the same
#                            printed width
#   --help                   usage
#
# Compile: spinel nix_utils/seq.rb -o nix_utils/bin/seq
# Run:
#   ./bin/seq 5
#   ./bin/seq 1 2 10
#   ./bin/seq -s, 1 5    # -> 1,2,3,4,5
#   ./bin/seq -w 8 10    # -> 08 09 10
#
# Core Ruby only (Float, STDOUT); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/seq.rb ...`).

USAGE = "Usage: seq [OPTION]... LAST\n" \
        "  or:  seq [OPTION]... FIRST LAST\n" \
        "  or:  seq [OPTION]... FIRST INCREMENT LAST\n" \
        "Print a sequence of numbers from FIRST to LAST by INCREMENT.\n" \
        "  -s SEP  use SEP as separator (default newline)\n" \
        "  -w      equal width by padding with leading zeros\n" \
        "  --help"

class SeqOptions
  attr_accessor :separator, :equal_width
  def initialize
    @separator = "\n"
    @equal_width = false
  end
end

def parse_argv(argv)
  opts = SeqOptions.new
  nums = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done
      nums.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "-w" || arg == "--equal-width"
      opts.equal_width = true
    elsif arg == "-s" || arg == "--separator"
      index += 1
      if index >= argv.length
        STDERR.puts "seq: option requires an argument -- 's'"
        exit 1
      end
      opts.separator = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.separator = arg[2, arg.length - 2]
    elsif arg.length > 12 && arg[0, 12] == "--separator="
      opts.separator = arg[12, arg.length - 12]
    elsif arg.length > 0 && (arg[0] != "-" || arg == "-" || numeric_arg?(arg))
      nums.push(arg)
    else
      STDERR.puts "seq: invalid option -- '#{arg}'"
      STDERR.puts "Try 'seq --help' for more information."
      exit 1
    end
    index += 1
  end
  [opts, nums]
end

def numeric_arg?(s)
  return false if s.nil? || s == ""
  i = 0
  i += 1 if s[0] == "-" || s[0] == "+"
  return false if i >= s.length
  dot_seen = false
  while i < s.length
    c = s[i]
    if c == "."
      return false if dot_seen
      dot_seen = true
    elsif !"0123456789".include?(c)
      return false
    end
    i += 1
  end
  true
end

def parse_num(s, label)
  unless numeric_arg?(s)
    STDERR.puts "seq: invalid #{label}: '#{s}'"
    exit 1
  end
  s.to_f
end

# Count decimal places in a number string like "1.50" -> 2, "3" -> 0.
def decimal_places(s)
  dot = s.index(".")
  return 0 if dot.nil?
  # Strip trailing zeros from the original string for a clean count.
  frac = s[dot + 1, s.length - dot - 1]
  i = frac.length - 1
  while i >= 0 && frac[i] == "0"
    i -= 1
  end
  i + 1
end

# Format n with the given number of decimal places, without sprintf.
def format_fixed(n, places)
  factor = 1
  i = 0
  while i < places
    factor *= 10
    i += 1
  end
  negative = n < 0.0
  abs_n = negative ? -n : n
  scaled = (abs_n * factor + 0.5).to_i
  whole = scaled / factor
  frac = scaled % factor
  frac_str = frac.to_s
  while frac_str.length < places
    frac_str = "0" + frac_str
  end
  result = places > 0 ? "#{whole}.#{frac_str}" : whole.to_s
  negative ? "-#{result}" : result
end

# Pad s to width with leading zeros, preserving a leading minus sign.
def zero_pad(s, width)
  return s if s.length >= width
  if s.length > 0 && s[0] == "-"
    "-" + ("0" * (width - s.length)) + s[1, s.length - 1]
  else
    ("0" * (width - s.length)) + s
  end
end

opts, nums = parse_argv(ARGV)

if nums.empty?
  STDERR.puts "seq: missing operand"
  STDERR.puts "Try 'seq --help' for more information."
  exit 1
end

first_s, inc_s, last_s =
  case nums.length
  when 1 then ["1", "1", nums[0]]
  when 2 then [nums[0], "1", nums[1]]
  else        [nums[0], nums[1], nums[2]]
  end

first_n = parse_num(first_s, "first value")
inc_n   = parse_num(inc_s,   "increment")
last_n  = parse_num(last_s,  "last value")

if inc_n == 0.0
  STDERR.puts "seq: invalid Zero increment value: '#{inc_s}'"
  exit 1
end

# Determine output decimal precision from the argument strings.
places = [decimal_places(first_s), decimal_places(inc_s), decimal_places(last_s)].max

# For -w, determine the target width from the formatted first and last values.
pad_width = 0
if opts.equal_width
  w1 = format_fixed(first_n, places).length
  w2 = format_fixed(last_n, places).length
  pad_width = w1 > w2 ? w1 : w2
end

sep = opts.separator
first_item = true
current = first_n
tolerance = inc_n.abs * 1e-10

while true
  if inc_n > 0.0
    break if current > last_n + tolerance
  else
    break if current < last_n - tolerance
  end

  STDOUT.write(sep) unless first_item
  first_item = false

  s = format_fixed(current, places)
  s = zero_pad(s, pad_width) if pad_width > 0
  STDOUT.write(s)

  current += inc_n
end

STDOUT.write("\n") unless first_item

exit 0
