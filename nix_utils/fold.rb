# fold.rb, wrap each input line to a given width (GNU fold, Spinel port).
#
# Wrap lines in each FILE (or standard input) to fit in the specified width.
#
# Flags:
#   -w N, --width=N    use output width N (default: 80)
#   -b, --bytes        count bytes rather than columns
#   -s, --spaces       break at spaces rather than within words
#   --help
#
# Compile: spinel nix_utils/fold.rb -o nix_utils/bin/fold
# Run:
#   ./bin/fold -w 40 README.md
#   echo "a very long line here" | ./bin/fold -w 10 -s
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/fold.rb ...`).

USAGE = "Usage: fold [OPTION]... [FILE]...\n" \
        "Wrap input lines, breaking long lines to fit in WIDTH columns.\n" \
        "  -w N  width (default 80)   -b  bytes   -s  break at spaces   --help"

class FoldOptions
  attr_accessor :width, :bytes, :spaces
  def initialize
    @width  = 80
    @bytes  = false
    @spaces = false
  end
end

def numeric?(s)
  return false if s == ""
  i = 0
  while i < s.length
    return false unless "0123456789".include?(s[i])
    i += 1
  end
  true
end

def parse_argv(argv)
  opts  = FoldOptions.new
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
    elsif arg == "-b" || arg == "--bytes"
      opts.bytes = true
    elsif arg == "-s" || arg == "--spaces"
      opts.spaces = true
    elsif arg == "-w" || arg == "--width"
      index += 1
      unless numeric?(argv[index])
        STDERR.puts "fold: invalid number of columns: '#{argv[index]}'"
        exit 1
      end
      opts.width = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-w"
      val = arg[2, arg.length - 2]
      unless numeric?(val)
        STDERR.puts "fold: invalid number of columns: '#{val}'"
        exit 1
      end
      opts.width = val.to_i
    elsif arg.length > 8 && arg[0, 8] == "--width="
      val = arg[8, arg.length - 8]
      unless numeric?(val)
        STDERR.puts "fold: invalid number of columns: '#{val}'"
        exit 1
      end
      opts.width = val.to_i
    else
      STDERR.puts "fold: invalid option -- '#{arg}'"
      STDERR.puts "Try 'fold --help' for more information."
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

# Fold one line (without its trailing newline) at width. Returns folded text
# including any needed newlines between segments; no trailing newline added.
def fold_line(body, opts)
  width = opts.width
  return body if width <= 0

  units = opts.bytes ? body.bytes.length : body.length
  return body if units <= width

  result = ""
  pos = 0   # position in the character (or byte) array

  while pos < (opts.bytes ? body.bytesize : body.length)
    remaining = opts.bytes ? body.bytesize - pos : body.length - pos
    break if remaining == 0

    chunk_len = remaining < width ? remaining : width

    if opts.bytes
      chunk = body[pos, chunk_len]
    else
      chunk = body[pos, chunk_len]
    end

    if opts.spaces && pos + chunk_len < (opts.bytes ? body.bytesize : body.length)
      # Try to find the last space in the chunk to break after.
      break_at = chunk_len
      i = chunk_len - 1
      while i >= 0
        if chunk[i] == " "
          break_at = i + 1
          break
        end
        i -= 1
      end
      chunk_len = break_at
      chunk = body[pos, chunk_len]
    end

    result += "\n" unless result == ""
    result += chunk
    pos += chunk_len
  end

  result
end

def fold_content(content, opts)
  result = ""
  content.lines.each do |line|
    has_newline = line.end_with?("\n")
    body = has_newline ? line[0, line.length - 1] : line
    result += fold_line(body, opts)
    result += "\n" if has_newline
  end
  result
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "fold: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  if name != "-" && File.directory?(name)
    STDERR.puts "fold: #{name}: Is a directory"
    exit_code = 1
    next
  end
  STDOUT.write(fold_content(read_source(name), opts))
end

exit exit_code
