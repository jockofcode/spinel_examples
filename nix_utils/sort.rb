# sort.rb, sort lines of text files (GNU sort, Spinel port).
#
# Read lines from each FILE (or standard input when a file is "-" or none are
# given), sort them, and write the result to standard output.
#
# Flags:
#   -r, --reverse                   reverse the sort order
#   -n, --numeric-sort              compare according to string numerical value
#   -g, --general-numeric-sort      like -n but also handles floats
#   -f, --ignore-case               fold lower case to upper before comparison
#   -b, --ignore-leading-blanks     ignore leading whitespace in comparisons
#   -u, --unique                    output only the first of equal lines
#   -t SEP, --field-separator=SEP   field delimiter for -k
#   -k KEYDEF, --key=KEYDEF         sort key (field[.char][Opts][,field2[.char2][Opts]])
#   --help                          usage
#
# Compile: spinel nix_utils/sort.rb -o nix_utils/bin/sort
# Run:
#   ./bin/sort file.txt
#   ./bin/sort -rn numbers.txt
#   ./bin/sort -t: -k3 /etc/passwd
#
# Core Ruby only (File, STDIN, Array#sort_by); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/sort.rb ...`).

USAGE = "Usage: sort [OPTION]... [FILE]...\n" \
        "Write sorted concatenation of all FILE(s) to standard output.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -r  reverse   -n  numeric   -f  ignore-case   -b  ignore-blanks\n" \
        "  -u  unique    -t SEP  field separator   -k KEYDEF  sort key\n" \
        "  --help"

class SortKey
  attr_accessor :field, :char_offset, :numeric, :reverse, :fold_case, :ignore_blanks
  def initialize
    @field         = 0
    @char_offset   = 0
    @numeric       = false
    @reverse       = false
    @fold_case     = false
    @ignore_blanks = false
  end
end

class SortOptions
  attr_accessor :keys, :separator, :reverse, :numeric, :general_numeric
  attr_accessor :fold_case, :unique, :ignore_blanks
  def initialize
    @keys            = []
    @separator       = nil
    @reverse         = false
    @numeric         = false
    @general_numeric = false
    @fold_case       = false
    @unique          = false
    @ignore_blanks   = false
  end
end

def strip_leading_blanks(s)
  i = 0
  while i < s.length && (s[i] == " " || s[i] == "\t")
    i += 1
  end
  i > 0 ? s[i, s.length - i] : s
end

def parse_keydef(spec)
  key = SortKey.new
  parts = spec.split(",", 2)
  start_part = parts[0]

  i = 0
  while i < start_part.length && "0123456789".include?(start_part[i])
    i += 1
  end
  key.field = i > 0 ? start_part[0, i].to_i : 0

  rest = start_part[i, start_part.length - i]
  if rest.length > 0 && rest[0] == "."
    j = 1
    while j < rest.length && "0123456789".include?(rest[j])
      j += 1
    end
    key.char_offset = j > 1 ? rest[1, j - 1].to_i : 0
    rest = rest[j, rest.length - j]
  end

  k = 0
  while k < rest.length
    c = rest[k]
    if c == "n" || c == "g"; key.numeric       = true
    elsif c == "r";           key.reverse       = true
    elsif c == "f";           key.fold_case     = true
    elsif c == "b";           key.ignore_blanks = true
    end
    k += 1
  end

  key
end

