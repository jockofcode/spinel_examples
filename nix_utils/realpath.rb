# realpath.rb, print the resolved absolute file names (GNU realpath, Spinel port).
#
# Flags:
#   -e, --canonicalize-existing  error if any path component doesn't exist
#   -m, --canonicalize-missing   no existence check
#   (default: -E, all but last component must exist — approximated)
#   -q, --quiet                  suppress error messages
#   --relative-to=DIR            print path relative to DIR
#   --relative-base=DIR          absolute unless path is under DIR
#   -s, --strip, --no-symlinks   don't expand symlinks
#   -z, --zero   unsupported (NUL terminator)
#   --help, --version
#
# Note: -L/--logical and -P/--physical symlink-ordering semantics are
# approximated; File.expand_path covers the vast majority of real usage.
#
# Compile: spinel nix_utils/realpath.rb -o nix_utils/bin/realpath

USAGE = "Usage: realpath [OPTION]... FILE...\n" \
        "Print the resolved absolute file name.\n" \
        "  -e  error if path doesn't exist   -m  allow missing paths\n" \
        "  -q  quiet   -s  no symlink expansion\n" \
        "  --relative-to=DIR   --relative-base=DIR\n" \
        "  --help    --version\n" \
        "  -z/--zero unsupported (NUL bytes not possible in this build)"

VERSION = "realpath (nix_utils) 1.0"

require_relative "nix_helpers"

must_exist    = false  # -e
allow_missing = false  # -m
quiet         = false
no_symlinks   = false
relative_to   = nil
relative_base = nil
files         = []
options_done  = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || (arg[0] != "-")
    files.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-e" || arg == "--canonicalize-existing"
    must_exist = true
  elsif arg == "-E" || arg == "--canonicalize"
    # default; no-op
  elsif arg == "-m" || arg == "--canonicalize-missing"
    allow_missing = true
  elsif arg == "-q" || arg == "--quiet"
    quiet = true
  elsif arg == "-s" || arg == "--strip" || arg == "--no-symlinks"
    no_symlinks = true
  elsif arg == "-L" || arg == "--logical"
    # approximated by File.expand_path
  elsif arg == "-P" || arg == "--physical"
    # default
  elsif arg.length > 13 && arg[0, 13] == "--relative-to="
    relative_to = arg[13, arg.length - 13]
  elsif arg.length > 15 && arg[0, 15] == "--relative-base="
    relative_base = arg[15, arg.length - 15]
  elsif arg == "-z" || arg == "--zero"
    die("realpath: -z/--zero is unsupported in this build (NUL bytes not possible in Spinel C strings)")
  else
    die("realpath: unrecognized option '#{arg}'\nTry 'realpath --help' for more information.")
  end
  index += 1
end

if files.empty?
  die("realpath: missing operand\nTry 'realpath --help' for more information.")
end

# Compute a relative path from base_dir to target_path.
def relative_path(base_dir, target_path)
  base_parts   = ("" + base_dir).split("/").reject { |p| ("" + p) == "" }
  target_parts = ("" + target_path).split("/").reject { |p| ("" + p) == "" }
  common = 0
  while common < base_parts.length && common < target_parts.length &&
        ("" + base_parts[common]) == ("" + target_parts[common])
    common += 1
  end
  up_count   = base_parts.length - common
  rest_parts = target_parts[common, target_parts.length - common]
  rel_parts  = []
  up_count.times { rel_parts.push("..") }
  rest_parts.each { |p| rel_parts.push("" + p) }
  rel_parts.empty? ? "." : rel_parts.join("/")
end

exit_code = 0

files.each do |f|
  cf = "" + f
  if no_symlinks
    resolved = File.expand_path(cf)
  elsif allow_missing
    # Can't resolve symlinks if path may not exist; just normalize
    resolved = File.expand_path(cf)
  else
    begin
      resolved = File.realpath(cf)
    rescue
      resolved = File.expand_path(cf)
    end
  end

  if must_exist && !File.exist?(resolved)
    unless quiet
      STDERR.puts "realpath: #{cf}: No such file or directory"
    end
    exit_code = 1
    next
  end

  output = resolved

  unless relative_base.nil?
    rb = File.expand_path("" + relative_base)
    if resolved.length >= rb.length && resolved[0, rb.length] == rb
      output = relative_path(rb, resolved)
    else
      output = resolved
    end
  end

  unless relative_to.nil?
    rt = File.expand_path("" + relative_to)
    output = relative_path(rt, resolved)
  end

  puts output
end

exit exit_code
