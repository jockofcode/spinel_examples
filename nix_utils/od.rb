# od.rb, dump files in octal and other formats (GNU od, Spinel port).
#
# Dumps each FILE (or stdin) as a sequence of formatted bytes. The default
# output is octal (base 8) two-byte integers. Addresses are printed in octal
# by default.
#
# Flags:
#   -A RADIX, --address-radix=RADIX  d/o/x/n for decimal/octal/hex/none
#   -j SKIP, --skip-bytes=SKIP       skip SKIP bytes before dumping
#   -N COUNT, --read-bytes=COUNT     dump at most COUNT bytes
#   -t TYPE, --format=TYPE           output format type(s); see below
#   -v, --output-duplicates          don't suppress duplicate lines
#   -w [N], --width[=N]              bytes per output line (default 16)
#   Short forms:
#     -b   octal bytes         (same as -t o1)
#     -c   named/printable chars (same as -t c)
#     -d   unsigned decimal    (same as -t u2)
#     -o   octal shorts        (same as -t o2, default)
#     -x   hex shorts          (same as -t x2)
#     -s   decimal shorts      (same as -t d2)
#     -i   decimal ints        (same as -t d4)
#   --help  usage
#
# TYPE string characters:
#   a  named character      c  printable char / escape
#   d[SIZE]  signed decimal  o[SIZE]  octal  u[SIZE]  unsigned decimal
#   x[SIZE]  hex             f[SIZE]  float (4=float, 8=double)
#   SIZE: 1 2 4 8 (bytes); default 2 for integer types
#
# Compile: spinel nix_utils/od.rb -o nix_utils/bin/od
# Run:
#   ./bin/od file.bin
#   printf 'ABC\n' | ./bin/od -c
#   printf 'ABC\n' | ./bin/od -A x -t x1z
#
# Core Ruby only; no require gate needed.

USAGE = "Usage: od [OPTION]... [FILE]...\n" \
        "  or:  od [--address-radix=RADIX] [--read-bytes=BYTES] [--skip-bytes=BYTES]\n" \
        "       [--format=TYPE]... [FILE]... [(+)][OFFSET[.][b]]\n" \
        "Dump files in octal (and other) formats.\n" \
        "  -A RADIX  address radix: d/o/x/n  (default o)\n" \
        "  -j BYTES  skip BYTES before dumping\n" \
        "  -N COUNT  dump at most COUNT bytes\n" \
        "  -t TYPE   format: a c d[N] o[N] u[N] x[N] (can repeat)\n" \
        "  -v        do not suppress duplicate output lines\n" \
        "  -w N      bytes per line (default 16)\n" \
        "  -b/-c/-d/-o/-x/-s/-i  format shortcuts\n" \
        "  --help"

class OdFormat
  attr_accessor :type, :size
  def initialize(type, size)
    @type = type
    @size = size
  end
end

class OdOptions
  attr_accessor :addr_radix, :skip, :count, :formats, :verbose, :width, :big_endian
  def initialize
    @addr_radix = "o"
    @skip       = 0
    @count      = nil
    @formats    = []
    @verbose    = false
    @width      = 16
    @big_endian = false
    @formats.push(OdFormat.new("o", 2))
    @formats.pop
  end
end

def parse_type_string(spec, opts)
  i = 0
  while i < spec.length
    type_ch = spec[i]; i += 1
    size = nil
    if i < spec.length && "12348".include?(spec[i])
      size = spec[i].to_i; i += 1
    end
    if type_ch == "a"
      opts.formats.push(OdFormat.new("a", 1))
    elsif type_ch == "c"
      opts.formats.push(OdFormat.new("c", 1))
    elsif type_ch == "d"
      opts.formats.push(OdFormat.new("d", size || 2))
    elsif type_ch == "o"
      opts.formats.push(OdFormat.new("o", size || 2))
    elsif type_ch == "u"
      opts.formats.push(OdFormat.new("u", size || 2))
    elsif type_ch == "x"
      opts.formats.push(OdFormat.new("x", size || 2))
    elsif type_ch == "f"
      opts.formats.push(OdFormat.new("f", size || 4))
    elsif type_ch == "z"
      # -tz: ASCII chars after hex dump (GNU extension); treat as no-op for now
    else
      STDERR.puts "od: invalid type string '#{spec}'"
      exit 1
    end
  end
end

