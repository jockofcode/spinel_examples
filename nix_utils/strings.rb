# strings.rb, print printable character sequences in files (GNU strings, Spinel).
#
# Scans each FILE (or stdin) for sequences of printable characters at least
# MIN_LEN long and prints them. Useful for examining binary files.
#
# Flags:
#   -n MIN, --bytes=MIN  minimum sequence length (default 4)
#   -<NUMBER>            same as -n NUMBER (e.g. -6)
#   -t RADIX, --radix=RADIX  print offset in given base: d/o/x (decimal/octal/hex)
#   -o              shorthand for -t o (GNU compat)
#   -a, --all       scan the whole file (default; kept for compat)
#   -f, --print-file-name   print the file name before each string
#   -w, --include-all-whitespace  count tab/newline/etc. as part of a string
#   -s, --output-separator=SEP    separator between strings (default newline)
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
        "  -f, --print-file-name print the file name before each string\n" \
        "  -w, --include-all-whitespace  keep tab/newline inside strings\n" \
        "  -s, --output-separator=SEP    string separator (default newline)\n" \
        "  -e ENCODING           character encoding (only s/single-byte supported)\n" \
        "  --help"

PRINTABLE_RE = Regexp.new("[ -~]")  # ASCII 0x20–0x7E
WHITESPACE_BYTES = [9, 10, 11, 12, 13]  # \t \n \v \f \r

class StringsOptions
  attr_accessor :min_len, :radix, :all_sections, :print_filename, :include_ws, :separator
  def initialize
    @min_len        = 4
    @radix          = nil  # nil = no offset
    @all_sections   = true
    @print_filename = false
    @include_ws     = false
    @separator      = "\n"
  end
end

def all_digits?(s)
  return false if s == ""
  i = 0
  while i < s.length
    return false unless "0123456789".include?(s[i])
    i += 1
  end
  true
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

    if arg == "-f" || arg == "--print-file-name"
      opts.print_filename = true
      index += 1
      next
    end

    if arg == "-w" || arg == "--include-all-whitespace"
      opts.include_ws = true
      index += 1
      next
    end

    if arg == "-s" || arg == "--output-separator"
      index += 1
      opts.separator = argv[index]
      index += 1
      next
    end

    if arg.length > 19 && arg[0, 19] == "--output-separator="
      opts.separator = arg[19, arg.length - 19]
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

    # Historical form: -<NUMBER> is the same as -n NUMBER.
    if arg.length > 1 && all_digits?(arg[1, arg.length - 1])
      opts.min_len = arg[1, arg.length - 1].to_i
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

def printable_byte?(byte, opts)
  return true if byte >= 32 && byte <= 126
  return true if opts.include_ws && WHITESPACE_BYTES.include?(byte)
  false
end

def emit_string(start, str, opts, filename)
  line = ""
  line += "#{filename}: " if opts.print_filename
  line += format_offset(start, opts.radix)
  line += str
  STDOUT.write(line + opts.separator)
end

def process_content(content, opts, filename)
  current = ""
  offset_start = 0
  pos = 0

  content.bytes.each do |byte|
    if printable_byte?(byte, opts)
      offset_start = pos if current.length == 0
      current += byte.chr
    else
      emit_string(offset_start, current, opts, filename) if current.length >= opts.min_len
      current = ""
    end
    pos += 1
  end
  # flush remaining sequence
  emit_string(offset_start, current, opts, filename) if current.length >= opts.min_len
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "strings: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  content = (cname == "-") ? STDIN.read : File.read(cname)
  process_content(content, opts, cname)
end

exit exit_code
