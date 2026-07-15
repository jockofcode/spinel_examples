# nl.rb, number lines of files (GNU nl, Spinel port).
#
# Write each FILE (or standard input) to standard output with line numbers
# added. Supports the most common numbering options.
#
# Flags:
#   -b STYLE  body numbering: a=all, t=nonempty (default), n=none, pREGEX (not supported)
#   -h STYLE  header numbering style (default: n)
#   -f STYLE  footer numbering style (default: n)
#   -n FORMAT number format: ln (left,no-zeros), rn (right,no-zeros), rz (right,zero-pad)
#   -w N      width of line-number field (default: 6)
#   -v N      first line number (default: 1)
#   -i N      line number increment (default: 1)
#   -l N      treat N empty lines as one for numbering (default: 1)
#   -s SEP    separator between line number and content (default: tab)
#   --help
#
# Compile: spinel nix_utils/nl.rb -o nix_utils/bin/nl
# Run:
#   ./bin/nl file.txt
#   ./bin/nl -ba -nrz -w4 file.txt
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/nl.rb ...`).

USAGE = "Usage: nl [OPTION]... [FILE]...\n" \
        "Write each FILE to standard output with line numbers added.\n" \
        "  -b STYLE  body style (a/t/n)   -n FORMAT  number format (ln/rn/rz)\n" \
        "  -w N  field width   -v N  start   -i N  increment   -s SEP  separator\n" \
        "  --help"

class NlOptions
  attr_accessor :body_style, :header_style, :footer_style
  attr_accessor :format, :width, :start, :increment, :empty_lines, :separator
  def initialize
    @body_style   = "t"   # t=nonempty
    @header_style = "n"   # n=none
    @footer_style = "n"
    @format       = "rn"  # right-justified, no zeros
    @width        = 6
    @start        = 1
    @increment    = 1
    @empty_lines  = 1
    @separator    = "\t"
  end
end

def numeric?(s)
  return false if s == ""
  i = 0
  i += 1 if s[0] == "-" || s[0] == "+"
  return false if i >= s.length
  while i < s.length
    return false unless "0123456789".include?(s[i])
    i += 1
  end
  true
end

def parse_argv(argv)
  opts  = NlOptions.new
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
    elsif arg == "-b" || arg == "--body-numbering"
      index += 1; opts.body_style = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-b"
      opts.body_style = arg[2, arg.length - 2]
    elsif arg == "-h" || arg == "--header-numbering"
      index += 1; opts.header_style = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-h"
      opts.header_style = arg[2, arg.length - 2]
    elsif arg == "-f" || arg == "--footer-numbering"
      index += 1; opts.footer_style = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-f"
      opts.footer_style = arg[2, arg.length - 2]
    elsif arg == "-n" || arg == "--number-format"
      index += 1; opts.format = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-n"
      opts.format = arg[2, arg.length - 2]
    elsif arg == "-w" || arg == "--number-width"
      index += 1; opts.width = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-w"
      opts.width = arg[2, arg.length - 2].to_i
    elsif arg == "-v" || arg == "--starting-line-number"
      index += 1; opts.start = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-v"
      opts.start = arg[2, arg.length - 2].to_i
    elsif arg == "-i" || arg == "--line-increment"
      index += 1; opts.increment = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-i"
      opts.increment = arg[2, arg.length - 2].to_i
    elsif arg == "-l" || arg == "--join-blank-lines"
      index += 1; opts.empty_lines = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-l"
      opts.empty_lines = arg[2, arg.length - 2].to_i
    elsif arg == "-s" || arg == "--number-separator"
      index += 1; opts.separator = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.separator = arg[2, arg.length - 2]
    else
      STDERR.puts "nl: invalid option -- '#{arg}'"
      STDERR.puts "Try 'nl --help' for more information."
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

# Format a line number according to the chosen format and width.
def format_number(n, fmt, width)
  s = n.to_s
  if fmt == "rz"
    # Right-justified, zero-padded.
    while s.length < width
      s = "0" + s
    end
    s
  elsif fmt == "ln"
    # Left-justified, space-padded.
    while s.length < width
      s = s + " "
    end
    s
  else
    # rn: right-justified, space-padded (default).
    s.rjust(width)
  end
end

# Decide whether a line should be numbered given the numbering style.
def should_number?(body, style)
  if style == "a"
    true
  elsif style == "t"
    body != ""
  elsif style == "n"
    false
  else
    false
  end
end

def process_content(content, opts)
  line_num     = opts.start
  result       = ""
  blank_run    = 0

  content.lines.each do |raw_line|
    has_newline = raw_line.end_with?("\n")
    body = has_newline ? raw_line[0, raw_line.length - 1] : raw_line

    is_blank = (body == "")
    if is_blank
      blank_run += 1
    else
      blank_run = 0
    end

    # For blank lines the body style is applied; skip-count uses -l.
    number_it = should_number?(body, opts.body_style)
    # When style is "t" and the line is blank, only number when we've seen
    # enough consecutive blank lines (controlled by -l, default 1).
    if opts.body_style == "a" && is_blank
      number_it = (blank_run % opts.empty_lines == 0)
    end

    if number_it
      prefix = format_number(line_num, opts.format, opts.width) + opts.separator
      line_num += opts.increment
    else
      prefix = " " * (opts.width + opts.separator.length)
    end

    result += prefix + body
    result += "\n" if has_newline
  end

  result
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "nl: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  if name != "-" && File.directory?(name)
    STDERR.puts "nl: #{name}: Is a directory"
    exit_code = 1
    next
  end
  STDOUT.write(process_content(read_source(name), opts))
end

exit exit_code
