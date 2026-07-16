# wc.rb, print newline, word, and byte counts (GNU wc, Spinel port).
#
# A faithful subset of GNU wc. For each FILE (or standard input when a file is
# "-" or none are given) it prints selected counts, then a total line when more
# than one file is given. Counts always print in GNU's fixed order regardless
# of the flag order: newline, word, character, byte, max-line-length.
#
# Flags:
#   -l, --lines             newline counts
#   -w, --words             word counts (whitespace-delimited)
#   -m, --chars             character counts
#   -c, --count_bytes             byte counts
#   -L, --max-line-length   length of the longest line
#   --help                  usage
# With no count flag, wc prints lines, words, and count_bytes (the GNU default).
#
# Compile: spinel nix_utils/wc.rb -o nix_utils/bin/wc
# Run:
#   ./bin/wc file.txt
#   ./bin/wc -l a.txt b.txt        # per-file + total
#   printf 'a b\n' | ./bin/wc -w
#
# Core Ruby only (File, STDIN, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/wc.rb ...`).

USAGE = "Usage: wc [OPTION]... [FILE]...\n" \
        "  or:  wc [OPTION]... --files0-from=F\n" \
        "Print newline, word, and byte counts for each FILE.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -l  lines   -w  words   -m  chars   -c  count_bytes\n" \
        "  -L  max line length\n" \
        "  --files0-from=F  read NUL-delimited filenames from F\n" \
        "  --total=WHEN     auto (default), always, only, never\n" \
        "  --help"

# Which counts the user asked for. When nothing is selected we fall back to the
# GNU default of lines, words, and count_bytes at print time.
class WcSelection
  attr_accessor :lines, :words, :chars, :count_bytes, :max_length
  def initialize
    @lines = false
    @words = false
    @chars = false
    @count_bytes = false
    @max_length = false
  end

  def any?
    @lines || @words || @chars || @count_bytes || @max_length
  end
end

# Compute all five counts for one blob of text in a single pass over its
# lines. Returns [lines, words, chars, count_bytes, max_line_length].
#
# GNU semantics: "lines" counts newline characters, "words" are maximal runs
# of non-whitespace, "chars" is character count, "count_bytes" is byte count, and
# max-line-length is the longest line measured without its newline.
def count_text(text)
  count_bytes = text.bytesize
  chars = text.length
  lines = 0
  words = 0
  max_length = 0

  text.lines.each do |raw_line|
    has_newline = raw_line.end_with?("\n")
    lines += 1 if has_newline
    body = has_newline ? raw_line[0, raw_line.length - 1] : raw_line
    body_length = body.length
    max_length = body_length if body_length > max_length
    words += body.split.length
  end

  [lines, words, chars, count_bytes, max_length]
end

# Read one source fully. "-" is standard input.
def read_source(name)
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

# Print one result row. counts is [lines, words, chars, count_bytes, max_length];
# label is the file name (or "" for the stdin case, matching GNU, which prints
# no name for stdin). Only the selected columns are shown, each right-justified
# in a width-7 field with a leading space between columns, as GNU does.
def print_row(counts, selection, label)
  fields = []
  fields.push(counts[0]) if selection.lines
  fields.push(counts[1]) if selection.words
  fields.push(counts[2]) if selection.chars
  fields.push(counts[3]) if selection.count_bytes
  fields.push(counts[4]) if selection.max_length

  parts = []
  fields.each { |value| parts.push(value.to_s.rjust(7)) }
  line = parts.join(" ")
  line += " #{label}" unless label == ""
  puts line
end

# Parse ARGV into [selection, files, files0_from, total_when].
# "-" is a file; "--" ends options.
def parse_argv(argv)
  selection   = WcSelection.new
  files       = []
  files0_from = nil
  total_when  = "auto"
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "--lines"
      selection.lines = true
    elsif arg == "--words"
      selection.words = true
    elsif arg == "--chars"
      selection.chars = true
    elsif arg == "--bytes"
      selection.count_bytes = true
    elsif arg == "--max-line-length"
      selection.max_length = true
    elsif arg.length > 14 && arg[0, 14] == "--files0-from="
      files0_from = arg[14, arg.length - 14]
    elsif arg == "--files0-from"
      index += 1
      files0_from = argv[index]
    elsif arg.length > 8 && arg[0, 8] == "--total="
      total_when = arg[8, arg.length - 8]
      unless total_when == "auto" || total_when == "always" ||
             total_when == "only" || total_when == "never"
        STDERR.puts "wc: invalid argument '#{total_when}' for '--total'"
        exit 1
      end
    elsif arg == "--debug"
      # internal flag, silently ignored
    else
      letters = arg[1, arg.length - 1]
      letter_index = 0
      while letter_index < letters.length
        letter = letters[letter_index]
        if letter == "l"
          selection.lines = true
        elsif letter == "w"
          selection.words = true
        elsif letter == "m"
          selection.chars = true
        elsif letter == "c"
          selection.count_bytes = true
        elsif letter == "L"
          selection.max_length = true
        else
          STDERR.puts "wc: invalid option -- '#{letter}'"
          STDERR.puts "Try 'wc --help' for more information."
          exit 1
        end
        letter_index += 1
      end
    end
    index += 1
  end
  [selection, files, files0_from, total_when]
end

selection, files, files0_from, total_when = parse_argv(ARGV)

# --files0-from=F: append NUL-separated filenames from F to the file list.
# NUL bytes can't be embedded in C strings, so we convert them to newlines
# with tr(1) and split on newline instead.
unless files0_from.nil?
  ff = "" + files0_from
  src = ff == "-" ? "/dev/stdin" : ff
  content = "" + `/usr/bin/tr '\\000' '\\012' < #{src}`
  content.split("\n").each do |seg|
    cseg = "" + seg
    files.push(cseg) unless cseg == ""
  end
end

# Default selection: lines, words, count_bytes.
unless selection.any?
  selection.lines = true
  selection.words = true
  selection.count_bytes = true
end

reading_stdin = files.empty?
files = ["-"] if reading_stdin

totals    = [0, 0, 0, 0, 0]
exit_code = 0
row_count = 0   # number of files successfully processed

files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "wc: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  if cname != "-" && File.directory?(cname)
    STDERR.puts "wc: #{cname}: Is a directory"
    exit_code = 1
    next
  end

  counts = count_text(read_source(cname))
  label  = (cname == "-") ? "" : cname

  # --total=only suppresses individual rows.
  print_row(counts, selection, label) unless total_when == "only"

  totals[0] += counts[0]
  totals[1] += counts[1]
  totals[2] += counts[2]
  totals[3] += counts[3]
  totals[4] = counts[4] if counts[4] > totals[4]
  row_count += 1
end

# Print total line according to --total=WHEN.
case total_when
when "always"
  print_row(totals, selection, "total")
when "only"
  print_row(totals, selection, "total")
when "never"
  # never print
else
  # "auto": print when more than one file was named.
  print_row(totals, selection, "total") if row_count > 1
end

exit exit_code