def parse_argv(argv)
  opts = SortOptions.new
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
    elsif arg == "-r" || arg == "--reverse"
      opts.reverse = true
    elsif arg == "-n" || arg == "--numeric-sort"
      opts.numeric = true
    elsif arg == "-g" || arg == "--general-numeric-sort"
      opts.general_numeric = true
    elsif arg == "-f" || arg == "--ignore-case"
      opts.fold_case = true
    elsif arg == "-b" || arg == "--ignore-leading-blanks"
      opts.ignore_blanks = true
    elsif arg == "-u" || arg == "--unique"
      opts.unique = true
    elsif arg == "-s" || arg == "--stable" || arg == "-m" || arg == "--merge"
      # stable / merge: no-op; Ruby's sort is already stable
    elsif arg == "-t" || arg == "--field-separator"
      index += 1
      opts.separator = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-t"
      opts.separator = arg[2, arg.length - 2]
    elsif arg.length > 18 && arg[0, 18] == "--field-separator="
      opts.separator = arg[18, arg.length - 18]
    elsif arg == "-k" || arg == "--key"
      index += 1
      opts.keys.push(parse_keydef(argv[index]))
    elsif arg.length > 2 && arg[0, 2] == "-k"
      opts.keys.push(parse_keydef(arg[2, arg.length - 2]))
    elsif arg.length > 6 && arg[0, 6] == "--key="
      opts.keys.push(parse_keydef(arg[6, arg.length - 6]))
    else
      # Multi-letter short flag run.
      letters = arg[1, arg.length - 1]
      li = 0
      valid = true
      while li < letters.length
        c = letters[li]
        if c == "r";         opts.reverse         = true
        elsif c == "n";      opts.numeric         = true
        elsif c == "g";      opts.general_numeric = true
        elsif c == "f";      opts.fold_case       = true
        elsif c == "b";      opts.ignore_blanks   = true
        elsif c == "u";      opts.unique          = true
        elsif c == "s" || c == "m" # no-op
        else valid = false; break
        end
        li += 1
      end
      unless valid
        STDERR.puts "sort: invalid option -- '#{arg}'"
        STDERR.puts "Try 'sort --help' for more information."
        exit 1
      end
    end
    index += 1
  end
  [opts, files]
end

def read_source(name)
  return STDIN.read if name == "-"
  File.read(name)
end

def split_fields(line, sep)
  sep.nil? ? line.split(" ") : line.split(sep, -1)
end

def extract_key_text(line, key, opts)
  body = line.chomp
  if key.field == 0
    text = body
  else
    fields = split_fields(body, opts.separator)
    text = key.field <= fields.length ? fields[key.field - 1] : ""
    if key.char_offset > 0 && key.char_offset <= text.length
      text = text[key.char_offset - 1, text.length - key.char_offset + 1]
    end
  end
  text = strip_leading_blanks(text) if key.ignore_blanks
  text
end

def make_sort_value(line, opts)
  if opts.keys.empty?
    body = line.chomp
    body = strip_leading_blanks(body) if opts.ignore_blanks
    body = body.downcase if opts.fold_case
    (opts.numeric || opts.general_numeric) ? [body.to_f, body] : body
  else
    key = opts.keys[0]
    text = extract_key_text(line, key, opts)
    text = text.downcase if key.fold_case || opts.fold_case
    use_num = key.numeric || opts.numeric || opts.general_numeric
    use_num ? [text.to_f, text] : text
  end
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

lines = []
exit_code = 0

files.each do |name|
  if name != "-" && !File.exist?(name)
    STDERR.puts "sort: cannot read: #{name}: No such file or directory"
    exit_code = 1
    next
  end
  if name != "-" && File.directory?(name)
    STDERR.puts "sort: read failed: #{name}: Is a directory"
    exit_code = 1
    next
  end
  content = read_source(name)
  content.lines.each { |l| lines.push(l) }
  # Guarantee every line ends with a newline so the sort output is consistent.
  if !lines.empty? && !lines.last.end_with?("\n")
    lines[lines.length - 1] = lines.last + "\n"
  end
end

sorted = lines.sort_by { |line| make_sort_value(line, opts) }
sorted.reverse! if opts.reverse

if opts.unique
  uniq = []
  prev = nil
  sorted.each do |line|
    k = make_sort_value(line, opts)
    if prev.nil? || k != prev
      uniq.push(line)
      prev = k
    end
  end
  sorted = uniq
end

sorted.each { |line| STDOUT.write(line) }

exit exit_code
