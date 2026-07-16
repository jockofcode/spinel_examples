# printf.rb, format and print data (GNU printf, Spinel port).
#
# Formats ARGUMENTS according to FORMAT and writes the result to stdout.
# The format string supports the same escape sequences and conversion
# specifiers as GNU printf(1), a subset of C's printf.
#
# Escape sequences in FORMAT:
#   \\  backslash     \a  alert     \b  backspace  \f  form feed
#   \n  newline       \r  CR        \t  tab         \v  vertical tab
#   \NNN  octal char  \xHH  hex char
#
# Conversion specifiers:
#   %d, %i   decimal integer
#   %o       octal integer
#   %x, %X   hex integer (lower/upper)
#   %e, %E   float in exponential notation
#   %f       float in fixed notation
#   %g, %G   float in shorter of %e/%f
#   %s       string
#   %c       first character of argument (or NUL if empty)
#   %b       string with \-escape sequences interpreted
#   %%       literal percent
#
# Width, precision, and flags (-, +, space, 0, #) before the specifier
# are supported for integer and float conversions.
#
# If more arguments than specifiers are given, the format is reused.
#
# Compile: spinel nix_utils/printf.rb -o nix_utils/bin/printf
# Run:
#   ./bin/printf '%d\n' 42
#   ./bin/printf '%.2f\n' 3.14
#   ./bin/printf '%s %s\n' hello world
#
# Core Ruby only; no require gate needed.

USAGE = "Usage: printf FORMAT [ARGUMENT]...\n" \
        "Format and print ARGUMENT(s) according to FORMAT.\n" \
        "Escape sequences: \\n \\t \\r \\a \\b \\f \\v \\\\ \\NNN \\xHH\n" \
        "Specifiers: %d %i %o %x %X %f %e %E %g %G %s %c %b %%\n" \
        "  --help"

if ARGV[0] == "--help"
  puts USAGE
  exit 0
end

if ARGV.empty?
  STDERR.puts "printf: missing operand"
  exit 1
end

def interpret_escapes(s)
  result = ""
  i = 0
  while i < s.length
    if s[i] == "\\" && i + 1 < s.length
      n = s[i + 1]
      if n == "n"
        result += "\n"; i += 2
      elsif n == "t"
        result += "\t"; i += 2
      elsif n == "r"
        result += "\r"; i += 2
      elsif n == "a"
        result += "\a"; i += 2
      elsif n == "b"
        result += "\b"; i += 2
      elsif n == "f"
        result += "\f"; i += 2
      elsif n == "v"
        result += "\v"; i += 2
      elsif n == "\\"
        result += "\\"; i += 2
      elsif n == "0" || "1234567".include?(n)
        # octal: up to 3 digits
        oct = ""
        j = i + 1
        while j < s.length && j < i + 4 && "01234567".include?(s[j])
          oct += s[j]; j += 1
        end
        result += oct.to_i(8).chr
        i = j
      elsif n == "x" || n == "X"
        hex = ""
        j = i + 2
        while j < s.length && j < i + 4 && "0123456789abcdefABCDEF".include?(s[j])
          hex += s[j]; j += 1
        end
        result += hex.to_i(16).chr
        i = j
      else
        result += s[i]; i += 1
      end
    else
      result += s[i]; i += 1
    end
  end
  result
end

def to_int(s)
  s = s.strip
  return 0 if s == ""
  if s.length >= 2 && s[0] == "0" && (s[1] == "x" || s[1] == "X")
    s[2, s.length - 2].to_i(16)
  elsif s.length >= 2 && s[0] == "0"
    s.to_i(8)
  elsif s[0] == "'"  || s[0] == '"'
    s.length > 1 ? s[1].ord : 0
  else
    s.to_i
  end
end

def to_float(s)
  s = s.strip
  return 0.0 if s == ""
  s.to_f
end

