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
#   -f FMT, --format=FMT     use a printf-style floating-point FORMAT
#   -s SEP, --separator=SEP  use SEP to separate numbers (default: newline)
#   -w, --equal-width        pad with leading zeros so all values are the same
#                            printed width
#   --help                   usage
#
# FORMAT accepts one floating-point conversion (%e, %f, %g and the uppercase
# variants) with optional flags, width, and precision, e.g. -f '%.2f'.
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
        "  -f FMT  printf-style float format   -s SEP  separator (default newline)\n" \
        "  -w      equal width by padding with leading zeros\n" \
        "  --help"

class SeqOptions
  attr_accessor :separator, :equal_width, :format
  def initialize
    @separator = "\n"
    @equal_width = false
    @format = nil
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
    elsif arg == "-f" || arg == "--format"
      index += 1
      if index >= argv.length
        STDERR.puts "seq: option requires an argument -- 'f'"
        exit 1
      end
      opts.format = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-f"
      opts.format = arg[2, arg.length - 2]
    elsif arg.length > 9 && arg[0, 9] == "--format="
      opts.format = arg[9, arg.length - 9]
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
  factor_f = 1.0
  i = 0
  while i < places
    factor_f *= 10.0
    i += 1
  end
  factor_i = factor_f.to_i
  negative = n < 0.0
  abs_n = negative ? -n : n
  scaled = (abs_n * factor_f + 0.5).to_i
  whole = scaled / factor_i
  frac = scaled % factor_i
  frac_str = frac.to_s
  while frac_str.length < places
    frac_str = "0" + frac_str
  end
  result = places > 0 ? whole.to_s + "." + frac_str : whole.to_s
  negative ? "-" + result : result
end

def pow10i(n)
  r = 1
  i = 0
  while i < n
    r *= 10
    i += 1
  end
  r
end

# Format a value in exponential notation with `prec` fractional digits.
def exp_str(value, prec, echar)
  neg = value < 0.0
  v = neg ? -value : value
  exp10 = 0
  if v != 0.0
    while v >= 10.0
      v /= 10.0; exp10 += 1
    end
    while v < 1.0
      v *= 10.0; exp10 -= 1
    end
  end
  scale = pow10i(prec)
  r = (v * scale + 0.5).to_i
  if r >= 10 * scale
    r /= 10
    exp10 += 1
  end
  s = r.to_s
  while s.length < prec + 1
    s = "0" + s
  end
  intp = s[0, s.length - prec]
  frac = s[s.length - prec, prec]
  mant = prec > 0 ? intp + "." + frac : intp
  eabs = exp10 < 0 ? -exp10 : exp10
  estr = eabs.to_s
  estr = "0" + estr if estr.length < 2
  (neg ? "-" : "") + mant + echar + (exp10 < 0 ? "-" : "+") + estr
end

# Strip trailing zeros (and a dangling dot) from a %g-style mantissa.
def strip_g(mantissa)
  return mantissa unless mantissa.include?(".")
  i = mantissa.length - 1
  while i >= 0 && mantissa[i] == "0"
    i -= 1
  end
  i -= 1 if i >= 0 && mantissa[i] == "."
  mantissa[0, i + 1]
end

# Render one floating-point conversion (f/e/g and uppercase) for value.
def render_conv(value, prec, conv)
  default_prec = prec.nil? ? 6 : prec.to_i
  if conv == "f" || conv == "F"
    format_fixed(value, default_prec)
  elsif conv == "e" || conv == "E"
    exp_str(value, default_prec, conv == "E" ? "E" : "e")
  else # g / G
    p = default_prec
    p = 1 if p == 0
    v = value < 0.0 ? -value : value
    exp10 = 0
    if v != 0.0
      while v >= 10.0
        v /= 10.0; exp10 += 1
      end
      while v < 1.0
        v *= 10.0; exp10 -= 1
      end
    end
    echar = conv == "G" ? "E" : "e"
    if exp10 < -4 || exp10 >= p
      strip_g(exp_str(value, p - 1, echar))
    else
      places = p - 1 - exp10
      places = 0 if places < 0
      strip_g(format_fixed(value, places))
    end
  end
end

# Apply a printf-style FORMAT (a single float conversion plus literal text) to
# value. Supports flags -, +, space, 0 and an optional width and precision.
def apply_format(fmt, value)
  out = ""
  i = 0
  while i < fmt.length
    c = fmt[i]
    if c != "%"
      out += c
      i += 1
      next
    end
    if fmt[i + 1] == "%"
      out += "%"
      i += 2
      next
    end
    j = i + 1
    flags = ""
    while j < fmt.length && "-+ 0#".include?(fmt[j])
      flags += fmt[j]; j += 1
    end
    width = ""
    while j < fmt.length && "0123456789".include?(fmt[j])
      width += fmt[j]; j += 1
    end
    prec = nil
    if j < fmt.length && fmt[j] == "."
      prec = ""
      j += 1
      while j < fmt.length && "0123456789".include?(fmt[j])
        prec += fmt[j]; j += 1
      end
    end
    conv = j < fmt.length ? fmt[j] : ""
    j += 1

    body = render_conv(value, prec, conv)
    # Apply the sign flags on non-negative values.
    if body.length > 0 && body[0] != "-"
      if flags.include?("+")
        body = "+" + body
      elsif flags.include?(" ")
        body = " " + body
      end
    end
    w = width == "" ? 0 : width.to_i
    if body.length < w
      if flags.include?("-")
        body = body + (" " * (w - body.length))
      elsif flags.include?("0")
        body = zero_pad(body, w)
      else
        body = (" " * (w - body.length)) + body
      end
    end
    out += body
    i = j
  end
  out
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
  when 1 then ["1", "1", "" + nums[0]]
  when 2 then ["" + nums[0], "1", "" + nums[1]]
  else        ["" + nums[0], "" + nums[1], "" + nums[2]]
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

  if opts.format.nil?
    s = format_fixed(current, places)
    s = zero_pad(s, pad_width) if pad_width > 0
  else
    s = apply_format(opts.format, current)
  end
  STDOUT.write(s)

  current += inc_n
end

STDOUT.write("\n") unless first_item

exit 0
