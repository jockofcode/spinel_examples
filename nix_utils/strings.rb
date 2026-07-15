# strings.rb, print printable character sequences in files (GNU strings, Spinel).
#
# Scans each FILE (or stdin) for sequences of printable characters at least
# MIN_LEN long and prints them. Useful for examining binary files.
#
# Flags:
#   -n MIN, --bytes=MIN  minimum sequence length (default 4)
#   -t RADIX, --radix=RADIX  print offset in given base: d/o/x (decimal/octal/hex)
#   -o              shorthand for -t o (GNU compat)
#   -a, --all       scan the whole file (default; kept for compat)
#   -e ENCODING     character encoding: s=single-byte (default), b=big16, l=little16
#   --help          usage
#
# Only the single-byte encoding (-e s) is implemented here; -e b/l are accepted
# but treated as single-byte for simplicity.
#
# Compile: spinel nix_utils/strings.rb -o nix_utils/bin/strings
# Run:
#   ./bin/strings binary_file
#   ./bin/strings -n 6 -t x file
#
# Core Ruby only; no require gate needed.

USAGE = "Usage: strings [OPTION]... FILE...\n" \
        "Print sequences of printable characters at least 4 (or MIN) long.\n" \
        "With no FILE, read standard input.\n" \
        "  -n MIN, --bytes=MIN   minimum sequence length (default 4)\n" \
        "  -t RADIX              print file offset (d=decimal, o=octal, x=hex)\n" \
        "  -o                    print octal offset (same as -t o)\n" \
        "  -a, --all             scan entire file (default)\n" \
        "  -e ENCODING           character encoding (only s/single-byte supported)\n" \
        "  --help"

PRINTABLE_RE = Regexp.new("[ -~]")  # ASCII 0x20–0x7E

class StringsOptions
  attr_accessor :min_len, :radix, :all_sections
  def initialize
    @min_len      = 4
    @radix        = nil  # nil = no offset
    @all_sections = true
  end
end

def parse_argv(argv)
  opts = StringsOptions.new
  files = []
  index = 0
  options_done = false

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

    if arg == "-a" || arg == "--all" || arg == "--data"
      opts.all_sections = true
      index += 1
      next
    end

    if arg == "-o"
      opts.radix = "o"
      index += 1
      next
    end

    if arg == "-t" || arg == "--radix"
      index += 1
      opts.radix = argv[index]
      index += 1
      next
    end

    if arg.length > 3 && arg[0, 3] == "-t "
      opts.radix = arg[3, arg.length - 3]
      index += 1
      next
    end

    if arg.length > 9 && arg[0, 9] == "--radix="
      opts.radix = arg[9, arg.length - 9]
      index += 1
      next
    end

    if arg == "-n" || arg == "--bytes"
      index += 1
      opts.min_len = argv[index].to_i
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-n"
      opts.min_len = arg[2, arg.length - 2].to_i
      index += 1
      next
    end

    if arg.length > 8 && arg[0, 8] == "--bytes="
      opts.min_len = arg[8, arg.length - 8].to_i
      index += 1
      next
    end

    if arg == "-e" || arg == "--encoding"
      index += 1
      # accept encoding flag but only support single-byte
      index += 1
      next
    end

    if arg.length > 2 && arg[0, 2] == "-e"
      # accept, ignore encoding
      index += 1
      next
    end

    STDERR.puts "strings: invalid option -- '#{arg}'"
    STDERR.puts "Try 'strings --help' for more information."
    exit 1
  end

  [opts, files]
end

def format_offset(off, radix)
  return "" if radix.nil?
  s = if radix == "d"
    off.to_s
  elsif radix == "o"
    # convert to octal string
    n = off
    return "0" if n == 0
    digits = ""
    while n > 0
      digits = (n % 8).to_s + digits
      n /= 8
    end
    digits
  elsif radix == "x"
    # convert to hex string
    n = off
    return "0" if n == 0
    hex_chars = "0123456789abcdef"
    digits = ""
    while n > 0
      digits = hex_chars[n % 16] + digits
      n /= 16
    end
    digits
  else
    off.to_s
  end
  s + " "
end

def process_content(content, opts)
  current = ""
  offset_start = 0
  pos = 0

  content.bytes.each do |byte|
    ch = byte.chr
    if PRINTABLE_RE.match(ch)
      offset_start = pos if current.length == 0
      current += ch
    else
      if current.length >= opts.min_len
        prefix = format_offset(offset_start, opts.radix)
        puts prefix + current
      end
      current = ""
    end
    pos += 1
  end
  # flush remaining sequence
  if current.length >= opts.min_len
    prefix = format_offset(offset_start, opts.radix)
    puts prefix + current
  end
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "strings: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  content = (name == "-") ? STDIN.read : File.read(name)
  process_content(content, opts)
end

exit exit_code
