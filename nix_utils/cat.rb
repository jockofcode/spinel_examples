# cat.rb, concatenate files and print on the standard output (GNU cat, Spinel).
#
# A faithful subset of GNU cat: concatenates each FILE (or standard input when
# a file is "-" or none are given) to stdout. Supports the line-transforming
# flags GNU cat is known for.
#
# Flags:
#   -n, --number            number all output lines
#   -b, --number-nonblank   number nonempty lines (overrides -n)
#   -s, --squeeze-blank     collapse runs of blank lines into one
#   -E, --show-ends         put $ at the end of each line
#   -T, --show-tabs         show TAB as ^I
#   -A, --show-all          same as -ET here (control chars kept literally)
#   -e                      same as -E (the -v part is a no-op in this subset)
#   -t                      same as -T
#   --help                  usage
#
# Compile: spinel nix_utils/cat.rb -o nix_utils/bin/cat
# Run:
#   ./bin/cat file1 file2         # concatenate
#   printf 'a\nb\n' | ./bin/cat -n
#   ./bin/cat -           # explicit stdin
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/cat.rb ...`).

USAGE = "Usage: cat [OPTION]... [FILE]...\n" \
        "Concatenate FILE(s) to standard output.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -n  number all lines   -b  number nonempty lines\n" \
        "  -s  squeeze blanks     -E  show line ends ($)\n" \
        "  -T  show tabs (^I)     -v  show nonprinting (^X / M-x)\n" \
        "  -A  show-all (-vET)    --help"

# Parsed options for a cat run.
class CatOptions
  attr_accessor :number, :number_nonblank, :squeeze, :show_ends, :show_tabs
  attr_accessor :show_nonprinting
  def initialize
    @number           = false
    @number_nonblank  = false
    @squeeze          = false
    @show_ends        = false
    @show_tabs        = false
    @show_nonprinting = false
  end

  # True when no line transformation is requested, so we can stream files
  # verbatim (the fast, byte-exact path that also handles binary input).
  def plain?
    !@number && !@number_nonblank && !@squeeze &&
      !@show_ends && !@show_tabs && !@show_nonprinting
  end
end

# Apply the -A/-e/-t/-v expansions and set each individual flag on opts.
def apply_flag_letter(letter, opts)
  if letter == "n"
    opts.number = true
  elsif letter == "b"
    opts.number_nonblank = true
  elsif letter == "s"
    opts.squeeze = true
  elsif letter == "E"
    opts.show_ends = true
  elsif letter == "T"
    opts.show_tabs = true
  elsif letter == "v"
    opts.show_nonprinting = true
  elsif letter == "A"
    # GNU: -A == -vET
    opts.show_nonprinting = true
    opts.show_ends = true
    opts.show_tabs = true
  elsif letter == "e"
    # GNU: -e == -vE
    opts.show_nonprinting = true
    opts.show_ends = true
  elsif letter == "t"
    # GNU: -t == -vT
    opts.show_nonprinting = true
    opts.show_tabs = true
  elsif letter == "u"
    # -u (unbuffered) is accepted and ignored, as GNU documents.
  else
    STDERR.puts "cat: invalid option -- '#{letter}'"
    STDERR.puts "Try 'cat --help' for more information."
    exit 1
  end
end

# Split ARGV into [options, files]. A lone "-" is a file (stdin), not a flag.
# "--" ends option parsing. Long options --number etc. map onto the letters.
def parse_argv(argv)
  opts = CatOptions.new
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
      puts USAGE
      exit 0
    elsif arg == "--number"
      opts.number = true
    elsif arg == "--number-nonblank"
      opts.number_nonblank = true
    elsif arg == "--squeeze-blank"
      opts.squeeze = true
    elsif arg == "--show-ends"
      opts.show_ends = true
    elsif arg == "--show-tabs"
      opts.show_tabs = true
    elsif arg == "--show-nonprinting"
      opts.show_nonprinting = true
    elsif arg == "--show-all"
      opts.show_nonprinting = true
      opts.show_ends = true
      opts.show_tabs = true
    else
      # A short flag cluster like -bE. Apply each letter.
      letters = arg[1, arg.length - 1]
      letter_index = 0
      while letter_index < letters.length
        apply_flag_letter(letters[letter_index], opts)
        letter_index += 1
      end
    end
    index += 1
  end
  [opts, files]
end

# Render non-printing characters using GNU cat's ^ and M- notation.
# TAB (0x09) and LF (0x0A) are left as-is so -T and -E can handle them.
# Iterates over raw bytes to avoid encoding errors on non-UTF-8 input.
def show_nonprinting_body(body)
  result = ""
  body.bytes.each do |code|
    if code < 32 && code != 9
      # Control char (not TAB): ^A .. ^Z, ^[, ^\, ^], ^^, ^_
      result += "^" + (code + 64).chr
    elsif code == 127
      result += "^?"
    elsif code > 127
      low = code - 128
      result += "M-"
      if low < 32
        result += "^" + (low + 64).chr
      elsif low == 127
        result += "^?"
      else
        result += low.chr
      end
    else
      result += code.chr
    end
  end
  result
end

# Read the whole content of one source. "-" means standard input.
def read_source(name)
  return STDIN.read if name == "-"
  File.read(name)
end

# Emit one file's content under the active options. `state` carries the running
# line number and the previous-blank flag across files (GNU numbers and
# squeezes continuously across the whole output, not per file). Returns state.
def emit(content, opts, state)
  if opts.plain?
    STDOUT.write(content)
    return state
  end

  line_number = state[0]
  prev_blank = state[1]

  # Split into lines, preserving whether the file ended without a newline so we
  # do not invent a trailing line. lines keeps the "\n" on each element.
  content.lines.each do |raw_line|
    has_newline = raw_line.end_with?("\n")
    body = has_newline ? raw_line[0, raw_line.length - 1] : raw_line
    is_blank = (body == "")

    if opts.squeeze && is_blank && prev_blank
      next                           # drop this repeated blank line
    end
    prev_blank = is_blank

    if opts.show_nonprinting
      body = show_nonprinting_body(body)
    end

    if opts.show_tabs
      body = body.gsub("\t", "^I")
    end

    # -b numbers only nonempty lines; -n numbers all lines. -b wins over -n.
    if opts.number_nonblank
      if !is_blank
        line_number += 1
        body = number_prefix(line_number) + body
      end
    elsif opts.number
      line_number += 1
      body = number_prefix(line_number) + body
    end

    body += "$" if opts.show_ends
    STDOUT.write(body)
    STDOUT.write("\n") if has_newline
  end

  [line_number, prev_blank]
end

# GNU cat right-justifies the line number in a 6-wide field, then a tab.
def number_prefix(number)
  number.to_s.rjust(6) + "\t"
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
state = [0, false]                   # [line_number, prev_line_was_blank]
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "cat: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  if name != "-" && File.directory?(name)
    STDERR.puts "cat: #{name}: Is a directory"
    exit_code = 1
    next
  end
  state = emit(read_source(name), opts, state)
end

exit exit_code
