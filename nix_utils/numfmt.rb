# numfmt.rb, reformat numbers on a line (GNU numfmt, Spinel port).
#
# Flags:
#   --from=UNIT       scale input: none, auto, si, iec, iec-i
#   --to=UNIT         scale output (same set)
#   --from-unit=N     input unit multiplier
#   --to-unit=N       output unit multiplier
#   --suffix=SUFFIX   append suffix to output
#   --round=METHOD    up, down, from-zero (default), towards-zero, nearest
#   --padding=N       pad/align
#   --format=FORMAT   printf-style %f format
#   --field=FIELDS    which fields to convert (default 1)
#   --header[=N]      pass through first N lines unchanged
#   --invalid=MODE    abort (default), fail, warn, ignore
#   --grouping        comma grouping
#   --debug
#   -z, --zero-terminated   unsupported
#   --help, --version
#
# Compile: spinel nix_utils/numfmt.rb -o nix_utils/bin/numfmt

USAGE = "Usage: numfmt [OPTION]... [NUMBER]...\n" \
        "Reformat NUMBER(s), or the numbers from standard input.\n" \
        "  --from=UNIT    --to=UNIT    (none, auto, si, iec, iec-i)\n" \
        "  --from-unit=N  --to-unit=N\n" \
        "  --suffix=SUFF  --round=METHOD  --padding=N  --format=FMT\n" \
        "  --field=FIELDS  --header[=N]  --invalid=MODE  --grouping\n" \
        "  --help    --version\n" \
        "  -z/--zero-terminated unsupported (NUL bytes not possible in this build)"

VERSION = "numfmt (nix_utils) 1.0"

require_relative "nix_helpers"

class NumfmtOptions
  attr_accessor :from_unit_type, :to_unit_type, :from_unit_mult, :to_unit_mult
  attr_accessor :suffix, :round_method, :padding, :format_str
  attr_accessor :field_str, :header_count, :invalid_mode, :grouping, :debug
  def initialize
    @from_unit_type = "none"
    @to_unit_type   = "none"
    @from_unit_mult = 1
    @to_unit_mult   = 1
    @suffix         = nil
    @round_method   = "from-zero"
    @padding        = 0
    @format_str     = nil
    @field_str      = "1"
    @header_count   = 0
    @invalid_mode   = "abort"
    @grouping       = false
    @debug          = false
  end
end

opts         = NumfmtOptions.new
numbers      = []
options_done = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || arg == "-"
    numbers.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg.length > 7 && arg[0, 7] == "--from="
    opts.from_unit_type = arg[7, arg.length - 7]
  elsif arg.length > 5 && arg[0, 5] == "--to="
    opts.to_unit_type = arg[5, arg.length - 5]
  elsif arg.length > 12 && arg[0, 12] == "--from-unit="
    opts.from_unit_mult = arg[12, arg.length - 12].to_i
  elsif arg.length > 10 && arg[0, 10] == "--to-unit="
    opts.to_unit_mult = arg[10, arg.length - 10].to_i
  elsif arg.length > 9 && arg[0, 9] == "--suffix="
    opts.suffix = arg[9, arg.length - 9]
  elsif arg.length > 8 && arg[0, 8] == "--round="
    opts.round_method = arg[8, arg.length - 8]
  elsif arg.length > 10 && arg[0, 10] == "--padding="
    opts.padding = arg[10, arg.length - 10].to_i
  elsif arg.length > 9 && arg[0, 9] == "--format="
    opts.format_str = arg[9, arg.length - 9]
  elsif arg.length > 8 && arg[0, 8] == "--field="
    opts.field_str = arg[8, arg.length - 8]
  elsif arg == "--header"
    opts.header_count = 1
  elsif arg.length > 9 && arg[0, 9] == "--header="
    opts.header_count = arg[9, arg.length - 9].to_i
  elsif arg.length > 10 && arg[0, 10] == "--invalid="
    opts.invalid_mode = arg[10, arg.length - 10]
  elsif arg == "--grouping"
    opts.grouping = true
  elsif arg == "--debug"
    opts.debug = true
  elsif arg == "-z" || arg == "--zero-terminated"
    die("numfmt: -z/--zero-terminated is unsupported in this build")
  elsif arg[0] != "-"
    numbers.push(arg)
  else
    die("numfmt: unrecognized option '#{arg}'\nTry 'numfmt --help' for more information.")
  end
  index += 1
end

# ── Unit suffix tables ──────────────────────────────────────────────────────

SI_SUFFIX_MAP = {
  "k" => 1000, "K" => 1000,
  "M" => 1000 * 1000, "G" => 1000 * 1000 * 1000,
  "T" => 1000 * 1000 * 1000 * 1000,
}

IEC_SUFFIX_MAP = {
  "K" => 1024, "M" => 1024 * 1024, "G" => 1024 * 1024 * 1024,
  "T" => 1024 * 1024 * 1024 * 1024,
}

IEC_I_SUFFIX_MAP = {
  "Ki" => 1024, "Mi" => 1024 * 1024, "Gi" => 1024 * 1024 * 1024,
  "Ti" => 1024 * 1024 * 1024 * 1024,
}

