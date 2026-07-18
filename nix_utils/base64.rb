# base64.rb, encode/decode base64 data (GNU base64, Spinel port).
#
# Flags:
#   -d, --decode            decode input
#   -i, --ignore-garbage    when decoding, ignore non-alphabet characters
#   -w COLS, --wrap=COLS    wrap encoded lines after COLS chars (default 76); 0 = no wrap
#   --help, --version
#
# Compile: spinel nix_utils/base64.rb -o nix_utils/bin/base64

USAGE = "Usage: base64 [OPTION]... [FILE]\n" \
        "Base64 encode or decode FILE, or standard input, to standard output.\n" \
        "  -d, --decode          decode data\n" \
        "  -i, --ignore-garbage  when decoding, ignore non-alphabetic characters\n" \
        "  -w COLS, --wrap=COLS  wrap encoded lines after COLS character columns (default 76)\n" \
        "                        use 0 to disable line wrapping\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit"

VERSION = "base64 (nix_utils) 1.0"

require "base64"
require_relative "nix_helpers"

decode_mode     = false
ignore_garbage  = false
wrap_cols       = 76
file            = nil
options_done    = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || arg == "-"
    file = arg
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-d" || arg == "--decode"
    decode_mode = true
  elsif arg == "-i" || arg == "--ignore-garbage"
    ignore_garbage = true
  elsif arg == "-w"
    index += 1
    wrap_cols = coerce(ARGV[index]).to_i
  elsif arg.length > 7 && arg[0, 7] == "--wrap="
    wrap_cols = arg[7, arg.length - 7].to_i
  elsif arg.length > 2 && arg[0, 2] == "-w"
    wrap_cols = arg[2, arg.length - 2].to_i
  elsif arg[0] != "-"
    file = arg
  else
    die("base64: invalid option -- '#{arg}'\nTry 'base64 --help' for more information.")
  end
  index += 1
end

data = file.nil? ? STDIN.read : read_source(file)

if decode_mode
  s = "" + data
  # Strip whitespace always; optionally strip non-base64 chars
  if ignore_garbage
    clean = ""
    i = 0
    while i < s.length
      c = s[i]
      if "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".include?(c)
        clean += c
      end
      i += 1
    end
    s = clean
  else
    # Remove whitespace only
    clean = ""
    i = 0
    while i < s.length
      c = s[i]
      clean += c unless c == "\n" || c == "\r" || c == " " || c == "\t"
      i += 1
    end
    s = clean
  end
  begin
    STDOUT.write(Base64.decode64(s))
  rescue => e
    die("base64: invalid input: #{e.message}")
  end
else
  encoded = Base64.strict_encode64(data)
  if wrap_cols == 0
    puts encoded
  else
    i = 0
    while i < encoded.length
      chunk_end = i + wrap_cols
      chunk_end = encoded.length if chunk_end > encoded.length
      puts encoded[i, chunk_end - i]
      i += wrap_cols
    end
  end
end
