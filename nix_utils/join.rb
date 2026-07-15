# join.rb, join lines of two files on a common field (GNU join, Spinel port).
#
# For each pair of input lines from FILE1 and FILE2 with identical join fields,
# writes a line to stdout combining the two records. Both files must be sorted
# on the join field.
#
# Flags:
#   -1 FIELD     join on FIELD of FILE1 (default 1)
#   -2 FIELD     join on FIELD of FILE2 (default 1)
#   -j FIELD     equivalent to: -1 FIELD -2 FIELD
#   -t CHAR      use CHAR as input/output field separator (default: whitespace)
#   -a FILENUM   print unpairable lines from FILENUM (1 or 2)
#   -v FILENUM   like -a, but suppress joined output lines
#   -e EMPTY     replace missing input fields with EMPTY
#   -o LIST      use FORMAT for output; LIST is comma-separated FILENUM.FIELD specs
#   -i           ignore case differences when comparing fields
#   -z           NUL-terminated input/output
#   --nocheck-order  do not check input is sorted
#   --check-order    fail if input is not sorted
#   --help       usage
#
# Compile: spinel nix_utils/join.rb -o nix_utils/bin/join
# Run:
#   join file1.txt file2.txt
#   join -t: -1 1 -2 2 file1.txt file2.txt

USAGE = "Usage: join [OPTION]... FILE1 FILE2\n" \
        "Join lines of two sorted files on a common field.\n" \
        "  -1 FIELD  join on FIELD of FILE1 (default 1)\n" \
        "  -2 FIELD  join on FIELD of FILE2 (default 1)\n" \
        "  -j FIELD  same -1/-2 FIELD\n" \
        "  -t CHAR   field separator (default: whitespace)\n" \
        "  -a N      also print unpairable lines from file N (1 or 2)\n" \
        "  -v N      like -a, but only unpairable lines\n" \
        "  -e EMPTY  substitute EMPTY for missing fields\n" \
        "  -o LIST   output format: comma-separated FILENUM.FIELD specs\n" \
        "  -i        ignore case\n" \
        "  -z        NUL-terminated lines\n" \
        "  --help"

class JoinOptions
  attr_accessor :field1, :field2, :separator, :unpairable, :only_unpairable
  attr_accessor :empty, :output_format, :ignore_case, :zero, :nocheck
  def initialize
    @field1         = 1
    @field2         = 1
    @separator      = nil   # nil = whitespace
    @unpairable     = []    # [1] and/or [2]
    @only_unpairable = []
    @empty          = ""
    @output_format  = nil   # nil = default
    @ignore_case    = false
    @zero           = false
    @nocheck        = false
  end
end

def parse_output_spec(spec)
  # "0" means join field; "1.N" means field N of file 1; "2.N" for file 2
  parts = []
  spec.split(",").each do |s|
    s = s.strip
    if s == "0"
      parts.push([0, 0])
    elsif s.include?(".")
      dot = s.index(".")
      filenum = s[0, dot].to_i
      fieldnum = s[dot + 1, s.length - dot - 1].to_i
      parts.push([filenum, fieldnum])
    end
  end
  parts
end

def parse_argv(argv)
  opts = JoinOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg); index += 1; next
    end
    if arg == "--"; options_done = true; index += 1; next; end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "--nocheck-order"; opts.nocheck = true
    elsif arg == "--check-order"; opts.nocheck = false
    elsif arg == "-i" || arg == "--ignore-case"; opts.ignore_case = true
    elsif arg == "-z" || arg == "--zero-terminated"; opts.zero = true
    elsif arg == "-1"
      index += 1; opts.field1 = argv[index].to_i
    elsif arg == "-2"
      index += 1; opts.field2 = argv[index].to_i
    elsif arg == "-j"
      index += 1
      n = argv[index].to_i
      opts.field1 = n; opts.field2 = n
    elsif arg == "-t"
      index += 1; opts.separator = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-t"
      opts.separator = arg[2, arg.length - 2]
    elsif arg == "-a"
      index += 1; opts.unpairable.push(argv[index].to_i)
    elsif arg == "-v"
      index += 1
      n = argv[index].to_i
      opts.only_unpairable.push(n)
      opts.unpairable.push(n)
    elsif arg == "-e"
      index += 1; opts.empty = argv[index]
    elsif arg == "-o"
      index += 1; opts.output_format = parse_output_spec(argv[index])
    elsif arg.length > 2 && arg[0, 2] == "-o"
      opts.output_format = parse_output_spec(arg[2, arg.length - 2])
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "i"; opts.ignore_case = true
        elsif letter == "z"; opts.zero = true
        else
          STDERR.puts "join: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

