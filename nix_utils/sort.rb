# sort.rb, sort lines of text files (GNU sort, Spinel port).
#
# Read lines from each FILE (or standard input when a file is "-" or none are
# given), sort them, and write the result to standard output.
#
# Flags:
#   -r, --reverse                   reverse the sort order
#   -n, --numeric-sort              compare according to string numerical value
#   -g, --general-numeric-sort      like -n but also handles floats
#   -h, --human-numeric-sort        compare human-readable numbers (2K, 1G)
#   -M, --month-sort                compare as month names (JAN < FEB < ...)
#   -V, --version-sort              natural sort of (version) numbers
#   -R, --random-sort               shuffle, but group identical keys
#   -d, --dictionary-order          consider only blanks and alphanumerics
#   -i, --ignore-nonprinting        consider only printable characters
#   -f, --ignore-case               fold lower case to upper before comparison
#   -b, --ignore-leading-blanks     ignore leading whitespace in comparisons
#   -u, --unique                    output only the first of equal lines
#   -c, --check                     check whether input is sorted; do not sort
#   -C, --check=quiet               like -c, but do not report the first bad line
#   -t SEP, --field-separator=SEP   field delimiter for -k
#   -k KEYDEF, --key=KEYDEF         sort key (field[.char][Opts][,field2[.char2][Opts]])
#   -o FILE, --output=FILE          write result to FILE instead of standard output
#   -z, --zero-terminated           line delimiter is NUL, not newline
#   --sort=WORD                     select sort mode by name
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

class SortOptions
  attr_accessor :separator, :sort_reverse, :numeric, :general_numeric
  attr_accessor :fold_case, :unique, :ignore_blanks
  attr_accessor :human, :month, :version, :random, :dictionary, :ignore_nonprint
  attr_accessor :output, :zero, :check
  attr_accessor :has_sort_key, :sk_field, :sk_char_offset, :sk_numeric
  attr_accessor :sk_key_reverse, :sk_fold_case, :sk_ignore_blanks
  def initialize
    @separator       = nil
    @sort_reverse    = false
    @numeric         = false
    @general_numeric = false
    @fold_case       = false
    @unique          = false
    @ignore_blanks   = false
    @human           = false
    @month           = false
    @version         = false
    @random          = false
    @dictionary      = false
    @ignore_nonprint = false
    @output          = nil
    @zero            = false
    @check           = nil
    @has_sort_key    = false
    @sk_field        = 0
    @sk_char_offset  = 0
    @sk_numeric      = false
    @sk_key_reverse  = false
    @sk_fold_case    = false
    @sk_ignore_blanks = false
  end
end

def strip_leading_blanks(s)
  i = 0
  while i < s.length && (s[i] == " " || s[i] == "\t")
    i += 1
  end
  i > 0 ? s[i, s.length - i] : s
end

def parse_keydef(spec, opts)
  s = "" + spec
  parts = s.split(",", 2)
  start_part = "" + parts[0]

  i = 0
  while i < start_part.length && "0123456789".include?(start_part[i])
    i += 1
  end
  opts.sk_field = i > 0 ? start_part[0, i].to_i : 0

  rest = "" + start_part[i, start_part.length - i]
  if rest.length > 0 && rest[0] == "."
    j = 1
    while j < rest.length && "0123456789".include?(rest[j])
      j += 1
    end
    opts.sk_char_offset = j > 1 ? rest[1, j - 1].to_i : 0
    rest = "" + rest[j, rest.length - j]
  end

  k = 0
  while k < rest.length
    c = rest[k]
    if c == "n" || c == "g"; opts.sk_numeric      = true
    elsif c == "r";           opts.sk_key_reverse  = true
    elsif c == "f";           opts.sk_fold_case    = true
    elsif c == "b";           opts.sk_ignore_blanks = true
    end
    k += 1
  end

  opts.has_sort_key = true
end

