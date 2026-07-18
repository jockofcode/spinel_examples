# split.rb, split a file into pieces (GNU split, Spinel port).
#
# Flags:
#   -a N, --suffix-length=N       suffix length (default 2)
#   --additional-suffix=SUFFIX    extra suffix after generated suffix
#   -b SIZE, --bytes=SIZE         SIZE bytes per output file
#   -C SIZE, --line-bytes=SIZE    at most SIZE bytes per file, whole lines
#   -d, --numeric-suffixes[=FROM] numeric suffixes (default alpha)
#   -x, --hex-suffixes[=FROM]     hex suffixes
#   -e, --elide-empty-files       skip empty output files (with -n)
#   -l N, --lines=N               N lines per output file (default 1000)
#   -n CHUNKS, --number=CHUNKS    split into CHUNKS files
#   -t SEP, --separator=SEP       record separator (NUL not supported)
#   --verbose                     print filename before opening
#   --help, --version
#
# Skip: --filter=COMMAND (subprocess), -u/--unbuffered
#
# Compile: spinel nix_utils/split.rb -o nix_utils/bin/split

USAGE = "Usage: split [OPTION]... [FILE [PREFIX]]\n" \
        "Output pieces of FILE to PREFIXaa, PREFIXab, ...; default PREFIX is 'x'.\n" \
        "  -l N          lines per file (default 1000)\n" \
        "  -b SIZE       bytes per file (K/M/G suffixes ok)\n" \
        "  -C SIZE       bytes per file keeping lines whole\n" \
        "  -n CHUNKS     split into N chunks\n" \
        "  -d [FROM]     numeric suffixes   -x [FROM]  hex suffixes\n" \
        "  -a N          suffix length (default 2)\n" \
        "  --additional-suffix=SUFF  extra suffix after generated suffix\n" \
        "  -e            elide empty files   -t SEP  record separator\n" \
        "  --verbose     print filename before opening\n" \
        "  --help    --version"

VERSION = "split (nix_utils) 1.0"

require_relative "nix_helpers"

class SplitOptions
  attr_accessor :suffix_len, :add_suffix, :mode, :count
  attr_accessor :numeric_from, :hex_from, :elide_empty, :verbose
  attr_accessor :separator
  def initialize
    @suffix_len  = 2
    @add_suffix  = ""
    @mode        = :lines
    @count       = 1000   # lines default
    @numeric_from = nil   # nil = alpha
    @hex_from    = nil
    @elide_empty = false
    @verbose     = false
    @separator   = "\n"
  end
end

opts         = SplitOptions.new
file         = nil
prefix       = "x"
options_done = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done
    if file.nil?; file = arg
    else; prefix = arg; end
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-l" || arg == "--lines"
    index += 1; opts.mode = :lines; opts.count = coerce(ARGV[index]).to_i
  elsif arg.length > 2 && arg[0, 2] == "-l"
    opts.mode = :lines; opts.count = arg[2, arg.length - 2].to_i
  elsif arg.length > 8 && arg[0, 8] == "--lines="
    opts.mode = :lines; opts.count = arg[8, arg.length - 8].to_i
  elsif arg == "-b" || arg == "--bytes"
    index += 1; opts.mode = :bytes; opts.count = parse_size_suffix(coerce(ARGV[index]))
  elsif arg.length > 2 && arg[0, 2] == "-b"
    opts.mode = :bytes; opts.count = parse_size_suffix(arg[2, arg.length - 2])
  elsif arg.length > 8 && arg[0, 8] == "--bytes="
    opts.mode = :bytes; opts.count = parse_size_suffix(arg[8, arg.length - 8])
  elsif arg == "-C" || arg == "--line-bytes"
    index += 1; opts.mode = :line_bytes; opts.count = parse_size_suffix(coerce(ARGV[index]))
  elsif arg.length > 2 && arg[0, 2] == "-C"
    opts.mode = :line_bytes; opts.count = parse_size_suffix(arg[2, arg.length - 2])
  elsif arg.length > 13 && arg[0, 13] == "--line-bytes="
    opts.mode = :line_bytes; opts.count = parse_size_suffix(arg[13, arg.length - 13])
  elsif arg == "-n" || arg == "--number"
    index += 1; opts.mode = :number; opts.count = coerce(ARGV[index]).to_i
  elsif arg.length > 2 && arg[0, 2] == "-n"
    opts.mode = :number; opts.count = arg[2, arg.length - 2].to_i
  elsif arg.length > 9 && arg[0, 9] == "--number="
    opts.mode = :number; opts.count = arg[9, arg.length - 9].to_i
  elsif arg == "-a" || arg == "--suffix-length"
    index += 1; opts.suffix_len = coerce(ARGV[index]).to_i
  elsif arg.length > 2 && arg[0, 2] == "-a"
    opts.suffix_len = arg[2, arg.length - 2].to_i
  elsif arg.length > 16 && arg[0, 16] == "--suffix-length="
    opts.suffix_len = arg[16, arg.length - 16].to_i
  elsif arg.length > 19 && arg[0, 19] == "--additional-suffix="
    opts.add_suffix = arg[19, arg.length - 19]
  elsif arg == "-d"
    opts.numeric_from = 0
  elsif arg.length > 2 && arg[0, 2] == "-d"
    opts.numeric_from = arg[2, arg.length - 2].to_i
  elsif arg == "--numeric-suffixes"
    opts.numeric_from = 0
  elsif arg.length > 19 && arg[0, 19] == "--numeric-suffixes="
    opts.numeric_from = arg[19, arg.length - 19].to_i
  elsif arg == "-x"
    opts.hex_from = 0
  elsif arg.length > 2 && arg[0, 2] == "-x"
    opts.hex_from = arg[2, arg.length - 2].to_i
  elsif arg == "--hex-suffixes"
    opts.hex_from = 0
  elsif arg.length > 15 && arg[0, 15] == "--hex-suffixes="
    opts.hex_from = arg[15, arg.length - 15].to_i
  elsif arg == "-e" || arg == "--elide-empty-files"
    opts.elide_empty = true
  elsif arg == "--verbose"
    opts.verbose = true
  elsif arg == "-t" || arg == "--separator"
    index += 1
    sv = coerce(ARGV[index])
    opts.separator = sv
  elsif arg.length > 12 && arg[0, 12] == "--separator="
    opts.separator = arg[12, arg.length - 12]
  elsif arg.length > 2 && arg[0, 2] == "-t"
    opts.separator = arg[2, arg.length - 2]
  elsif arg[0] != "-"
    if file.nil?; file = arg
    else; prefix = arg; end
  else
    die("split: invalid option -- '#{arg}'\nTry 'split --help' for more information.")
  end
  index += 1