def parse_size_arg(s)
  # handle b=512, kB=1000, K/KiB=1024, MB=1000^2, M/MiB=1024^2, GB, G/GiB
  if s.end_with?("KiB") then s[0, s.length - 3].to_i * 1024
  elsif s.end_with?("MiB") then s[0, s.length - 3].to_i * 1024 * 1024
  elsif s.end_with?("GiB") then s[0, s.length - 3].to_i * 1024 * 1024 * 1024
  elsif s.end_with?("kB") || s.end_with?("KB") then s[0, s.length - 2].to_i * 1000
  elsif s.end_with?("MB") then s[0, s.length - 2].to_i * 1000 * 1000
  elsif s.end_with?("GB") then s[0, s.length - 2].to_i * 1000 * 1000 * 1000
  elsif s.end_with?("K") then s[0, s.length - 1].to_i * 1024
  elsif s.end_with?("M") then s[0, s.length - 1].to_i * 1024 * 1024
  elsif s.end_with?("G") then s[0, s.length - 1].to_i * 1024 * 1024 * 1024
  elsif s.end_with?("b") then s[0, s.length - 1].to_i * 512
  else s.to_i
  end
end

def parse_argv(argv)
  opts = OdOptions.new
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
    if arg == "-v" || arg == "--output-duplicates"
      opts.verbose = true
    elsif arg == "-a"
      opts.formats.push(OdFormat.new("a", 1))
    elsif arg == "-b"
      opts.formats.push(OdFormat.new("o", 1))
    elsif arg == "-c"
      opts.formats.push(OdFormat.new("c", 1))
    elsif arg == "-d"
      opts.formats.push(OdFormat.new("u", 2))
    elsif arg == "-f"
      opts.formats.push(OdFormat.new("f", 4))
    elsif arg == "-l"
      opts.formats.push(OdFormat.new("d", 8))
    elsif arg == "-o"
      opts.formats.push(OdFormat.new("o", 2))
    elsif arg == "-x"
      opts.formats.push(OdFormat.new("x", 2))
    elsif arg == "-s"
      opts.formats.push(OdFormat.new("d", 2))
    elsif arg == "-i"
      opts.formats.push(OdFormat.new("d", 4))
    elsif arg == "--endian=big"
      opts.big_endian = true
    elsif arg == "--endian=little"
      opts.big_endian = false
    elsif arg == "-A" || arg == "--address-radix"
      index += 1
      opts.addr_radix = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-A"
      opts.addr_radix = arg[2, arg.length - 2]
    elsif arg.length > 16 && arg[0, 16] == "--address-radix="
      opts.addr_radix = arg[16, arg.length - 16]
    elsif arg == "-j" || arg == "--skip-bytes"
      index += 1
      opts.skip = parse_size_arg(argv[index])
    elsif arg.length > 2 && arg[0, 2] == "-j"
      opts.skip = parse_size_arg(arg[2, arg.length - 2])
    elsif arg.length > 13 && arg[0, 13] == "--skip-bytes="
      opts.skip = parse_size_arg(arg[13, arg.length - 13])
    elsif arg == "-N" || arg == "--read-bytes"
      index += 1
      opts.count = parse_size_arg(argv[index])
    elsif arg.length > 2 && arg[0, 2] == "-N"
      opts.count = parse_size_arg(arg[2, arg.length - 2])
    elsif arg.length > 13 && arg[0, 13] == "--read-bytes="
      opts.count = parse_size_arg(arg[13, arg.length - 13])
    elsif arg == "-t" || arg == "--format"
      index += 1
      parse_type_string(argv[index], opts)
    elsif arg.length > 2 && arg[0, 2] == "-t"
      parse_type_string(arg[2, arg.length - 2], opts)
    elsif arg.length > 9 && arg[0, 9] == "--format="
      parse_type_string(arg[9, arg.length - 9], opts)
    elsif arg == "-w" || arg == "--width"
      if index + 1 < argv.length && "0123456789".include?(argv[index + 1][0])
        index += 1
        opts.width = argv[index].to_i
      else
        opts.width = 32
      end
    elsif arg.length > 2 && arg[0, 2] == "-w"
      opts.width = arg[2, arg.length - 2].to_i
    elsif arg.length > 8 && arg[0, 8] == "--width="
      opts.width = arg[8, arg.length - 8].to_i
    else
      STDERR.puts "od: invalid option '#{arg}'"
      STDERR.puts "Try 'od --help' for more information."
      exit 1
    end
    index += 1
  end
  [opts, files]
end

