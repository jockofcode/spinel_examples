# paste.rb, merge lines of files (GNU paste, Spinel port).
#
# Write lines from each FILE (or standard input for "-") side by side, joined
# by a tab character.  In serial mode (-s), each file is pasted as one record.
#
# Flags:
#   -d LIST, --delimiters=LIST  cycle through LIST as the delimiter(s) between
#                               columns instead of a single tab
#   -s, --serial                paste one file at a time in serial rather than
#                               merging columns
#   -z, --zero-terminated       use NUL as the line delimiter (not newline)
#   --help
#
# Compile: spinel nix_utils/paste.rb -o nix_utils/bin/paste
# Run:
#   ./bin/paste a.txt b.txt
#   ./bin/paste -d, a.txt b.txt
#   ./bin/paste -s a.txt
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/paste.rb ...`).

USAGE = "Usage: paste [OPTION]... [FILE]...\n" \
        "Write lines from each FILE side by side, separated by tabs.\n" \
        "With -, read standard input.\n" \
        "  -d LIST  delimiter list (cycles)   -s  serial mode   -z  NUL line delimiter\n" \
        "  --help"

class PasteOptions
  attr_accessor :delimiters, :serial, :zero
  def initialize
    @delimiters = ["\t"]
    @serial     = false
    @zero       = false
  end
end

# Interpret tr-style backslash escapes in a delimiter list.
def expand_delimiters(s)
  result = []
  i = 0
  while i < s.length
    if s[i] == "\\" && i + 1 < s.length
      c = s[i + 1]
      if c == "n";     result.push("\n"); i += 2
      elsif c == "t";  result.push("\t"); i += 2
      elsif c == "\\"; result.push("\\"); i += 2
      elsif c == "0";  result.push("\0"); i += 2
      else             result.push(c);    i += 2
      end
    else
      result.push(s[i])
      i += 1
    end
  end
  result
end

def parse_argv(argv)
  opts  = PasteOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-s" || arg == "--serial"
      opts.serial = true
    elsif arg == "-z" || arg == "--zero-terminated"
      opts.zero = true
    elsif arg == "-d" || arg == "--delimiters"
      index += 1
      opts.delimiters = expand_delimiters(argv[index])
    elsif arg.length > 2 && arg[0, 2] == "-d"
      opts.delimiters = expand_delimiters(arg[2, arg.length - 2])
    elsif arg.length > 13 && arg[0, 13] == "--delimiters="
      opts.delimiters = expand_delimiters(arg[13, arg.length - 13])
    else
      STDERR.puts "paste: invalid option -- '#{arg}'"
      STDERR.puts "Try 'paste --help' for more information."
      exit 1
    end
    index += 1
  end
  [opts, files]
end

def read_source(name)
  return STDIN.read if name == "-"
  File.read(name)
end

def read_lines(name, line_delim)
  content = read_source(name)
  lines = content.split(line_delim, -1)
  # Remove a trailing empty element that appears when content ends with delim.
  lines.pop if !lines.empty? && lines.last == ""
  lines
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

line_delim = opts.zero ? "\0" : "\n"
delims     = opts.delimiters
exit_code  = 0

files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "paste: #{name}: No such file or directory"
    exit_code = 1
  end
end

if opts.serial
  # -s: paste each file independently: all lines joined by cycling delimiters.
  files.each do |name|
    next if name != "-" && !File.exist?(name)
    lines = read_lines(name, line_delim)
    result = ""
    i = 0
    while i < lines.length
      result += lines[i]
      if i < lines.length - 1
        result += delims[i % delims.length]
      else
        result += line_delim
      end
      i += 1
    end
    STDOUT.write(result)
  end
else
  # Parallel merge: read all files, then zip columns.
  all_lines = []
  files.each do |name|
    if name != "-" && !File.exist?(name)
      all_lines.push([])
    else
      all_lines.push(read_lines(name, line_delim))
    end
  end

  # Find the longest file.
  max_rows = 0
  all_lines.each { |ls| max_rows = ls.length if ls.length > max_rows }

  row = 0
  while row < max_rows
    parts = []
    col = 0
    while col < all_lines.length
      parts.push(row < all_lines[col].length ? all_lines[col][row] : "")
      col += 1
    end
    result = ""
    i = 0
    while i < parts.length
      result += parts[i]
      result += delims[i % delims.length] if i < parts.length - 1
      i += 1
    end
    STDOUT.write(result + line_delim)
    row += 1
  end
end

exit exit_code
