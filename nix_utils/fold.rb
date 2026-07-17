# fold.rb, wrap each input line to a given width (GNU fold, Spinel port).
#
# Wrap lines in each FILE (or standard input) to fit in the specified width.
#
# Flags:
#   -w N, --width=N     use output width N (default: 80)
#   -b, --bytes         count bytes rather than columns
#   -c, --characters    count characters rather than columns
#   -s, --spaces        break at spaces rather than within words
#   --help
#
# By default the width is measured in screen columns: a tab advances to the next
# multiple of 8, a backspace moves back one column, and a carriage return resets
# the column to zero.  -b and -c instead count each byte or character as one.
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
        "  -w N  width (default 80)   -b  bytes   -c  characters\n" \
        "  -s  break at spaces   --help"

class FoldOptions
  attr_accessor :width, :count_bytes, :count_chars, :spaces
  def initialize
    @width       = 80
    @count_bytes = false
    @count_chars = false
    @spaces      = false
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
      opts.count_bytes = true
    elsif arg == "-c" || arg == "--characters"
      opts.count_chars = true
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
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

# Column advance for one character starting at the given column. In byte or
# character mode every unit counts as one column; in the default column mode a
# tab jumps to the next multiple of 8, a backspace moves back one, and a
# carriage return resets to column zero.
def char_width(char, column, opts)
  return 1 if opts.count_bytes || opts.count_chars
  if char == "\t"
    (column + 8 - column % 8) - column
  elsif char == "\b"
    column > 0 ? -1 : 0
  elsif char == "\r"
    -column
  else
    1
  end
end

# Recompute the ending column of a segment from scratch.
def segment_column(seg, opts)
  return seg.length if opts.count_bytes || opts.count_chars
  col = 0
  k = 0
  while k < seg.length
    col += char_width(seg[k], col, opts)
    k += 1
  end
  col
end

# Fold one line (without its trailing newline) at width. Returns folded text
# including any needed newlines between segments; no trailing newline added.
def fold_line(body, opts)
  width = opts.width
  return body if width <= 0

  result = ""
  seg    = ""   # characters emitted since the last break
  column = 0
  i = 0
  n = body.length

  while i < n
    char = body[i]
    adv  = char_width(char, column, opts)

    if column + adv > width && seg.length > 0
      if opts.spaces
        # Break after the last blank in the segment, if there is one.
        brk = -1
        j = seg.length - 1
        while j >= 0
          if seg[j] == " " || seg[j] == "\t"
            brk = j
            break
          end
          j -= 1
        end
        if brk >= 0
          result += seg[0, brk + 1] + "\n"
          seg = seg[brk + 1, seg.length - brk - 1]
        else
          result += seg + "\n"
          seg = ""
        end
      else
        result += seg + "\n"
        seg = ""
      end
      column = segment_column(seg, opts)
      next   # reprocess the current char against the fresh segment
    end

    seg += char
    column += adv
    i += 1
  end

  result + seg
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
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "fold: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  if cname != "-" && File.directory?(cname)
    STDERR.puts "fold: #{cname}: Is a directory"
    exit_code = 1
    next
  end
  STDOUT.write(fold_content(read_source(cname), opts))
end

exit exit_code
