# date.rb, print or set the system date and time (GNU date, Spinel port).
#
# Flags:
#   +FORMAT                 format string using strftime sequences
#   -u, --utc, --universal  use UTC
#   -r FILE, --reference=FILE  display mtime of FILE
#   -I[FMT], --iso-8601[=FMT]  ISO 8601 output (date/hours/minutes/seconds)
#   -R, --rfc-email            RFC 5322 format
#   --rfc-3339=FMT             RFC 3339 (date/seconds/ns)
#   -d STRING, --date=STRING   display time for STRING
#   -f FILE, --file=FILE       like --date, once per line
#   --resolution               print timestamp resolution
#   --help, --version
#
# Skip: -s/--set (requires settime syscall), --debug
#
# Note: Time.parse is not available in Spinel; dates are parsed manually.
#
# Compile: spinel nix_utils/date.rb -o nix_utils/bin/date

USAGE = "Usage: date [OPTION]... [+FORMAT]\n" \
        "Display the current time in the given FORMAT.\n" \
        "  -u, --utc           print or set Coordinated Universal Time\n" \
        "  -r FILE             display the last modification time of FILE\n" \
        "  -d STRING           display time described by STRING\n" \
        "  -f FILE             like -d, once per line\n" \
        "  -I[FMT]             ISO 8601 output (date/hours/minutes/seconds)\n" \
        "  -R, --rfc-email     RFC 5322 date and time\n" \
        "  --rfc-3339=FMT      RFC 3339 date and time\n" \
        "  --resolution        output the resolution of timestamps\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit\n" \
        "  -s/--set is unsupported (requires settime syscall)"

VERSION = "date (nix_utils) 1.0"

require_relative "nix_helpers"

use_utc      = false
format_str   = nil
ref_file     = nil
date_str     = nil
date_file    = nil
iso_fmt      = nil   # "date", "hours", "minutes", "seconds"
rfc_email    = false
rfc3339_fmt  = nil
show_resolution = false
options_done = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done
    format_str = arg if arg[0] == "+"
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-u" || arg == "--utc" || arg == "--universal"
    use_utc = true
  elsif arg == "-R" || arg == "--rfc-email"
    rfc_email = true
  elsif arg == "--resolution"
    show_resolution = true
  elsif arg[0] == "+"
    format_str = arg
  elsif arg == "-r"
    index += 1; ref_file = coerce(ARGV[index])
  elsif arg.length > 12 && arg[0, 12] == "--reference="
    ref_file = arg[12, arg.length - 12]
  elsif arg == "-d"
    index += 1; date_str = coerce(ARGV[index])
  elsif arg.length > 7 && arg[0, 7] == "--date="
    date_str = arg[7, arg.length - 7]
  elsif arg == "-f"
    index += 1; date_file = coerce(ARGV[index])
  elsif arg.length > 7 && arg[0, 7] == "--file="
    date_file = arg[7, arg.length - 7]
  elsif arg == "-I"
    iso_fmt = "date"
  elsif arg.length > 2 && arg[0, 2] == "-I"
    iso_fmt = arg[2, arg.length - 2]
  elsif arg == "--iso-8601"
    iso_fmt = "date"
  elsif arg.length > 11 && arg[0, 11] == "--iso-8601="
    iso_fmt = arg[11, arg.length - 11]
  elsif arg.length > 11 && arg[0, 11] == "--rfc-3339="
    rfc3339_fmt = arg[11, arg.length - 11]
  elsif arg == "-s" || arg == "--set"
    die("date: setting the time is not supported in this build")
  else
    die("date: invalid option -- '#{arg}'\nTry 'date --help' for more information.")
  end
  index += 1
end

if show_resolution
  puts "1s"
  exit 0
end

# ── Date string parser ──────────────────────────────────────────────────────

