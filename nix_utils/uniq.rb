# uniq.rb, report or omit repeated adjacent lines (GNU uniq, Spinel port).
#
# Filter adjacent matching lines from FILE (or standard input), writing to
# standard output or to OUTPUT if given. Lines must be adjacent to be
# considered duplicates; pipe through sort(1) first when order matters.
#
# Flags:
#   -c, --count            prefix lines by the number of occurrences
#   -d, --repeated         only print duplicate lines (one per group)
#   -D                     print all duplicate lines
#   --all-repeated[=METHOD]  like -D, with none/prepend/separate group spacing
#   --group[=METHOD]       show all items, separating groups (separate default)
#   -u, --unique           only print lines that appear exactly once
#   -i, --ignore-case      ignore differences in case when comparing
#   -f N, --skip-fields=N  skip N fields before comparing
#   -s N, --skip-chars=N   skip N characters before comparing
#   -w N, --check-chars=N  compare at most N characters
#   -z, --zero-terminated  line delimiter is NUL, not newline
#   --help                 usage
#
# Compile: spinel nix_utils/uniq.rb -o nix_utils/bin/uniq
# Run:
#   ./bin/uniq file.txt
#   sort file.txt | ./bin/uniq -c
#   ./bin/uniq -d repeated.txt
#
# Core Ruby only (File, STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/uniq.rb ...`).

USAGE = "Usage: uniq [OPTION]... [INPUT [OUTPUT]]\n" \
        "Filter adjacent matching lines from INPUT (or stdin) to OUTPUT (or stdout).\n" \
        "  -c  prefix count   -d  only repeated   -u  only unique   -i  ignore case\n" \
        "  -f N  skip N fields   -s N  skip N chars   -w N  compare N chars\n" \
        "  --help"

class UniqOptions
  attr_accessor :count, :repeated, :all_repeated, :unique
  attr_accessor :ignore_case, :skip_fields, :skip_chars, :check_chars
  attr_accessor :all_repeated_method, :group, :group_method, :zero
  def initialize
    @count        = false
    @repeated     = false
    @all_repeated = false
    @unique       = false
    @ignore_case  = false
    @skip_fields  = 0
    @skip_chars   = 0
    @check_chars  = 0   # 0 means unlimited
    @all_repeated_method = "none"
    @group        = false
    @group_method = "separate"
    @zero         = false
  end
end

def parse_argv(argv)
  opts = UniqOptions.new
  operands = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      operands.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-c" || arg == "--count"
      opts.count = true
    elsif arg == "-d" || arg == "--repeated"
      opts.repeated = true
    elsif arg == "-D"
      opts.all_repeated = true
      opts.all_repeated_method = "none"
    elsif arg == "--all-repeated"
      opts.all_repeated = true
      opts.all_repeated_method = "none"
    elsif arg.length > 15 && arg[0, 15] == "--all-repeated="
      opts.all_repeated = true
      opts.all_repeated_method = arg[15, arg.length - 15]
    elsif arg == "--group"
      opts.group = true
    elsif arg.length > 8 && arg[0, 8] == "--group="
      opts.group = true
      opts.group_method = arg[8, arg.length - 8]
    elsif arg == "-z" || arg == "--zero-terminated"
      opts.zero = true
    elsif arg == "-u" || arg == "--unique"
      opts.unique = true
    elsif arg == "-i" || arg == "--ignore-case"
      opts.ignore_case = true
    elsif arg == "-f" || arg == "--skip-fields"
      index += 1
      opts.skip_fields = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-f"
      opts.skip_fields = arg[2, arg.length - 2].to_i
    elsif arg.length > 14 && arg[0, 14] == "--skip-fields="
      opts.skip_fields = arg[14, arg.length - 14].to_i
    elsif arg == "-s" || arg == "--skip-chars"
      index += 1
      opts.skip_chars = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.skip_chars = arg[2, arg.length - 2].to_i
    elsif arg.length > 13 && arg[0, 13] == "--skip-chars="
      opts.skip_chars = arg[13, arg.length - 13].to_i
    elsif arg == "-w" || arg == "--check-chars"
      index += 1
      opts.check_chars = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-w"
      opts.check_chars = arg[2, arg.length - 2].to_i
    elsif arg.length > 14 && arg[0, 14] == "--check-chars="
      opts.check_chars = arg[14, arg.length - 14].to_i
    else
      STDERR.puts "uniq: invalid option -- '#{arg}'"
      STDERR.puts "Try 'uniq --help' for more information."
      exit 1
    end
    index += 1
  end
  in_file  = operands.length > 0 ? operands[0] : "-"
  out_file = operands.length > 1 ? operands[1] : nil
  [opts, in_file, out_file]