def format_int(n, spec, width, prec, flags)
  # spec: d/i/o/u/x/X
  negative = n < 0
  n = n.abs if negative
  s = if spec == "o"
    n.to_s(8)
  elsif spec == "x"
    n.to_s(16)
  elsif spec == "X"
    n.to_s(16).upcase
  else
    n.to_s
  end
  # precision: minimum digits
  if !prec.nil? && s.length < prec
    s = "0" * (prec - s.length) + s
  end
  # sign/prefix
  prefix = ""
  if negative
    prefix = "-"
  elsif flags.include?("+")
    prefix = "+"
  elsif flags.include?(" ")
    prefix = " "
  end
  if flags.include?("#")
    prefix = "0" + prefix if spec == "o" && s[0] != "0"
    prefix = "0x" + prefix if spec == "x"
    prefix = "0X" + prefix if spec == "X"
  end
  result = prefix + s
  if !width.nil? && result.length < width
    if flags.include?("-")
      result = result + " " * (width - result.length)
    elsif flags.include?("0") && prec.nil?
      result = prefix + "0" * (width - result.length) + s
    else
      result = " " * (width - result.length) + result
    end
  end
  result
end

def format_float(n, spec, width, prec, flags)
  prec_val = prec.nil? ? 6 : prec
  s = if spec == "e" || spec == "E"
    format_exp(n, prec_val, spec == "E")
  elsif spec == "g" || spec == "G"
    format_g(n, prec_val, spec == "G")
  else
    format_fixed_f(n, prec_val)
  end
  if n >= 0 && flags.include?("+")
    s = "+" + s
  elsif n >= 0 && flags.include?(" ")
    s = " " + s
  end
  if !width.nil? && s.length < width
    if flags.include?("-")
      s = s + " " * (width - s.length)
    elsif flags.include?("0")
      # pad with zeros after sign
      if s[0] == "-" || s[0] == "+" || s[0] == " "
        s = s[0] + "0" * (width - s.length) + s[1, s.length - 1]
      else
        s = "0" * (width - s.length) + s
      end
    else
      s = " " * (width - s.length) + s
    end
  end
  s
end

def format_fixed_f(n, prec)
  negative = n < 0
  n = n.abs
  int_part = n.to_i
  frac = n - int_part
  s = int_part.to_s
  if prec > 0
    # multiply frac by 10^prec and round
    factor = 1
    prec.times { factor *= 10 }
    frac_int = (frac * factor + 0.5).to_i
    if frac_int >= factor
      s = (int_part + 1).to_s
      frac_int = 0
    end
    frac_str = frac_int.to_s
    while frac_str.length < prec
      frac_str = "0" + frac_str
    end
    s = s + "." + frac_str
  end
  negative ? "-" + s : s
end

def format_exp(n, prec, upper)
  negative = n < 0
  n = n.abs
  exp = 0
  if n == 0.0
    exp = 0
  elsif n >= 10.0
    while n >= 10.0
      n /= 10.0
      exp += 1
    end
  elsif n > 0.0 && n < 1.0
    while n < 1.0
      n *= 10.0
      exp -= 1
    end
  end
  mantissa = format_fixed_f(n, prec)
  exp_str = exp.abs.to_s
  exp_str = "0" + exp_str if exp_str.length < 2
  e_char = upper ? "E" : "e"
  sign = exp >= 0 ? "+" : "-"
  result = mantissa + e_char + sign + exp_str
  negative ? "-" + result : result
end

def format_g(n, prec, upper)
  prec = 1 if prec == 0
  # choose e or f based on magnitude
  neg = n < 0
  abs_n = n.abs
  exp = 0
  if abs_n >= 10.0
    tmp = abs_n
    while tmp >= 10.0; tmp /= 10.0; exp += 1; end
  elsif abs_n > 0.0 && abs_n < 1.0
    tmp = abs_n
    while tmp < 1.0; tmp *= 10.0; exp -= 1; end
  end
  if exp < -4 || exp >= prec
    format_exp(n, prec - 1, upper)
  else
    format_fixed_f(n, prec - 1 - exp)
  end
