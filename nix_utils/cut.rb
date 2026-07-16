# cut.rb, remove sections from each line of files (GNU cut, Spinel port).
#
# Print selected parts of lines from each FILE (or standard input).
# Exactly one of -b, -c, or -f must be specified.
#
# Flags:
#   -b LIST, --bytes=LIST          select only these bytes
#   -c LIST, --characters=LIST     select only these characters
#   -f LIST, --fields=LIST         select only these fields; default delimiter tab
#   -d DELIM, --delimiter=DELIM    field delimiter for -f (default: tab)
#   -F LIST                        like -f but implies -w and -O ' '
#   --complement                   complement the selection
#   -s, --only-delimited           suppress lines without delimiter (-f only)
#   -w, --whitespace-delimited[=trimmed]  fields separated by runs of blanks
#   -O STR, --output-delimiter=STR use STR as the output delimiter
#   -z, --zero-terminated          line delimiter is NUL, not newline
#   -n, --no-partial               (ignored; with -b, do not split multi-byte chars)
#   --help                         usage
#
# LIST is a comma-separated list of ranges, where each range is one of:
#   N     Nth element (1-based)
#   N-    from Nth to end
#   N-M   from Nth to Mth (inclusive)
#   -M    from first to Mth
#
# Compile: spinel nix_utils/cut.rb -o nix_utils/bin/cut
# Run:
#   ./bin/cut -d: -f1 /etc/passwd
#   printf 'a\tb\tc\n' | ./bin/cut -f2
#   ./bin/cut -c1-3 file.txt
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/cut.rb ...`).

USAGE = "Usage: cut OPTION... [FILE]...\n" \
        "Print selected parts of lines from each FILE to standard output.\n" \
        "  -b LIST  bytes   -c LIST  characters   -f LIST  fields\n" \
        "  -d DELIM  delimiter (default tab)   --complement   -s suppress no-delim\n" \
        "  --help"

class CutOptions
  attr_accessor :mode, :list_str, :delimiter, :complement, :suppress, :output_delimiter
  attr_accessor :whitespace, :ws_trimmed, :zero
  def initialize
    @mode             = nil   # :bytes, :chars, :fields
    @list_str         = nil
    @delimiter        = "\t"
    @complement       = false
    @suppress         = false
    @output_delimiter = nil   # defaults to the input delimiter
    @whitespace       = false
    @ws_trimmed       = false
    @zero             = false
  end
end

def parse_argv(argv)
  opts = CutOptions.new
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
    elsif arg == "--complement"
      opts.complement = true
    elsif arg == "-s" || arg == "--only-delimited"
      opts.suppress = true
    elsif arg == "-z" || arg == "--zero-terminated"
      opts.zero = true
    elsif arg == "-w" || arg == "--whitespace-delimited"
      opts.whitespace = true
    elsif arg == "--whitespace-delimited=trimmed"
      opts.whitespace = true; opts.ws_trimmed = true
    elsif arg == "-n" || arg == "--no-partial"
      # ignored
    elsif arg == "-F"
      index += 1; opts.mode = :fields; opts.list_str = argv[index]
      opts.whitespace = true; opts.output_delimiter = " " if opts.output_delimiter.nil?
    elsif arg.length > 2 && arg[0, 2] == "-F"
      opts.mode = :fields; opts.list_str = arg[2, arg.length - 2]
      opts.whitespace = true; opts.output_delimiter = " " if opts.output_delimiter.nil?
    elsif arg == "-O" || arg == "--output-delimiter"
      index += 1; opts.output_delimiter = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-O"
      opts.output_delimiter = arg[2, arg.length - 2]
    elsif arg == "-b" || arg == "--bytes"
      index += 1; opts.mode = :bytes; opts.list_str = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-b"
      opts.mode = :bytes; opts.list_str = arg[2, arg.length - 2]
    elsif arg.length > 8 && arg[0, 8] == "--bytes="
      opts.mode = :bytes; opts.list_str = arg[8, arg.length - 8]
    elsif arg == "-c" || arg == "--characters"
      index += 1; opts.mode = :chars; opts.list_str = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-c"
      opts.mode = :chars; opts.list_str = arg[2, arg.length - 2]
    elsif arg.length > 13 && arg[0, 13] == "--characters="
      opts.mode = :chars; opts.list_str = arg[13, arg.length - 13]
    elsif arg == "-f" || arg == "--fields"
      index += 1; opts.mode = :fields; opts.list_str = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-f"
      opts.mode = :fields; opts.list_str = arg[2, arg.length - 2]
    elsif arg.length > 9 && arg[0, 9] == "--fields="
      opts.mode = :fields; opts.list_str = arg[9, arg.length - 9]
    elsif arg == "-d" || arg == "--delimiter"
      index += 1; opts.delimiter = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-d"
      opts.delimiter = arg[2, arg.length - 2]
    elsif arg.length > 12 && arg[0, 12] == "--delimiter="
      opts.delimiter = arg[12, arg.length - 12]
    elsif arg.length > 19 && arg[0, 19] == "--output-delimiter="
      opts.output_delimiter = arg[19, arg.length - 19]
    else
      STDERR.puts "cut: invalid option -- '#{arg}'"
      STDERR.puts "Try 'cut --help' for more information."
      exit 1
    end
    index += 1
  end
  [opts, files]
end

# Parse a LIST string like "1,3-5,7-" into a sorted unique array of 1-based
# indices. open_end is true when any range is open-ended (N-). max_index is
# returned as the largest finite index or 0 for open ranges.
def parse_list(list_str)
  indices = []
  open_end = false
  list_str.split(",").each do |part|
    dash = part.index("-")
    if dash.nil?
      n = part.to_i
      indices.push(n) if n > 0
    elsif dash == 0
      # "-M" form
      m = part[1, part.length - 1].to_i
      i = 1
      while i <= m
        indices.push(i)
        i += 1
      end
    else
      from_s = part[0, dash]
      to_s   = part[dash + 1, part.length - dash - 1]
      from   = from_s.to_i
      if to_s == ""
        open_end = true
        indices.push(-(from))   # negative sentinel for "from to end"
      else
        to = to_s.to_i
        i  = from
        while i <= to
          indices.push(i)
          i += 1
        end
      end
    end
  end
  [indices, open_end]
end

# True when 1-based index idx is selected by indices/open_end.
def selected?(idx, indices, open_end, complement)
  result = indices.include?(idx)
  if !result && open_end
    indices.each do |s|
      if s < 0 && idx >= -s
        result = true
        break
      end
    end
  end
  complement ? !result : result
end

def cut_chars(body, indices, open_end, complement)
  chars = []
  i = 0
  while i < body.length
    chars.push(body[i])
    i += 1
  end
  result = ""
  c = 0
  while c < chars.length
    result += chars[c] if selected?(c + 1, indices, open_end, complement)
    c += 1
  end
  result
end

def cut_bytes(body, indices, open_end, complement)
  bytes = []
  i = 0
  while i < body.bytesize
    bytes.push(body[i])
    i += 1
  end
  result = ""
  b = 0
  while b < bytes.length
    result += bytes[b] if selected?(b + 1, indices, open_end, complement)
    b += 1
  end
  result
end

# Split a line into fields on runs of blanks (space or tab). With trimmed, drop
# leading and trailing blanks so there is no empty first or last field.
def split_whitespace(body, trimmed)
  fields = []
  cur = ""
  in_field = false
  i = 0
  while i < body.length
    c = body[i]
    if c == " " || c == "\t"
      if in_field
        fields.push(cur); cur = ""; in_field = false
      elsif !trimmed
        # Untrimmed: a leading run of blanks yields an empty leading field once.
        fields.push("") if fields.empty? && i == 0
      end
    else
      in_field = true
      cur += c
    end
    i += 1
  end
  fields.push(cur) if in_field
  fields
end

def cut_fields(body, indices, open_end, complement, delim, suppress, out_delim, opts)
  if opts.whitespace
    has_delim = body.include?(" ") || body.include?("\t")
    return nil if suppress && !has_delim
    return complement ? "" : body if !has_delim
    fields = split_whitespace(body, opts.ws_trimmed)
  else
    return nil if suppress && !body.include?(delim)
    return complement ? "" : body if !body.include?(delim)
    fields = body.split(delim, -1)
  end

  selected = []
  i = 0
  while i < fields.length
    selected.push(fields[i]) if selected?(i + 1, indices, open_end, complement)
    i += 1
  end
  selected.join(out_delim)
end

def read_source(name)
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

opts, files = parse_argv(ARGV)

if opts.mode.nil?
  STDERR.puts "cut: you must specify a list of bytes, characters, or fields"
  exit 1
end

if opts.delimiter.length != 1 && opts.mode == :fields && !opts.whitespace
  STDERR.puts "cut: the delimiter must be a single character"
  exit 1
end

indices, open_end = parse_list(opts.list_str)
out_delim = opts.output_delimiter || opts.delimiter
line_delim = opts.zero ? "\0" : "\n"

files = ["-"] if files.empty?
exit_code = 0

files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "cut: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  content = read_source(cname)
  records = content.split(line_delim, -1)
  # A trailing empty record appears when content ends with the delimiter.
  records.pop if !records.empty? && records.last == ""
  records.each do |body|
    result =
      case opts.mode
      when :chars  then cut_chars(body, indices, open_end, opts.complement)
      when :bytes  then cut_bytes(body, indices, open_end, opts.complement)
      when :fields then cut_fields(body, indices, open_end, opts.complement,
                                   opts.delimiter, opts.suppress, out_delim, opts)
      end
    STDOUT.write(result + line_delim) unless result.nil?
  end
end

exit exit_code