end

# Derive the comparison key for a record per the skip/check options.
def comparison_key(record, opts)
  body = record

  # Skip leading fields (whitespace-separated).
  if opts.skip_fields > 0
    i = 0
    fields_skipped = 0
    while fields_skipped < opts.skip_fields && i < body.length
      # Skip past any whitespace before this field.
      while i < body.length && (body[i] == " " || body[i] == "\t")
        i += 1
      end
      # Skip past the field itself.
      while i < body.length && body[i] != " " && body[i] != "\t"
        i += 1
      end
      fields_skipped += 1
    end
    body = i < body.length ? body[i, body.length - i] : ""
  end

  # Skip leading characters.
  if opts.skip_chars > 0
    start = opts.skip_chars < body.length ? opts.skip_chars : body.length
    body = body[start, body.length - start]
  end

  # Limit comparison width.
  if opts.check_chars > 0 && body.length > opts.check_chars
    body = body[0, opts.check_chars]
  end

  opts.ignore_case ? body.downcase : body
end

def emit(out, body, count, opts, delim)
  if opts.count
    out.write(count.to_s.rjust(7) + " " + body + delim)
  else
    out.write(body + delim)
  end
end

opts, in_file, out_file = parse_argv(ARGV)

in_name = "" + in_file
content =
  if in_name == "-"
    STDIN.read
  else
    unless File.exist?(in_name)
      STDERR.puts "uniq: #{in_name}: No such file or directory"
      exit 1
    end
    File.read(in_name)
  end

out = out_file ? File.open("" + out_file, "w") : STDOUT
delim = opts.zero ? "\0" : "\n"

records = content.split(delim, -1)
# Drop the trailing empty record produced when content ends with the delimiter.
records.pop if !records.empty? && records.last == ""

# Group adjacent records that share a comparison key. Each group keeps the
# records themselves so -D/--group can reproduce every line.
groups = []
records.each do |record|
  key = comparison_key(record, opts)
  if groups.empty? || groups.last[0] != key
    groups.push([key, [record]])
  else
    groups.last[1].push(record)
  end
end

if opts.group
  # --group: print every record, separating groups with a blank line.
  first = true
  groups.each do |g|
    lines = g[1]
    prepend = opts.group_method == "prepend" || opts.group_method == "both"
    append  = opts.group_method == "append"  || opts.group_method == "both"
    separate = opts.group_method == "separate"
    out.write(delim) if prepend || (separate && !first)
    lines.each { |body| out.write(body + delim) }
    out.write(delim) if append
    first = false
  end
elsif opts.all_repeated
  # -D / --all-repeated: print every record of each duplicate group.
  first_group = true
  groups.each do |g|
    lines = g[1]
    next if lines.length <= 1
    if opts.all_repeated_method == "prepend"
      out.write(delim)
    elsif opts.all_repeated_method == "separate" && !first_group
      out.write(delim)
    end
    lines.each { |body| emit(out, body, 1, opts, delim) }
    first_group = false
  end
else
  # One representative record per group, filtered by -d / -u.
  groups.each do |g|
    body  = g[1][0]
    count = g[1].length
    if opts.repeated
      emit(out, body, count, opts, delim) if count > 1
    elsif opts.unique
      emit(out, body, count, opts, delim) if count == 1
    else
      emit(out, body, count, opts, delim)
    end
  end
end

out.close if out_file

exit 0