def parse_argv(argv, opts)
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
      opts.sort_reverse = true
    elsif arg == "-n" || arg == "--numeric-sort"
      opts.numeric = true
    elsif arg == "-g" || arg == "--general-numeric-sort"
      opts.general_numeric = true
    elsif arg == "-h" || arg == "--human-numeric-sort"
      opts.human = true
    elsif arg == "-M" || arg == "--month-sort"
      opts.month = true
    elsif arg == "-V" || arg == "--version-sort"
      opts.version = true
    elsif arg == "-R" || arg == "--random-sort"
      opts.random = true
    elsif arg == "-d" || arg == "--dictionary-order"
      opts.dictionary = true
    elsif arg == "-i" || arg == "--ignore-nonprinting"
      opts.ignore_nonprint = true
    elsif arg == "-f" || arg == "--ignore-case"
      opts.fold_case = true
    elsif arg == "-b" || arg == "--ignore-leading-blanks"
      opts.ignore_blanks = true
    elsif arg == "-u" || arg == "--unique"
      opts.unique = true
    elsif arg == "-c" || arg == "--check" || arg == "--check=diagnose-first"
      opts.check = "diagnose"
    elsif arg == "-C" || arg == "--check=quiet" || arg == "--check=silent"
      opts.check = "quiet"
    elsif arg == "-z" || arg == "--zero-terminated"
      opts.zero = true
    elsif arg == "-o" || arg == "--output"
      index += 1
      opts.output = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-o"
      opts.output = arg[2, arg.length - 2]
    elsif arg.length > 9 && arg[0, 9] == "--output="
      opts.output = arg[9, arg.length - 9]
    elsif arg.length > 7 && arg[0, 7] == "--sort="
      word = arg[7, arg.length - 7]
      if word == "numeric"; opts.numeric = true
      elsif word == "general-numeric"; opts.general_numeric = true
      elsif word == "human-numeric"; opts.human = true
      elsif word == "month"; opts.month = true
      elsif word == "version"; opts.version = true
      elsif word == "random"; opts.random = true
      end
    elsif arg.length > 16 && arg[0, 16] == "--random-source="
      # Accepted for compatibility; this port uses a fixed shuffle.
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
      parse_keydef(argv[index], opts)
    elsif arg.length > 2 && arg[0, 2] == "-k"
      parse_keydef(arg[2, arg.length - 2], opts)
    elsif arg.length > 6 && arg[0, 6] == "--key="
      parse_keydef(arg[6, arg.length - 6], opts)
    else
      # Multi-letter short flag run.
      letters = arg[1, arg.length - 1]
      li = 0
      valid = true
      while li < letters.length
        c = letters[li]
        if c == "r";         opts.sort_reverse    = true
        elsif c == "n";      opts.numeric         = true
        elsif c == "g";      opts.general_numeric = true
        elsif c == "h";      opts.human           = true
        elsif c == "M";      opts.month           = true
        elsif c == "V";      opts.version         = true
        elsif c == "R";      opts.random          = true
        elsif c == "d";      opts.dictionary      = true
        elsif c == "i";      opts.ignore_nonprint = true
        elsif c == "f";      opts.fold_case       = true
        elsif c == "b";      opts.ignore_blanks   = true
        elsif c == "u";      opts.unique          = true
        elsif c == "c";      opts.check           = "diagnose"
        elsif c == "C";      opts.check           = "quiet"
        elsif c == "z";      opts.zero            = true
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
  files
end

def read_source(name)
  cname = "" + name
  return STDIN.read.to_s if cname == "-"
  File.read(cname)
end

def split_fields(line, sep)
  typed_line = "" + line
  if sep.nil?
    typed_line.split(" ")
  else
    typed_line.split("" + sep)
  end
end

def extract_key_text(body, opts)
  cbody = "" + body
  if opts.sk_field == 0
    text = cbody
  else
    fields = split_fields(cbody, opts.separator)
    fi = opts.sk_field - 1
    text = opts.sk_field <= fields.length ? ("" + fields[fi]) : ""
    if opts.sk_char_offset > 0 && opts.sk_char_offset <= text.length
      text = text[opts.sk_char_offset - 1, text.length - opts.sk_char_offset + 1]
    end
  end
  text = strip_leading_blanks(text) if opts.sk_ignore_blanks
  text
end

def alnum_char?(c)
  o = c.ord
  (o >= 48 && o <= 57) || (o >= 65 && o <= 90) || (o >= 97 && o <= 122)
end

# Keep only blanks and alphanumerics (-d) or only printable characters (-i).
def filter_chars(text, opts)
  return text unless opts.dictionary || opts.ignore_nonprint
  out = ""
  i = 0
  while i < text.length
    c = text[i]
    if opts.dictionary
      out = out + c if alnum_char?(c) || c == " " || c == "\t"
    else
      o = c.ord
      out = out + c if o >= 32 && o <= 126
    end
    i += 1
  end
  out
end

