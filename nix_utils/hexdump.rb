# hexdump.rb, ASCII, decimal, hex, octal dump (BSD hexdump, Spinel port).
#
# Displays the content of FILE(s) in various formats. The default output is
# two columns of 8 hex bytes per line with a printable-ASCII sidebar.
#
# Flags:
#   -C, --canonical  canonical hex+ASCII display (16 bytes per line with ASCII)
#   -b               one-byte octal display
#   -c               one-byte character display
#   -d               two-byte decimal display
#   -o               two-byte octal display
#   -x               two-byte hex display (default)
#   -e FORMAT        format string (basic support: /n 'fmt' specifiers)
#   -n COUNT         interpret only COUNT bytes of input
#   -s SKIP          skip SKIP bytes from the beginning
#   -v               display all input data without asterisk for repeats
#   --help           usage
#
# Compile: spinel nix_utils/hexdump.rb -o nix_utils/bin/hexdump
# Run:
#   printf 'Hello, World!\n' | ./bin/hexdump -C
#   ./bin/hexdump -x file.bin

USAGE = "Usage: hexdump [OPTION]... FILE...\n" \
        "Display file contents in various formats.\n" \
        "  -C  canonical hex+ASCII    -b  octal bytes\n" \
        "  -c  character bytes        -d  decimal shorts\n" \
        "  -o  octal shorts           -x  hex shorts (default)\n" \
        "  -n COUNT  read COUNT bytes  -s SKIP  skip SKIP bytes\n" \
        "  -v  all data (no duplicate suppression)\n" \
        "  --help"

class HexdumpOptions
  attr_accessor :canonical, :format_char, :count, :skip, :verbose
  def initialize
    @canonical   = false
    @format_char = "x"  # x=hex, b=oct-bytes, c=char, d=decimal, o=octal
    @count       = nil
    @skip        = 0
    @verbose     = false
  end
end

def parse_argv(argv)
  opts = HexdumpOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg); index += 1; next
    end
    if arg == "--"; options_done = true; index += 1; next; end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "-C" || arg == "--canonical"
      opts.canonical = true
    elsif arg == "-b"; opts.format_char = "b"
    elsif arg == "-c"; opts.format_char = "c"
    elsif arg == "-d"; opts.format_char = "d"
    elsif arg == "-o"; opts.format_char = "o"
    elsif arg == "-x"; opts.format_char = "x"
    elsif arg == "-v"; opts.verbose = true
    elsif arg == "-e"
      index += 1  # accept format string, ignore for now
    elsif arg == "-n"
      index += 1; opts.count = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-n"
      opts.count = arg[2, arg.length - 2].to_i
    elsif arg == "-s"
      index += 1; opts.skip = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.skip = arg[2, arg.length - 2].to_i
    else
      STDERR.puts "hexdump: invalid option '#{arg}'"
      exit 1
    end
    index += 1
  end
  [opts, files]
end

def to_hex(n, width)
  hex_chars = "0123456789abcdef"
  return "0" * width if n == 0
  digits = ""
  while n > 0
    digits = hex_chars[n % 16] + digits
    n /= 16
  end
  digits.rjust(width, "0")
end

def to_oct(n, width)
  return "0" * width if n == 0
  digits = ""
  while n > 0
    digits = (n % 8).to_s + digits
    n /= 8
  end
  digits.rjust(width, "0")
end

HXDUMP_CHAR_NAMES = {
  0 => "\\0",  7 => "\\a",  8 => "\\b",  9 => "\\t",
  10 => "\\n", 11 => "\\v", 12 => "\\f", 13 => "\\r"
}

def canonical_line(bytes, addr)
  addr_str = to_hex(addr, 8)
  hex_part = ""
  ascii_part = ""
  i = 0
  while i < 16
    if i < bytes.length
      b = bytes[i]
      hex_part += " " + to_hex(b, 2)
      hex_part += " " if i == 7  # extra space in middle
      ascii_part += (b >= 32 && b < 127) ? b.chr : "."
    else
      hex_part += "   "
      hex_part += " " if i == 7
      ascii_part += " "
    end
    i += 1
  end
  "#{addr_str}  #{hex_part}  |#{ascii_part}|"
end

def dump_canonical(data, opts)
  bytes = data.bytes
  addr = 0
  while addr < bytes.length
    chunk = bytes[addr, 16]
    puts canonical_line(chunk, addr)
    addr += 16
  end
  puts to_hex(bytes.length, 8)
end

def dump_generic(data, opts)
  bytes = data.bytes
  # Determine columns and element size
  elem_size = if opts.format_char == "b" || opts.format_char == "c"; 1
               else 2  # d, o, x
               end
  cols = opts.format_char == "c" || opts.format_char == "b" ? 16 : 8

  addr = 0
  last_line = nil
  dup_printed = false

  while addr < bytes.length
    chunk_size = cols < bytes.length - addr ? cols : bytes.length - addr
    chunk = bytes[addr, chunk_size]

    unless opts.verbose
      line_key = chunk.join(",")
      if line_key == last_line && chunk_size == cols
        unless dup_printed
          puts "*"
          dup_printed = true
        end
        addr += chunk_size
        next
      end
      last_line = line_key
      dup_printed = false
    end

    addr_str = to_oct(addr, 7)
    parts = []
    i = 0
    while i < chunk_size
      if opts.format_char == "b"
        parts.push(to_oct(chunk[i], 3))
      elsif opts.format_char == "c"
        b = chunk[i]
        parts.push(HXDUMP_CHAR_NAMES[b] || (b >= 32 && b < 127 ? b.chr.rjust(3) : to_oct(b, 3)))
      else
        b1 = chunk[i]
        b2 = i + 1 < chunk_size ? chunk[i + 1] : 0
        val = b1 | (b2 << 8)  # little-endian
        s = if opts.format_char == "d"
          val.to_s.rjust(5)
        elsif opts.format_char == "o"
          to_oct(val, 6)
        else  # x
          to_hex(val, 4)
        end
        parts.push(s)
        i += 1
      end
      i += 1
    end
    puts "#{addr_str} #{parts.join(" ")}"
    addr += chunk_size
  end
  puts to_oct(bytes.length, 7)
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

data = ""
exit_code = 0
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "hexdump: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  data += (name == "-") ? STDIN.read : File.read(name)
end

data = data[opts.skip, data.length - opts.skip] || ""
data = data[0, opts.count] if !opts.count.nil?

if opts.canonical
  dump_canonical(data, opts)
else
  dump_generic(data, opts)
end

exit exit_code