end

content = file.nil? ? STDIN.read : read_source(file)

def make_suffix(idx, opts)
  len = opts.suffix_len
  if !opts.hex_from.nil?
    n = (opts.hex_from || 0) + idx
    s = n.to_s(16)
    while s.length < len
      s = "0" + s
    end
    return s
  elsif !opts.numeric_from.nil?
    n = (opts.numeric_from || 0) + idx
    s = n.to_s
    while s.length < len
      s = "0" + s
    end
    return s
  else
    # Base-26 alpha suffix
    s = ""
    n = idx
    len.times do
      s = ("a".ord + (n % 26)).chr + s
      n = n / 26
    end
    return s
  end
end

def write_chunk(prefix, suffix_idx, data, opts)
  suf  = make_suffix(suffix_idx, opts)
  name = ("" + prefix) + suf + ("" + opts.add_suffix)
  if opts.elide_empty && data == ""
    return suffix_idx
  end
  STDERR.puts "creating file '#{name}'" if opts.verbose
  File.open(name, "w") { |f| f.write(data) }
  suffix_idx + 1
end

sep   = "" + opts.separator
pref  = "" + prefix
sidx  = 0

case opts.mode
when :lines
  records = content.split(sep, -1)
  records.pop if !records.empty? && ("" + records.last) == ""
  i = 0
  while i < records.length
    chunk_lines = []
    n = 0
    while n < opts.count && i + n < records.length
      chunk_lines.push("" + records[i + n])
      n += 1
    end
    chunk = chunk_lines.join(sep) + (chunk_lines.empty? ? "" : sep)
    sidx = write_chunk(pref, sidx, chunk, opts)
    i += opts.count
  end

when :bytes
  total = content.bytesize
  i     = 0
  while i < total
    chunk_end = i + opts.count
    chunk_end = total if chunk_end > total
    chunk = content[i, chunk_end - i]
    sidx  = write_chunk(pref, sidx, chunk, opts)
    i += opts.count
  end

when :line_bytes
  records = content.split(sep, -1)
  records.pop if !records.empty? && ("" + records.last) == ""
  current = ""
  records.each do |rec|
    r      = "" + rec
    line   = r + sep
    needed = current.bytesize + line.bytesize
    if needed > opts.count && current != ""
      sidx    = write_chunk(pref, sidx, current, opts)
      current = ""
    end
    current += line
  end
  sidx = write_chunk(pref, sidx, current, opts) if current != ""

when :number
  n     = opts.count
  n     = 1 if n < 1
  total = content.bytesize
  size  = (total + n - 1) / n
  size  = 1 if size < 1
  i     = 0
  while i < n
    chunk_start = i * size
    break if chunk_start >= total
    chunk_end = chunk_start + size
    chunk_end = total if chunk_end > total
    chunk = content[chunk_start, chunk_end - chunk_start]
    sidx  = write_chunk(pref, sidx, chunk, opts)
    i += 1
  end
end