def parse_number_with_unit(text, unit_type, suffix_hint)
  s = "" + text
  # Strip optional matching suffix from input
  unless suffix_hint.nil?
    csuffix = "" + suffix_hint
    if s.end_with?(csuffix)
      s = s[0, s.length - csuffix.length]
    end
  end
  ut = "" + unit_type
  if ut == "none"
    return s.to_f
  end
  # Try each suffix table
  maps =
    if ut == "si"
      [SI_SUFFIX_MAP]
    elsif ut == "iec"
      [IEC_SUFFIX_MAP]
    elsif ut == "iec-i"
      [IEC_I_SUFFIX_MAP]
    else  # auto
      [IEC_I_SUFFIX_MAP, IEC_SUFFIX_MAP, SI_SUFFIX_MAP]
    end
  maps.each do |map|
    map.each do |sfx, mult|
      if s.end_with?(sfx)
        base = s[0, s.length - sfx.length]
        return base.to_f * mult
      end
    end
  end
  s.to_f
end

SI_OUT_UNITS  = ["", "k", "M", "G", "T", "P"]
IEC_OUT_UNITS = ["", "K", "M", "G", "T", "P"]
IEC_I_OUT_UNITS = ["", "Ki", "Mi", "Gi", "Ti", "Pi"]

def scale_to_unit(val, unit_type, to_unit_mult)
  v = val.to_f / to_unit_mult
  ut = "" + unit_type
  return [v, ""] if ut == "none"
  divisor = (ut == "si") ? 1000.0 : 1024.0
  units =
    if ut == "si"
      SI_OUT_UNITS
    elsif ut == "iec"
      IEC_OUT_UNITS
    else
      IEC_I_OUT_UNITS
    end
  idx = 0
  while idx < units.length - 1 && v.abs >= divisor
    v = v / divisor
    idx += 1
  end
  [v, "" + units[idx]]
end

def apply_rounding(val, method)
  m = "" + method
  if m == "up"
    val >= 0 ? val.ceil : -(-val).floor
  elsif m == "down"
    val >= 0 ? val.floor : -(-val).ceil
  elsif m == "towards-zero"
    val.to_i.to_f
  elsif m == "nearest"
    val.round.to_f
  else  # from-zero (default)
    val >= 0 ? val.ceil : -(-val).ceil
  end
end

def format_scaled(val, unit_suffix, opts)
  us = "" + unit_suffix
  sf = opts.suffix.nil? ? "" : ("" + opts.suffix)
  ut = "" + opts.to_unit_type
  if ut == "none"
    int_val = val.to_i
    s =
      if opts.grouping
        # Simple comma grouping
        neg = int_val < 0
        digits = (neg ? -int_val : int_val).to_s
        grouped = ""
        i = 0
        while i < digits.length
          grouped += "," if i > 0 && (digits.length - i) % 3 == 0
          grouped += digits[i]
          i += 1
        end
        (neg ? "-" : "") + grouped
      else
        int_val.to_s
      end
    result = s + sf
  else
    # Values >= 10 show no decimal; values < 10 always show one decimal
    abs_val = val < 0 ? -val : val
    if abs_val >= 10.0
      result = val.round.to_s + us + sf
    else
      whole = val.to_i
      frac  = ((val - whole).abs * 10.0).round.to_i
      if frac >= 10
        whole += 1 if val >= 0
        frac   = 0
      end
      result = "#{whole}.#{frac}#{us}#{sf}"
    end
  end
  unless opts.format_str.nil?
    fmt = "" + opts.format_str
    # Simple %[flags][width][.prec]f substitution
    result = sprintf(fmt, val) + us + sf
  end
  if opts.padding != 0
    width = opts.padding.abs
    if opts.padding > 0
      result = result.rjust(width)
    else
      result = result.ljust(width)
    end
  end
  result
end

def convert_number(num_str, opts)
  s = "" + num_str
  val = parse_number_with_unit(s, opts.from_unit_type, opts.suffix) * opts.from_unit_mult
  su_result = scale_to_unit(val, opts.to_unit_type, opts.to_unit_mult)
  scaled = su_result[0].to_f
  unit_suffix = "" + su_result[1].to_s
  rounded = apply_rounding(scaled, opts.round_method)
  format_scaled(rounded, unit_suffix, opts)
end

def process_line(line, opts, header_remaining)
  s = "" + line
  if header_remaining > 0
    puts s
    return header_remaining - 1
  end
  fr_result = parse_field_ranges(opts.field_str)
  field_indices = fr_result[0]
  open_end = (fr_result[1].to_s == "true")
  fields = s.split(" ", -1)
  i = 0
  while i < fields.length
    f = "" + fields[i]
    if field_selected?(i + 1, field_indices, open_end)
      begin
        fields[i] = convert_number(f, opts)
      rescue => e
        im = "" + opts.invalid_mode
        if im == "abort" || im == "fail"
          STDERR.puts "numfmt: invalid number: '#{f}'"
          exit 1 if im == "abort"
          exit 2
        elsif im == "warn"
          STDERR.puts "numfmt: invalid number: '#{f}'"
        end
        # ignore: leave field unchanged
      end
    end
    i += 1
  end
  puts fields.join(" ")
  header_remaining
end

exit_code = 0
header_left = opts.header_count

if numbers.empty?
  stdin_lines = STDIN.read.to_s.split("\n")
  sli = 0
  while sli < stdin_lines.length
    header_left = process_line("" + stdin_lines[sli], opts, header_left)
    sli += 1
  end
else
  numbers.each do |n|
    cn = "" + n
    if cn == "-"
      stdin_lines = STDIN.read.to_s.split("\n")
      sli = 0
      while sli < stdin_lines.length
        header_left = process_line("" + stdin_lines[sli], opts, header_left)
        sli += 1
      end
    else
      header_left = process_line(cn, opts, header_left)
    end
  end
end

exit exit_code
