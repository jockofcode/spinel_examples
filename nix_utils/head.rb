# head.rb, output the first part of files (GNU head, Spinel port).
#
# A faithful subset of GNU head. Prints the first 10 lines of each FILE (or of
# standard input when a file is "-" or none are given). With more than one file
# it precedes each with a "==> NAME <==" header, unless -q is given.
#
# Flags:
#   -n, --lines=[-]NUM   first NUM lines; with a leading '-', all but the last
#                        NUM lines
#   -c, --bytes=[-]NUM   first NUM bytes; with a leading '-', all but the last
#                        NUM bytes
#   -q, --quiet          never print file-name headers
#   -v, --verbose        always print file-name headers
#   --help               usage
# Short forms also accept an attached value, e.g. -n5 or -c-3.
#
# Compile: spinel nix_utils/head.rb -o nix_utils/bin/head
# Run:
#   ./bin/head file.txt
#   ./bin/head -n 3 a.txt b.txt
#   printf 'a\nb\nc\n' | ./bin/head -n1
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/head.rb ...`).

USAGE = "Usage: head [OPTION]... [FILE]...\n" \
        "Print the first 10 lines of each FILE to standard output.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -n [-]NUM   first NUM lines (or all but last NUM)\n" \
        "  -c [-]NUM   first NUM bytes (or all but last NUM)\n" \
        "  -q  never print headers   -v  always print headers\n" \
        "  NUM suffixes: b 512, kB 1000, K/KiB 1024, MB 1000^2, M/MiB 1024^2\n" \
        "  --help"

# Options for a head run.
class HeadOptions
  attr_accessor :count, :from_end, :by_bytes, :quiet, :verbose
  def initialize
    @count    = 10
    @from_end = false
    @by_bytes = false
    @quiet    = false
    @verbose  = false
  end
end

# Resolve a NUM suffix to a multiplier and return the resulting integer.
def parse_multiplier(text)
  if text.end_with?("KiB") || (text.end_with?("K") && !text.end_with?("kB"))
    base = text.end_with?("KiB") ? text[0, text.length - 3] : text[0, text.length - 1]
    return base.to_i * 1024
  elsif text.end_with?("MiB") || (text.end_with?("M") && !text.end_with?("MB"))
    base = text.end_with?("MiB") ? text[0, text.length - 3] : text[0, text.length - 1]
    return base.to_i * 1024 * 1024
  elsif text.end_with?("GiB") || (text.end_with?("G") && !text.end_with?("GB"))
    base = text.end_with?("GiB") ? text[0, text.length - 3] : text[0, text.length - 1]
    return base.to_i * 1024 * 1024 * 1024
  elsif text.end_with?("kB") || text.end_with?("KB")
    return text[0, text.length - 2].to_i * 1000
  elsif text.end_with?("MB")
    return text[0, text.length - 2].to_i * 1000 * 1000
  elsif text.end_with?("GB")
    return text[0, text.length - 2].to_i * 1000 * 1000 * 1000
  elsif text.end_with?("b")
    return text[0, text.length - 1].to_i * 512
  else
    return text.to_i
  end
end

# Parse a [-]NUM[SUFFIX] value for -n/-c. Sets opts.count and opts.from_end.
def set_count(value, tool_flag, opts)
  text = value
  if text.length > 0 && text[0] == "-"
    opts.from_end = true
    text = text[1, text.length - 1]
  else
    opts.from_end = false
  end
  if text == ""
    STDERR.puts "head: invalid number of #{tool_flag}: '#{value}'"
    exit 1
  end
  opts.count = parse_multiplier(text)
end

def numeric?(text)
  return false if text == ""
  index = 0
  while index < text.length
    return false unless "0123456789".include?(text[index])
    index += 1
  end
  true
end

# Parse ARGV into [opts, files]. Handles -n/-c with either a separate argument
# or an attached value (-n5). "-" is a file; "--" ends option parsing.
def parse_argv(argv)
  opts = HeadOptions.new
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
    elsif arg == "-q" || arg == "--quiet" || arg == "--silent"
      opts.quiet = true
    elsif arg == "-v" || arg == "--verbose"
      opts.verbose = true
    elsif arg == "-n" || arg == "--lines"
      index += 1
      set_count(argv[index], "lines", opts)
    elsif arg == "-c" || arg == "--bytes"
      index += 1
      set_count(argv[index], "bytes", opts)
    elsif arg.length > 2 && arg[0, 2] == "-n"
      set_count(arg[2, arg.length - 2], "lines", opts)
    elsif arg.length > 2 && arg[0, 2] == "-c"
      opts.by_bytes = true
      set_count(arg[2, arg.length - 2], "bytes", opts)
      next_after_attached(opts)
    elsif arg.length > 7 && arg[0, 8] == "--lines="
      set_count(arg[8, arg.length - 8], "lines", opts)
    elsif arg.length > 7 && arg[0, 8] == "--bytes="
      opts.by_bytes = true
      set_count(arg[8, arg.length - 8], "bytes", opts)
      next_after_attached(opts)
    else
      STDERR.puts "head: unrecognized option '#{arg}'"
      STDERR.puts "Try 'head --help' for more information."
      exit 1
    end
    # -c / --bytes with a separate argument also set by_bytes.
    opts.by_bytes = true if arg == "-c" || arg == "--bytes"
    index += 1
  end
  [opts, files]
end

# No-op hook kept for readability where an attached -cNUM was parsed; by_bytes
# is already set by the caller.
def next_after_attached(opts)
  opts
end

# Return the first part of content per opts, as a string ready to write.
def head_slice(content, opts)
  if opts.by_bytes
    return byte_head(content, opts)
  end
  line_head(content, opts)
end

def byte_head(content, opts)
  total = content.bytesize
  if opts.from_end
    keep = total - opts.count
    keep = 0 if keep < 0
    return content[0, keep]
  end
  take = opts.count < total ? opts.count : total
  content[0, take]
end

def line_head(content, opts)
  lines = content.lines
  if opts.from_end
    keep = lines.length - opts.count
    keep = 0 if keep < 0
    return lines[0, keep].join("")
  end
  take = opts.count < lines.length ? opts.count : lines.length
  lines[0, take].join("")
end

def read_source(name)
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

# Headers print when more than one file is given, unless -q; -v forces them.
print_headers = (files.length > 1 || opts.verbose) && !opts.quiet

exit_code = 0
first = true
files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "head: cannot open '#{cname}' for reading: No such file or directory"
    exit_code = 1
    next
  end
  if cname != "-" && File.directory?(cname)
    STDERR.puts "head: error reading '#{cname}': Is a directory"
    exit_code = 1
    next
  end

  if print_headers
    puts "" unless first
    label = (cname == "-") ? "standard input" : cname
    puts "==> #{label} <=="
  end
  first = false

  STDOUT.write(head_slice(read_source(cname), opts))
end

exit exit_code