end

def format_string(s, width, prec, flags)
  s = s[0, prec] if !prec.nil? && s.length > prec
  if !width.nil? && s.length < width
    if flags.include?("-")
      s = s + " " * (width - s.length)
    else
      s = " " * (width - s.length) + s
    end
  end
  s
end

# Parse one conversion specifier starting at fmt[i] (after the '%').
# Returns [formatted_string, new_i, arg_consumed].
def apply_spec(fmt, i, arg)
  flags = ""
  while i < fmt.length && "-+ 0#".include?(fmt[i])
    flags += fmt[i]; i += 1
  end
  # width
  width = nil
  if i < fmt.length && "0123456789".include?(fmt[i])
    w = ""
    while i < fmt.length && "0123456789".include?(fmt[i])
      w += fmt[i]; i += 1
    end
    width = w.to_i
  end
  # precision
  prec = nil
  if i < fmt.length && fmt[i] == "."
    i += 1
    p = ""
    while i < fmt.length && "0123456789".include?(fmt[i])
      p += fmt[i]; i += 1
    end
    prec = p == "" ? 0 : p.to_i
  end
  return ["%", i, false] if i >= fmt.length

  spec = fmt[i]; i += 1
  result = if spec == "%"
    "%"
  elsif spec == "s"
    format_string(arg.to_s, width, prec, flags)
  elsif spec == "b"
    interpret_escapes(arg.to_s)
  elsif spec == "c"
    s = arg.to_s
    s.length > 0 ? s[0] : "\0"
  elsif spec == "d" || spec == "i"
    format_int(to_int(arg.to_s), "d", width, prec, flags)
  elsif spec == "u"
    format_int(to_int(arg.to_s).abs, "d", width, prec, flags)
  elsif spec == "o"
    format_int(to_int(arg.to_s), "o", width, prec, flags)
  elsif spec == "x"
    format_int(to_int(arg.to_s), "x", width, prec, flags)
  elsif spec == "X"
    format_int(to_int(arg.to_s), "X", width, prec, flags)
  elsif spec == "f"
    format_float(to_float(arg.to_s), "f", width, prec, flags)
  elsif spec == "e"
    format_float(to_float(arg.to_s), "e", width, prec, flags)
  elsif spec == "E"
    format_float(to_float(arg.to_s), "E", width, prec, flags)
  elsif spec == "g"
    format_float(to_float(arg.to_s), "g", width, prec, flags)
  elsif spec == "G"
    format_float(to_float(arg.to_s), "G", width, prec, flags)
  else
    STDERR.puts "printf: invalid conversion specifier '%#{spec}'"
    exit 1
  end
  consumed = (spec != "%")
  [result, i, consumed]
end

# Apply FORMAT to a slice of ARGS starting at arg_index.
# Returns [output_string, args_consumed_count].
def apply_format(fmt, args, arg_start)
  fmt = interpret_escapes(fmt)
  output = ""
  arg_idx = arg_start
  i = 0
  while i < fmt.length
    if fmt[i] == "%"
      i += 1
      arg = arg_idx < args.length ? args[arg_idx] : ""
      str, i, consumed = apply_spec(fmt, i, arg)
      output = output + str
      arg_idx += 1 if consumed
    else
      output = output + fmt[i]; i += 1
    end
  end
  [output, arg_idx - arg_start]
end

fmt_string = ARGV[0]
args = ARGV[1, ARGV.length - 1]

if args.nil?
  args = []
end

# GNU printf repeats the format if there are more args than specifiers.
arg_pos = 0
loop do
  output, consumed = apply_format(fmt_string, args, arg_pos)
  STDOUT.write(output)
  break if consumed == 0 || arg_pos + consumed >= args.length
  arg_pos += consumed
end
