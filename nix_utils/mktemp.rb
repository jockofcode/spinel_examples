# mktemp.rb, create a temporary file or directory (GNU mktemp, Spinel port).
#
# Flags:
#   -d, --directory      create a directory instead of a file
#   -u, --dry-run        don't create; just print the name
#   -q, --quiet          suppress error messages on failure
#   --suffix=SUFF        append SUFF to template
#   -p DIR, --tmpdir[=DIR]  interpret template relative to DIR
#   -t               (deprecated) same as -p $TMPDIR
#   TEMPLATE             must contain at least 3 consecutive Xs in last component
#   --help, --version
#
# Compile: spinel nix_utils/mktemp.rb -o nix_utils/bin/mktemp

USAGE = "Usage: mktemp [OPTION]... [TEMPLATE]\n" \
        "Create a temporary file or directory, safely, and print its name.\n" \
        "  -d  directory   -u  dry-run   -q  quiet\n" \
        "  --suffix=SUFF   -p DIR / --tmpdir[=DIR]   -t (deprecated)\n" \
        "  --help    --version\n" \
        "TEMPLATE must contain at least 3 consecutive X characters."

VERSION = "mktemp (nix_utils) 1.0"

require_relative "nix_helpers"

make_dir   = false
dry_run    = false
quiet      = false
suffix     = ""
tmpdir     = nil
template   = nil
options_done = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done
    template = arg
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-d" || arg == "--directory"
    make_dir = true
  elsif arg == "-u" || arg == "--dry-run"
    dry_run = true
  elsif arg == "-q" || arg == "--quiet"
    quiet = true
  elsif arg == "-t"
    td = ENV["TMPDIR"]
    tmpdir = (td.nil? || ("" + td) == "") ? "/tmp" : ("" + td)
  elsif arg == "-p"
    index += 1
    tmpdir = coerce(ARGV[index])
  elsif arg.length > 8 && arg[0, 8] == "--tmpdir"
    if arg.length > 9 && arg[8] == "="
      tmpdir = arg[9, arg.length - 9]
    else
      td = ENV["TMPDIR"]
      tmpdir = (td.nil? || ("" + td) == "") ? "/tmp" : ("" + td)
    end
  elsif arg.length > 9 && arg[0, 9] == "--suffix="
    suffix = arg[9, arg.length - 9]
  elsif arg[0] != "-"
    template = arg
  else
    die("mktemp: unrecognized option '#{arg}'\nTry 'mktemp --help' for more information.")
  end
  index += 1
end

template = "tmp.XXXXXXXXXX" if template.nil?
template = ("" + template) + ("" + suffix)

# Find the last run of Xs in the last path component.
last_slash = template.rindex("/")
if last_slash.nil?
  basename = template
  dirname  = nil
else
  basename = template[last_slash + 1, template.length - last_slash - 1]
  dirname  = template[0, last_slash]
end

# Count trailing Xs
x_end = basename.length
x_start = x_end
while x_start > 0 && basename[x_start - 1] == "X"
  x_start -= 1
end
x_count = x_end - x_start

if x_count < 3
  STDERR.puts "mktemp: too few X's in template '#{template}'" unless quiet
  exit 1
end

prefix = basename[0, x_start]
suffix_part = ""  # no suffix after Xs in this implementation

# Determine base directory
base =
  if !dirname.nil?
    dirname
  elsif !tmpdir.nil?
    "" + tmpdir
  else
    td = ENV["TMPDIR"]
    (td.nil? || ("" + td) == "") ? "/tmp" : ("" + td)
  end

CHARS = "abcdefghijklmnopqrstuvwxyz0123456789"

attempts = 0
path = nil
loop do
  rand_part = ""
  x_count.times do
    rand_part += CHARS[rand(CHARS.length)]
  end
  candidate = base + "/" + prefix + rand_part + suffix_part
  unless File.exist?(candidate)
    path = candidate
    break
  end
  attempts += 1
  if attempts > 10000
    STDERR.puts "mktemp: failed to create unique temporary path" unless quiet
    exit 1
  end
end

if dry_run
  puts path
  exit 0
end

begin
  if make_dir
    Dir.mkdir(path)
  else
    # Create the file exclusively; fall back to a plain open if flags unsupported.
    begin
      File.open(path, File::CREAT | File::EXCL | File::WRONLY) { }
    rescue
      File.open(path, "w") { }
    end
  end
  puts path
rescue
  STDERR.puts "mktemp: failed to create #{make_dir ? 'directory' : 'file'} via template '#{template}'" unless quiet
  exit 1
end