def split_fields(line, sep)
  if sep.nil?
    # Whitespace splitting: any run of blanks, leading blanks stripped
    fields = []
    word = ""
    in_word = false
    i = 0
    while i < line.length
      ch = line[i]
      if ch == " " || ch == "\t"
        if in_word
          fields.push(word)
          word = ""
          in_word = false
        end
      else
        word += ch
        in_word = true
      end
      i += 1
    end
    fields.push(word) if in_word
    fields
  else
    line.split(sep, -1)
  end
end

def get_field(fields, n, empty)
  # n is 1-based
  n <= fields.length ? fields[n - 1] : empty
end

def read_file_lines(name, opts)
  content = (name == "-") ? STDIN.read : File.read(name)
  delim = opts.zero ? "\0" : "\n"
  if delim == "\n"
    lines = []
    content.lines.each do |l|
      lines.push(l.end_with?("\n") ? l[0, l.length - 1] : l)
    end
    lines
  else
    parts = content.split("\0", -1)
    parts.pop if !parts.empty? && parts.last == ""
    parts
  end
end

def format_line(fields1, fields2, join_key, opts)
  sep = opts.separator || " "
  term = opts.zero ? "\0" : "\n"

  if opts.output_format
    parts = []
    opts.output_format.each do |spec|
      filenum, fieldnum = spec
      if filenum == 0
        parts.push(join_key)
      elsif filenum == 1
        parts.push(get_field(fields1, fieldnum, opts.empty))
      else
        parts.push(get_field(fields2, fieldnum, opts.empty))
      end
    end
    STDOUT.write(parts.join(sep) + term)
  else
    # Default: join_key followed by all fields from file1 (except join field)
    # then all fields from file2 (except join field)
    parts = [join_key]
    idx = 0
    fields1.each do |f|
      parts.push(f) unless idx + 1 == opts.field1
      idx += 1
    end
    idx = 0
    fields2.each do |f|
      parts.push(f) unless idx + 1 == opts.field2
      idx += 1
    end
    STDOUT.write(parts.join(sep) + term)
  end
end

def print_unpairable(line, filenum, opts)
  return unless opts.unpairable.include?(filenum)
  term = opts.zero ? "\0" : "\n"
  STDOUT.write(line + term)
end

opts, files = parse_argv(ARGV)

if files.length != 2
  STDERR.puts "join: missing operand after #{files.length == 1 ? "'#{files[0]}'" : "'join'"}"
  exit 1
end

files.each do |f|
  if f != "-" && !File.exist?(f)
    STDERR.puts "join: #{f}: No such file or directory"
    exit 1
  end
end

lines1 = read_file_lines(files[0], opts)
lines2 = read_file_lines(files[1], opts)

# Parse all lines into [key, fields] pairs
records1 = []
lines1.each do |l|
  fields = split_fields(l, opts.separator)
  key = get_field(fields, opts.field1, "")
  key = key.downcase if opts.ignore_case
  records1.push([key, fields, l])
end

records2 = []
lines2.each do |l|
  fields = split_fields(l, opts.separator)
  key = get_field(fields, opts.field2, "")
  key = key.downcase if opts.ignore_case
  records2.push([key, fields, l])
end

show_joined = opts.only_unpairable.length == 0 ||
              (opts.only_unpairable.include?(1) && opts.only_unpairable.include?(2))
# If -v is used, only_unpairable is set; we suppress joined unless -a is also specified
show_joined = !(!opts.only_unpairable.empty? && opts.unpairable.length == opts.only_unpairable.length)

i = 0
j = 0
used1 = []
used2 = []

while i < records1.length || j < records2.length
  k1 = i < records1.length ? records1[i][0] : nil
  k2 = j < records2.length ? records2[j][0] : nil

  if k1.nil?
    print_unpairable(records2[j][2], 2, opts)
    j += 1
  elsif k2.nil?
    print_unpairable(records1[i][2], 1, opts)
    i += 1
  elsif k1 < k2
    print_unpairable(records1[i][2], 1, opts)
    i += 1
  elsif k1 > k2
    print_unpairable(records2[j][2], 2, opts)
    j += 1
  else
    # Equal keys: join all matching records from both files
    i_start = i
    while i < records1.length && records1[i][0] == k1
      j2 = j
      while j2 < records2.length && records2[j2][0] == k1
        unless show_joined == false
          format_line(records1[i][1], records2[j2][1], k1, opts)
        end
        j2 += 1
      end
      i += 1
    end
    j_end = j
    while j_end < records2.length && records2[j_end][0] == k1
      j_end += 1
    end
    j = j_end
  end
end