def format_addr(addr, radix)
  return "" if radix == "n"
  s = if radix == "d"
    addr.to_s
  elsif radix == "x"
    n = addr
    return "00000000" if n == 0
    hex_chars = "0123456789abcdef"
    digits = ""
    while n > 0; digits = hex_chars[n % 16] + digits; n /= 16; end
    digits
  else  # "o" (default)
    n = addr
    return "0000000" if n == 0
    digits = ""
    while n > 0; digits = (n % 8).to_s + digits; n /= 8; end
    digits
  end
  # Pad to 7 chars for octal, 8 for hex/dec
  pad = radix == "x" ? 8 : 7
  s.rjust(pad, "0")
end

NAMED_CHARS = {
  0 => "nul", 1 => "soh", 2 => "stx", 3 => "etx",
  4 => "eot", 5 => "enq", 6 => "ack", 7 => "bel",
  8 => "bs",  9 => "ht",  10 => "nl", 11 => "vt",
  12 => "ff", 13 => "cr", 14 => "so", 15 => "si",
  16 => "dle",17 => "dc1",18 => "dc2",19 => "dc3",
  20 => "dc4",21 => "nak",22 => "syn",23 => "etb",
  24 => "can",25 => "em", 26 => "sub",27 => "esc",
  28 => "fs", 29 => "gs", 30 => "rs", 31 => "us",
  32 => "sp", 127 => "del"
}

def format_byte_a(b)
  NAMED_CHARS[b] || b.chr
end

def format_byte_c(b)
  if b == 0;    "\\0"
  elsif b == 7; "\\a"
  elsif b == 8; "\\b"
  elsif b == 9; "\\t"
  elsif b == 10; "\\n"
  elsif b == 11; "\\v"
  elsif b == 12; "\\f"
  elsif b == 13; "\\r"
  elsif b == 92; "\\\\"
  elsif b >= 32 && b < 127; b.chr
  else
    # octal escape
    n = b
    d3 = (n % 8).to_s; n /= 8
    d2 = (n % 8).to_s; n /= 8
    d1 = n.to_s
    "\\" + d1 + d2 + d3
  end
end

def int_from_bytes(bytes, offset, size, signed, big_endian)
  val = 0
  i = 0
  while i < size && offset + i < bytes.length
    shift = big_endian ? (size - 1 - i) * 8 : i * 8
    val |= bytes[offset + i] << shift
    i += 1
  end
  if signed && size > 0
    max = 1 << (size * 8 - 1)
    val -= (1 << (size * 8)) if val >= max
  end
  val
end

def to_oct_str(n)
  return "0" if n == 0
  neg = n < 0
  n = n.abs
  digits = ""
  while n > 0; digits = (n % 8).to_s + digits; n /= 8; end
  neg ? "-" + digits : digits
end

def to_hex_str(n)
  return "0" if n == 0
  hex_chars = "0123456789abcdef"
  neg = n < 0
  n = n.abs
  digits = ""
  while n > 0; digits = hex_chars[n % 16] + digits; n /= 16; end
  neg ? "-" + digits : digits
end

def pow10(n)
  r = 1
  i = 0
  while i < n
    r *= 10
    i += 1
  end
  r
end

# Format a float in scientific notation with the given number of fractional
# digits, e.g. 1.0 -> "1.0000000e+00".
def format_sci(val, digits)
  neg = val < 0.0
  v = neg ? -val : val
  exp10 = 0
  if v != 0.0
    while v >= 10.0
      v /= 10.0; exp10 += 1
    end
    while v < 1.0
      v *= 10.0; exp10 -= 1
    end
  end
  scale = pow10(digits)
  r = (v * scale + 0.5).to_i
  if r >= 10 * scale
    r /= 10
    exp10 += 1
  end
  s = r.to_s
  while s.length < digits + 1
    s = "0" + s
  end
  intp = s[0, s.length - digits]
  frac = s[s.length - digits, digits]
  eabs = exp10 < 0 ? -exp10 : exp10
  estr = eabs.to_s
  estr = "0" + estr if estr.length < 2
  mant = digits > 0 ? intp + "." + frac : intp
  (neg ? "-" : "") + mant + "e" + (exp10 < 0 ? "-" : "+") + estr
end

