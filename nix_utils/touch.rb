# touch.rb, change file timestamps / create empty files (GNU touch, Spinel port).
#
# Updates the access and modification times of each FILE to the current time.
# Creates the file if it does not exist, unless -c is given.
#
# Flags:
#   -a           change only the access time
#   -m           change only the modification time
#   -c, --no-create  do not create any files
#   -t STAMP     use [[CC]YY]MMDDhhmm[.ss] instead of current time
#   -d STRING    parse STRING as a date/time (basic ISO 8601 and common forms)
#   -r FILE      use this file's times instead of current time
#   --help       usage
#
# Compile: spinel nix_utils/touch.rb -o nix_utils/bin/touch
# Run:
#   ./bin/touch newfile.txt
#   ./bin/touch -c maybe_missing.txt
#
# Core Ruby only (File, Time); no require gate needed.

USAGE = "Usage: touch [OPTION]... FILE...\n" \
        "Update the access and modification times of each FILE to the current time.\n" \
        "Create FILE if it does not exist.\n" \
        "  -a           change only access time\n" \
        "  -m           change only modification time\n" \
        "  -c           do not create files\n" \
        "  -r FILE      use FILE's times instead of current time\n" \
        "  -t STAMP     [[CC]YY]MMDDhhmm[.ss] timestamp\n" \
        "  -d STRING    date/time string (basic ISO 8601)\n" \
        "  --help"

class TouchOptions
  attr_accessor :access_only, :mod_only, :no_create, :ref_file, :time
  def initialize
    @access_only = false
    @mod_only    = false
    @no_create   = false
    @ref_file    = nil
    @time        = nil   # nil = current time
  end
end

# Parse a basic ISO 8601 date-time string into a Time object.
# Supports: YYYY-MM-DD, YYYY-MM-DDTHH:MM:SS, YYYY-MM-DD HH:MM:SS
def parse_date_string(s)
  now = Time.now
  s = s.strip
  # Try YYYY-MM-DDTHH:MM:SS or YYYY-MM-DD HH:MM:SS
  m = Regexp.new('^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?').match(s)
  if m
    yr  = m[1].to_i
    mon = m[2].to_i
    day = m[3].to_i
    hr  = m[4].to_i
    min = m[5].to_i
    sec = m[6] ? m[6].to_i : 0
    return Time.new(yr, mon, day, hr, min, sec)
  end
  # Try YYYY-MM-DD
  m = Regexp.new('^(\d{4})-(\d{2})-(\d{2})$').match(s)
  if m
    return Time.new(m[1].to_i, m[2].to_i, m[3].to_i, 0, 0, 0)
  end
  STDERR.puts "touch: invalid date format '#{s}'"
  exit 1
end

# Parse -t STAMP: [[CC]YY]MMDDhhmm[.ss]
def parse_stamp(s)
  # Strip optional seconds
  secs = 0
  if s.include?(".")
    parts = s.split(".")
    s = parts[0]
    secs = parts[1].to_i
  end
  now = Time.now
  case s.length
  when 12  # CCYYMMDDhhmm
    yr  = s[0, 4].to_i
    mon = s[4, 2].to_i
    day = s[6, 2].to_i
    hr  = s[8, 2].to_i
    min = s[10, 2].to_i
  when 10  # YYMMDDhhmm
    yy = s[0, 2].to_i
    yr = yy >= 69 ? 1900 + yy : 2000 + yy
    mon = s[2, 2].to_i
    day = s[4, 2].to_i
    hr  = s[6, 2].to_i
    min = s[8, 2].to_i
  when 8   # MMDDhhmm
    yr  = now.year
    mon = s[0, 2].to_i
    day = s[2, 2].to_i
    hr  = s[4, 2].to_i
    min = s[6, 2].to_i
  else
    STDERR.puts "touch: invalid date format '#{s}'"
    exit 1
  end
  Time.new(yr, mon, day, hr, min, secs)
end

def parse_argv(argv)
  opts = TouchOptions.new
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
    elsif arg == "--no-create"
      opts.no_create = true
    elsif arg == "-r" || arg == "--reference"
      index += 1
      opts.ref_file = argv[index]
    elsif arg == "-t"
      index += 1
      opts.time = parse_stamp(argv[index])
    elsif arg == "-d" || arg == "--date"
      index += 1
      opts.time = parse_date_string(argv[index])
    elsif arg.length > 2 && arg[0, 2] == "-d"
      opts.time = parse_date_string(arg[2, arg.length - 2])
    elsif arg.length > 2 && arg[0, 2] == "-t"
      opts.time = parse_stamp(arg[2, arg.length - 2])
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "a"
          opts.access_only = true
        elsif letter == "m"
          opts.mod_only = true
        elsif letter == "c"
          opts.no_create = true
        elsif letter == "f"
          # GNU: -f is obsolete, silently ignored
        else
          STDERR.puts "touch: invalid option -- '#{letter}'"
          STDERR.puts "Try 'touch --help' for more information."
          exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

opts, files = parse_argv(ARGV)

if files.empty?
  STDERR.puts "touch: missing file operand"
  STDERR.puts "Try 'touch --help' for more information."
  exit 1
end

# Resolve reference file time
if opts.ref_file
  if !File.exist?(opts.ref_file)
    STDERR.puts "touch: failed to get attributes of '#{opts.ref_file}': No such file or directory"
    exit 1
  end
  ref_stat = File.stat(opts.ref_file)
  opts.time = ref_stat.mtime
end

target_time = opts.time || Time.now

exit_code = 0
files.each do |name|
  exists = File.exist?(name)
  if !exists
    if opts.no_create
      next
    end
    # Create the file
    f = File.open(name, "w")
    f.close
  end
  # Update timestamps
  if opts.access_only
    File.utime(target_time, File.stat(name).mtime, name)
  elsif opts.mod_only
    File.utime(File.stat(name).atime, target_time, name)
  else
    File.utime(target_time, target_time, name)
  end
end

exit exit_code
