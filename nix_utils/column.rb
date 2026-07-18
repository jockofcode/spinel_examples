# column.rb, columnate lists (GNU column, Spinel port).
#
# Flags:
#   -t, --table            table mode: align on delimiter
#   -s SEP, --separator=SEP, --input-separator=SEP
#   -o STR, --output-separator=STR  (default two spaces)
#   -c N, --output-width=N
#   -x, --fillrows         fill rows before columns (in free-flow mode)
#   -N NAMES, --table-columns=NAMES  header names
#   -d, --table-noheadings  no header for -N
#   -R COLS, --table-right=COLS  right-align these columns
#   -T COLS, --table-truncate=COLS
#   -H COLS, --table-hide=COLS
#   -l N, --table-columns-limit=N
#   -L, --keep-empty-lines
#   --help, --version
#
# Compile: spinel nix_utils/column.rb -o nix_utils/bin/column

USAGE = "Usage: column [OPTION]... [FILE]...\n" \
        "Columnate lists.\n" \
        "  -t, --table              create a table\n" \
        "  -s SEP, --separator=SEP  input field delimiter\n" \
        "  -o STR                   output column separator (default two spaces)\n" \
        "  -c N                     output width (default 80)\n" \
        "  -x                       fill rows before columns\n" \
        "  -N NAMES                 column names header (comma-separated)\n" \
        "  -d                       suppress header for -N\n" \
        "  -R COLS                  right-align columns (comma-separated)\n" \
        "  -H COLS                  hide columns\n" \
        "  -l N                     limit columns\n" \
        "  -L                       keep empty lines\n" \
        "  --help    --version"

VERSION = "column (nix_utils) 1.0"

require_relative "nix_helpers"

class ColumnOptions
  attr_accessor :table_mode, :input_sep, :output_sep, :output_width
  attr_accessor :fillrows, :col_names, :no_headings, :right_cols
  attr_accessor :trunc_cols, :hide_cols, :col_limit, :keep_empty
  def initialize
    @table_mode  = false
    @input_sep   = nil    # nil = whitespace
    @output_sep  = "  "
    @output_width = 80
    @fillrows    = false
    @col_names   = nil
    @no_headings = false
    @right_cols  = []
    @trunc_cols  = []
    @hide_cols   = []
    @col_limit   = nil
    @keep_empty  = false
  end
end

opts         = ColumnOptions.new
files        = []
options_done = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || arg == "-"
    files.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-t" || arg == "--table"
    opts.table_mode = true
  elsif arg == "-x" || arg == "--fillrows"
    opts.fillrows = true
  elsif arg == "-d" || arg == "--table-noheadings"
    opts.no_headings = true
  elsif arg == "-L" || arg == "--keep-empty-lines"
    opts.keep_empty = true
  elsif arg == "-s" || arg == "--separator" || arg == "--input-separator"
    index += 1; opts.input_sep = coerce(ARGV[index])
  elsif arg.length > 12 && arg[0, 12] == "--separator="
    opts.input_sep = arg[12, arg.length - 12]
  elsif arg.length > 18 && arg[0, 18] == "--input-separator="
    opts.input_sep = arg[18, arg.length - 18]
  elsif arg.length > 2 && arg[0, 2] == "-s"
    opts.input_sep = arg[2, arg.length - 2]
  elsif arg == "-o" || arg == "--output-separator"
    index += 1; opts.output_sep = coerce(ARGV[index])
  elsif arg.length > 19 && arg[0, 19] == "--output-separator="
    opts.output_sep = arg[19, arg.length - 19]
  elsif arg.length > 2 && arg[0, 2] == "-o"
    opts.output_sep = arg[2, arg.length - 2]
  elsif arg == "-c" || arg == "--output-width"
    index += 1; opts.output_width = coerce(ARGV[index]).to_i
  elsif arg.length > 2 && arg[0, 2] == "-c"
    opts.output_width = arg[2, arg.length - 2].to_i
  elsif arg.length > 15 && arg[0, 15] == "--output-width="
    opts.output_width = arg[15, arg.length - 15].to_i
  elsif arg == "-N" || arg == "--table-columns"
    index += 1; opts.col_names = coerce(ARGV[index]).split(",")
  elsif arg.length > 17 && arg[0, 17] == "--table-columns="
    opts.col_names = arg[17, arg.length - 17].split(",")
  elsif arg.length > 2 && arg[0, 2] == "-N"
    opts.col_names = arg[2, arg.length - 2].split(",")
  elsif arg == "-R" || arg == "--table-right"
    index += 1; opts.right_cols = coerce(ARGV[index]).split(",")
  elsif arg.length > 14 && arg[0, 14] == "--table-right="
    opts.right_cols = arg[14, arg.length - 14].split(",")
  elsif arg.length > 2 && arg[0, 2] == "-R"
    opts.right_cols = arg[2, arg.length - 2].split(",")
  elsif arg == "-T" || arg == "--table-truncate"
    index += 1; opts.trunc_cols = coerce(ARGV[index]).split(",")
  elsif arg == "-H" || arg == "--table-hide"
    index += 1; opts.hide_cols = coerce(ARGV[index]).split(",")
  elsif arg.length > 13 && arg[0, 13] == "--table-hide="
    opts.hide_cols = arg[13, arg.length - 13].split(",")
  elsif arg == "-l" || arg == "--table-columns-limit"
    index += 1; opts.col_limit = coerce(ARGV[index]).to_i
  elsif arg.length > 22 && arg[0, 22] == "--table-columns-limit="
    opts.col_limit = arg[22, arg.length - 22].to_i
  elsif arg[0] != "-"
    files.push(arg)
  else
    die("column: invalid option -- '#{arg}'\nTry 'column --help' for more information.")
  end
  index += 1
