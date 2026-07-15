# comm.rb, compare two sorted files line by line (GNU comm, Spinel port).
#
# Reads two sorted FILES and produces three-column output:
#   column 1: lines only in FILE1
#   column 2: lines only in FILE2
#   column 3: lines in both files
#
# Flags:
#   -1           suppress column 1 (lines unique to FILE1)
#   -2           suppress column 2 (lines unique to FILE2)
#   -3           suppress column 3 (lines common to both)
#   -i           case-insensitive comparison
#   -z           NUL-terminated input/output
#   --nocheck-order  do not check that input is sorted
#   --output-delimiter=STR  use STR instead of TAB between columns
#   --help       usage
#
# Compile: spinel nix_utils/comm.rb -o nix_utils/bin/comm
# Run:
#   comm file1.txt file2.txt
#   comm -12 file1.txt file2.txt    # show only lines common to both
#
# Core Ruby only; no require gate needed.

USAGE = "Usage: comm [OPTION]... FILE1 FILE2\n" \
        "Compare two sorted files line by line.\n" \
        "With no options, produce three-tab-separated columns:\n" \
        "  col 1: lines unique to FILE1\n" \
        "  col 2: lines unique to FILE2\n" \
        "  col 3: lines appearing in both\n" \
        "  -1  suppress col 1   -2  suppress col 2   -3  suppress col 3\n" \
        "  -i  case-insensitive comparison\n" \
        "  -z  NUL-terminated lines\n" \
        "  --nocheck-order  do not check that input is sorted\n" \
        "  --output-delimiter=STR  column separator (default: TAB)\n" \
        "  --help"

class CommOptions
  attr_accessor :suppress1, :suppress2, :suppress3
  attr_accessor :ignore_case, :zero, :nocheck, :delim
  def initialize
    @suppress1   = false
    @suppress2   = false
    @suppress3   = false
    @ignore_case = false
    @zero        = false
    @nocheck     = false
    @delim       = "\t"
  end
end

def parse_argv(argv)
  opts = CommOptions.new
  files = []
  index = 0
  while index < argv.length
    arg = argv[index]
    if arg == "--"
      index += 1
      while index < argv.length
        files.push(argv[index])
        index += 1
      end
      break
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "--nocheck-order" || arg == "--check-order"
      opts.nocheck = (arg == "--nocheck-order")
    elsif arg.length > 20 && arg[0, 20] == "--output-delimiter="
      opts.delim = arg[20, arg.length - 20]
    elsif arg == "--output-delimiter"
      index += 1
      opts.delim = argv[index]
    elsif arg == "-z" || arg == "--zero-terminated"
      opts.zero = true
    elsif arg.length >= 2 && arg[0] == "-" && arg != "-"
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "1"
          opts.suppress1 = true
        elsif letter == "2"
          opts.suppress2 = true
        elsif letter == "3"
          opts.suppress3 = true
        elsif letter == "i"
          opts.ignore_case = true
        elsif letter == "z"
          opts.zero = true
        else
          STDERR.puts "comm: invalid option -- '#{letter}'"
          STDERR.puts "Try 'comm --help' for more information."
          exit 1
        end
        li += 1
      end
    else
      files.push(arg)
    end
    index += 1
  end
  [opts, files]
end

def read_lines(name, opts)
  content = (name == "-") ? STDIN.read : File.read(name)
  delim = opts.zero ? "\0" : "\n"
  if delim == "\n"
    lines = content.lines.map { |l| l.end_with?("\n") ? l[0, l.length - 1] : l }
  else
    lines = content.split("\0", -1)
    lines.pop if !lines.empty? && lines.last == ""
  end
  lines
end

def cmp_key(s, ignore_case)
  ignore_case ? s.downcase : s
end

opts, files = parse_argv(ARGV)

if files.length != 2
  STDERR.puts "comm: missing operand after #{files.length == 1 ? "'#{files[0]}'" : "'comm'"}"
  STDERR.puts "Try 'comm --help' for more information."
  exit 1
end

[files[0], files[1]].each do |f|
  if f != "-" && !File.exist?(f)
    STDERR.puts "comm: #{f}: No such file or directory"
    exit 1
  end
end

lines1 = read_lines(files[0], opts)
lines2 = read_lines(files[1], opts)

i = 0
j = 0
term = opts.zero ? "\0" : "\n"

while i < lines1.length || j < lines2.length
  l1 = i < lines1.length ? lines1[i] : nil
  l2 = j < lines2.length ? lines2[j] : nil

  if l1.nil?
    # FILE1 exhausted: rest of FILE2 is unique to FILE2
    unless opts.suppress2
      prefix = opts.suppress1 ? "" : opts.delim
      STDOUT.write(prefix + l2 + term)
    end
    j += 1
  elsif l2.nil?
    # FILE2 exhausted: rest of FILE1 is unique to FILE1
    unless opts.suppress1
      STDOUT.write(l1 + term)
    end
    i += 1
  else
    k1 = cmp_key(l1, opts.ignore_case)
    k2 = cmp_key(l2, opts.ignore_case)

    if k1 < k2
      # l1 is unique to FILE1
      unless opts.suppress1
        STDOUT.write(l1 + term)
      end
      i += 1
    elsif k1 > k2
      # l2 is unique to FILE2
      unless opts.suppress2
        prefix = opts.suppress1 ? "" : opts.delim
        STDOUT.write(prefix + l2 + term)
      end
      j += 1
    else
      # common
      unless opts.suppress3
        prefix = ""
        prefix += opts.delim unless opts.suppress1
        prefix += opts.delim unless opts.suppress2
        STDOUT.write(prefix + l1 + term)
      end
      i += 1
      j += 1
    end
  end
end