MONTHS = { "JAN" => 1, "FEB" => 2, "MAR" => 3, "APR" => 4, "MAY" => 5,
           "JUN" => 6, "JUL" => 7, "AUG" => 8, "SEP" => 9, "OCT" => 10,
           "NOV" => 11, "DEC" => 12 }

# Month number for -M: unknown or blank sorts before January (0).
def month_num(text)
  t = strip_leading_blanks(text).upcase
  return 0 if t.length < 3
  MONTHS[t[0, 3]] || 0
end

# Value for -h: a number with an optional SI suffix using powers of 1024.
def human_value(text)
  t = strip_leading_blanks(text)
  i = 0
  i += 1 if i < t.length && (t[i] == "-" || t[i] == "+")
  while i < t.length && ("0123456789.".include?(t[i]))
    i += 1
  end
  num = t[0, i].to_f
  suffix = i < t.length ? ("" + t[i]).upcase : ""
  order = suffix == "" ? nil : "KMGTPEZY".index("" + suffix)
  if !order.nil?
    mult = 1.0
    n = 0
    while n <= order
      mult *= 1024.0
      n += 1
    end
    num *= mult
  end
  num
end

# Normalize a string for -V by zero-padding each run of digits so that a plain
# lexicographic comparison yields natural version ordering.
def version_key(text)
  out = ""
  i = 0
  while i < text.length
    c = text[i]
    if "0123456789".include?(c)
      j = i
      while j < text.length && "0123456789".include?(text[j])
        j += 1
      end
      run = text[i, j - i]
      out = out + (("0" * (20 - run.length)) + run) if run.length < 20
      out = out + run if run.length >= 20
      i = j
    else
      out = out + c
      i += 1
    end
  end
  out
end

def make_sort_value(body, opts)
  cbody = "" + body
  if !opts.has_sort_key
    text = cbody
    text = strip_leading_blanks(text) if opts.ignore_blanks
    fold = opts.fold_case
  else
    text = extract_key_text(cbody, opts)
    fold = opts.sk_fold_case || opts.fold_case
  end

  text = filter_chars(text, opts)
  text = text.downcase if fold

  key_numeric = opts.has_sort_key && opts.sk_numeric
  if opts.month
    [month_num(text), text]
  elsif opts.human
    [human_value(text), text]
  elsif opts.version
    version_key(text)
  elsif opts.numeric || opts.general_numeric || key_numeric
    [text.to_f, text]
  else
    text
  end
end

opts = SortOptions.new
files = parse_argv(ARGV, opts)
files = ["-"] if files.empty?

delim = opts.zero ? "\0" : "\n"
lines = []   # record bodies without their terminator
lines.push(""); lines.pop
exit_code = 0

files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "sort: cannot read: #{cname}: No such file or directory"
    exit_code = 1
    next
  end
  if cname != "-" && File.directory?(cname)
    STDERR.puts "sort: read failed: #{cname}: Is a directory"
    exit_code = 1
    next
  end
  content = "" + read_source(cname)
  records = content.split(delim, -1)
  records.pop if !records.empty? && ("" + records.last) == ""
  records.each { |r| lines.push("" + r) }
end

# -c / -C: check whether the input is already sorted and exit without sorting.
if opts.check
  n = 0
  disordered = false
  while n + 1 < lines.length
    a = make_sort_value(lines[n], opts)
    b = make_sort_value(lines[n + 1], opts)
    cmp = a <=> b
    bad = opts.sort_reverse ? cmp < 0 : cmp > 0
    bad = true if opts.unique && cmp == 0
    if bad
      unless opts.check == "quiet"
        STDERR.puts "sort: -:#{n + 2}: disorder: #{lines[n + 1]}"
      end
      disordered = true
      break
    end
    n += 1
  end
  exit(disordered ? 1 : 0)
end

sorted = lines.sort_by { |body| make_sort_value(body, opts) }
sorted = sorted.reverse if opts.sort_reverse

# -R: group identical keys but otherwise shuffle by a stable hash of the key.
if opts.random
  sorted = lines.sort_by { |body| [make_sort_value(body, opts).hash, make_sort_value(body, opts)] }
end

if opts.unique
  uniq = []
  prev = nil
  sorted.each do |body|
    k = make_sort_value(body, opts)
    if prev.nil? || k != prev
      uniq.push(body)
      prev = k
    end
  end
  sorted = uniq
end

out = opts.output ? File.open(opts.output, "w") : STDOUT
sorted.each { |body| out.write(body + delim) }
out.close if opts.output

exit exit_code