def parse_date_string(s)
  cs = "" + s
  # @N — epoch seconds
  if cs[0] == "@"
    return Time.at(cs[1, cs.length - 1].to_i)
  end
  # YYYY-MM-DD [HH:MM:SS]
  if cs.length >= 10 && cs[4] == "-" && cs[7] == "-"
    year  = cs[0, 4].to_i
    month = cs[5, 2].to_i
    day   = cs[8, 2].to_i
    if cs.length >= 19 && cs[10] == " " || (cs.length >= 19 && cs[10] == "T")
      hour  = cs[11, 2].to_i
      min   = cs[14, 2].to_i
      sec   = cs[17, 2].to_i
    else
      hour = 0; min = 0; sec = 0
    end
    return Time.new(year, month, day, hour, min, sec)
  end
  # N unit ago / N unit
  # e.g. "2 days ago", "1 week ago", "+3 hours"
  sign = 1
  rest = cs
  if rest[0] == "+"
    sign = 1; rest = rest[1, rest.length - 1]
  elsif rest[0] == "-"
    sign = -1; rest = rest[1, rest.length - 1]
  end
  parts = rest.split(" ")
  if parts.length >= 2
    amount = ("" + parts[0]).to_i
    unit   = "" + parts[1]
    if parts.length >= 3 && ("" + parts[2]) == "ago"
      sign = -sign
    end
    now = Time.now
    secs =
      if unit.start_with?("second")
        amount
      elsif unit.start_with?("minute")
        amount * 60
      elsif unit.start_with?("hour")
        amount * 3600
      elsif unit.start_with?("day")
        amount * 86400
      elsif unit.start_with?("week")
        amount * 86400 * 7
      elsif unit.start_with?("month")
        amount * 86400 * 30
      elsif unit.start_with?("year")
        amount * 86400 * 365
      else
        0
      end
    return Time.at(now.to_i + sign * secs)
  end
  STDERR.puts "date: invalid date '#{s}'"; exit 1
end

# ── Output formatting ───────────────────────────────────────────────────────

def format_iso8601(t, fmt, utc)
  tt = utc ? t.utc : t
  f  = "" + fmt
  if f == "date"
    tt.strftime("%Y-%m-%d")
  elsif f == "hours"
    tt.strftime("%Y-%m-%dT%H%z")
  elsif f == "minutes"
    tt.strftime("%Y-%m-%dT%H:%M%z")
  else  # seconds
    tt.strftime("%Y-%m-%dT%H:%M:%S%z")
  end
end

def format_rfc_email(t, utc)
  tt = utc ? t.utc : t
  tt.strftime("%a, %d %b %Y %H:%M:%S %z")
end

def format_rfc3339(t, fmt, utc)
  tt = utc ? t.utc : t
  f  = "" + fmt
  if f == "date"
    tt.strftime("%Y-%m-%d")
  elsif f == "ns"
    tt.strftime("%Y-%m-%d %H:%M:%S.000000000%z")
  else  # seconds
    tt.strftime("%Y-%m-%d %H:%M:%S%z")
  end
end

def format_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
  tt = use_utc ? t.utc : t
  if !iso_fmt.nil?
    return format_iso8601(t, iso_fmt, use_utc)
  end
  if rfc_email
    return format_rfc_email(t, use_utc)
  end
  unless rfc3339_fmt.nil?
    return format_rfc3339(t, rfc3339_fmt, use_utc)
  end
  if format_str.nil?
    return tt.strftime("%a %b %_d %H:%M:%S %Z %Y")
  end
  fs = "" + format_str
  fs = fs[1, fs.length - 1] if fs[0] == "+"
  tt.strftime(fs)
end

def print_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
  puts format_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
end

if !date_file.nil?
  content = read_source("" + date_file)
  content.split("\n").each do |line|
    cl = "" + line
    next if cl == ""
    t = parse_date_string(cl)
    print_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
  end
elsif !date_str.nil?
  t = parse_date_string("" + date_str)
  print_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
elsif !ref_file.nil?
  cf = "" + ref_file
  die("date: #{cf}: No such file or directory") unless File.exist?(cf)
  t = File.mtime(cf)
  print_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
else
  t = Time.now
  print_time(t, format_str, use_utc, iso_fmt, rfc_email, rfc3339_fmt)
end