# Decode IEEE-754 bits (4 or 8 bytes) into a formatted string.
def decode_float(bits, size)
  if size == 4
    sign = (bits >> 31) & 1
    exp  = (bits >> 23) & 255
    frac = bits & 8388607          # 2^23 - 1
    ebits = 255; bias = 127; fbits = 23
  else
    sign = (bits >> 63) & 1
    exp  = (bits >> 52) & 2047
    frac = bits & ((1 << 52) - 1)
    ebits = 2047; bias = 1023; fbits = 52
  end
  if exp == ebits
    return "nan" if frac != 0
    return sign == 1 ? "-inf" : "inf"
  end
  if exp == 0
    return sign == 1 ? "-0" : "0" if frac == 0
    val = (frac.to_f / (1 << fbits)) * (2.0 ** (1 - bias))
  else
    val = (1.0 + frac.to_f / (1 << fbits)) * (2.0 ** (exp - bias))
  end
  val = -val if sign == 1
  format_sci(val, size == 4 ? 7 : 16)
end

def format_chunk(bytes, offset, size, fmt, big_endian)
  width = if fmt.type == "a" || fmt.type == "c"; 3
           elsif fmt.size == 1 && fmt.type == "o"; 3
           elsif fmt.size == 1 && fmt.type == "x"; 2
           elsif fmt.size == 1; 3
           elsif fmt.size == 2 && fmt.type == "o"; 6
           elsif fmt.size == 2 && fmt.type == "x"; 4
           elsif fmt.size == 2; 5
           elsif fmt.size == 4 && fmt.type == "o"; 11
           elsif fmt.size == 4 && fmt.type == "x"; 8
           elsif fmt.size == 4; 10
           elsif fmt.size == 8 && fmt.type == "x"; 16
           else; 20
           end

  if fmt.type == "a"
    format_byte_a(bytes[offset]).rjust(width)
  elsif fmt.type == "c"
    format_byte_c(bytes[offset]).rjust(width)
  elsif fmt.type == "o"
    n = int_from_bytes(bytes, offset, fmt.size, false, big_endian)
    to_oct_str(n).rjust(width, "0")
  elsif fmt.type == "x"
    n = int_from_bytes(bytes, offset, fmt.size, false, big_endian)
    to_hex_str(n).rjust(width, "0")
  elsif fmt.type == "u"
    n = int_from_bytes(bytes, offset, fmt.size, false, big_endian)
    n.to_s.rjust(width)
  elsif fmt.type == "d"
    n = int_from_bytes(bytes, offset, fmt.size, true, big_endian)
    n.to_s.rjust(width)
  elsif fmt.type == "f"
    bits = int_from_bytes(bytes, offset, fmt.size, false, big_endian)
    fwidth = fmt.size == 4 ? 15 : 24
    decode_float(bits, fmt.size).rjust(fwidth)
  else
    "?"
  end
end

def dump_data(data, opts)
  bytes = data.bytes
  total = bytes.length
  addr = 0
  last_row = nil
  dup_printed = false
  addr_len = opts.addr_radix == "n" ? 0 : (opts.addr_radix == "x" ? 8 : 7)

  formats_to_use = opts.formats
  if formats_to_use.empty?
    formats_to_use = [OdFormat.new("o", 2)]
  end

  while addr < total
    chunk_size = opts.width < total - addr ? opts.width : total - addr
    row_bytes = []
    i = 0
    while i < chunk_size
      row_bytes.push(bytes[addr + i])
      i += 1
    end

    # Duplicate suppression
    unless opts.verbose
      row_str = row_bytes.join(",")
      if row_str == last_row && chunk_size == opts.width
        unless dup_printed
          puts "*"
          dup_printed = true
        end
        addr += chunk_size
        next
      end
      last_row = row_str
      dup_printed = false
    end

    addr_str = format_addr(addr, opts.addr_radix)
    first_line = true

    formats_to_use.each do |fmt|
      line = first_line ? addr_str : " " * addr_len
      first_line = false

      pos = 0
      while pos < row_bytes.length
        avail = row_bytes.length - pos
        take = fmt.size < avail ? fmt.size : avail
        padded = row_bytes[pos, take]
        while padded.length < fmt.size; padded.push(0); end
        line += " " + format_chunk(padded, 0, fmt.size, fmt, opts.big_endian)
        pos += fmt.size
      end
      puts line
    end

    addr += chunk_size
  end

  # Print final address
  puts format_addr(total, opts.addr_radix)
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

# Collect all input data
data = ""
exit_code = 0
files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "od: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  data = data + ((cname == "-") ? STDIN.read : File.read(cname))
end

# Apply -j skip and -N count
data = data[opts.skip, data.length - opts.skip] || ""
data = data[0, opts.count] if !opts.count.nil?

dump_data(data, opts)
exit exit_code