end

files = ["-"] if files.empty?

# Read all input
lines = []
files.each do |f|
  cf = "" + f
  content = (cf == "-") ? STDIN.read : File.read(cf)
  content.split("\n", -1).each do |line|
    lines.push("" + line)
  end
end

# Drop trailing empty line from split
lines.pop if !lines.empty? && ("" + lines.last) == ""

if opts.table_mode
  # ── Table mode ────────────────────────────────────────────────────
  rows = []
  lines.each do |line|
    cl = "" + line
    next if !opts.keep_empty && cl == ""
    if opts.input_sep.nil?
      fields = cl.split
    else
      fields = cl.split("" + opts.input_sep, -1)
    end
    if !opts.col_limit.nil?
      fields = fields[0, opts.col_limit]
    end
    rows.push(fields)
  end

  # Prepend header row if -N given and not -d
  unless opts.col_names.nil? || opts.no_headings
    rows.unshift(opts.col_names)
  end

  # Build column names index for right/hide/trunc
  col_name_idx = {}
  unless opts.col_names.nil?
    i = 0
    while i < opts.col_names.length
      col_name_idx["" + opts.col_names[i]] = i + 1
      i += 1
    end
  end

  def col_num(spec, col_name_idx)
    cs = "" + spec
    if col_name_idx.key?(cs)
      col_name_idx[cs]
    else
      cs.to_i
    end
  end

  right_set = {}
  opts.right_cols.each { |c| right_set[col_num("" + c, col_name_idx)] = true }
  hide_set  = {}
  opts.hide_cols.each  { |c| hide_set[col_num("" + c, col_name_idx)] = true }

  # Compute column widths
  num_cols = 0
  rows.each { |r| num_cols = r.length if r.length > num_cols }

  widths = []
  num_cols.times { widths.push(0) }

  rows.each do |row|
    ci = 0
    while ci < row.length
      fw = ("" + row[ci]).length
      widths[ci] = fw if fw > widths[ci]
      ci += 1
    end
  end

  osep = "" + opts.output_sep

  rows.each do |row|
    parts = []
    ci = 0
    while ci < num_cols
      next_ci = ci + 1
      next if hide_set[next_ci]
      cell  = ci < row.length ? ("" + row[ci]) : ""
      w     = widths[ci]
      # Last visible column: no padding needed
      last_visible = true
      cj = ci + 1
      while cj < num_cols
        last_visible = false unless hide_set[cj + 1]
        cj += 1
      end
      if last_visible
        parts.push(cell)
      elsif right_set[next_ci]
        parts.push(cell.rjust(w))
      else
        parts.push(cell.ljust(w))
      end
      ci += 1
    end
    puts parts.join(osep)
  end

else
  # ── Free-flow mode ─────────────────────────────────────────────────
  tokens = []
  lines.each do |line|
    cl = "" + line
    if opts.keep_empty && cl == ""
      tokens.push("")
    else
      cl.split.each { |t| tokens.push("" + t) }
    end
  end

  return if tokens.empty?

  max_width = 1
  tokens.each { |t| w = ("" + t).length; max_width = w if w > max_width }

  col_width  = max_width + 2  # at least 2 spaces between columns
  num_cols   = opts.output_width / col_width
  num_cols   = 1 if num_cols < 1
  num_rows   = (tokens.length + num_cols - 1) / num_cols

  if opts.fillrows
    # Fill row by row
    r = 0
    while r < num_rows
      row_parts = []
      c = 0
      while c < num_cols
        idx = r * num_cols + c
        if idx < tokens.length
          t = "" + tokens[idx]
          if c == num_cols - 1 || idx == tokens.length - 1
            row_parts.push(t)
          else
            row_parts.push(t.ljust(col_width - 1))
          end
        end
        c += 1
      end
      puts row_parts.join(" ") unless row_parts.empty?
      r += 1
    end
  else
    # Fill column by column
    r = 0
    while r < num_rows
      row_parts = []
      c = 0
      while c < num_cols
        idx = c * num_rows + r
        if idx < tokens.length
          t = "" + tokens[idx]
          if c == num_cols - 1 || idx + num_rows >= tokens.length
            row_parts.push(t)
          else
            row_parts.push(t.ljust(col_width - 1))
          end
        end
        c += 1
      end
      puts row_parts.join(" ") unless row_parts.empty?
      r += 1
    end
  end
end
