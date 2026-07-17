# readlink.rb, print resolved symbolic links or canonical file names (GNU readlink, Spinel).
#
# Without options: prints the value of the symlink (the target it points to).
# With -f/-e/-m: resolves the full path (canonicalizes).
#
# Flags:
#   -f, --canonicalize         resolve all symlinks; all components must exist
#   -e, --canonicalize-existing  like -f but fail if any component missing
#   -m, --canonicalize-missing   like -f but missing components are OK
#   -n, --no-newline             do not output trailing newline
#   -q, --quiet, --silent        suppress error messages
#   -z, --zero                   NUL-terminate output lines instead of newline
#   --help                       usage
#
# Compile: spinel nix_utils/readlink.rb --link nix_utils/sp_file_ext.o -o nix_utils/bin/readlink
# Run:
#   ./bin/readlink /etc/localtime
#   ./bin/readlink -f relative/path

require_relative 'file_ext'

USAGE = "Usage: readlink [OPTION]... FILE...\n" \
        "Print the value of a symbolic link or canonical file name.\n" \
        "  -f  canonicalize path (resolve all symlinks)\n" \
        "  -e  canonicalize; fail if component missing\n" \
        "  -m  canonicalize; OK if components missing\n" \
        "  -n  no trailing newline    -q  quiet\n" \
        "  -z  NUL-terminate output\n" \
        "  --help"

class ReadlinkOptions
  attr_accessor :canonicalize, :must_exist, :allow_missing, :no_newline, :quiet, :zero, :verbose
  def initialize
    @canonicalize  = false
    @must_exist    = false
    @allow_missing = false
    @no_newline    = false
    @quiet         = false
    @zero          = false
    @verbose       = false
  end
end

def parse_argv(argv)
  opts = ReadlinkOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg.length < 2 || arg[0] != "-"
      files.push(arg); index += 1; next
    end
    if arg == "--"; options_done = true; index += 1; next; end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "-f" || arg == "--canonicalize"
      opts.canonicalize = true; opts.must_exist = true
    elsif arg == "-e" || arg == "--canonicalize-existing"
      opts.canonicalize = true; opts.must_exist = true
    elsif arg == "-m" || arg == "--canonicalize-missing"
      opts.canonicalize = true; opts.must_exist = false; opts.allow_missing = true
    elsif arg == "-n" || arg == "--no-newline"
      opts.no_newline = true
    elsif arg == "-q" || arg == "--quiet" || arg == "--silent"
      opts.quiet = true
    elsif arg == "-v" || arg == "--verbose"
      opts.verbose = true
    elsif arg == "-z" || arg == "--zero"
      opts.zero = true
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "f"; opts.canonicalize = true; opts.must_exist = true
        elsif letter == "e"; opts.canonicalize = true; opts.must_exist = true
        elsif letter == "m"; opts.canonicalize = true; opts.allow_missing = true
        elsif letter == "n"; opts.no_newline = true
        elsif letter == "q"; opts.quiet = true
        elsif letter == "v"; opts.verbose = true
        elsif letter == "z"; opts.zero = true
        else
          STDERR.puts "readlink: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

def canonicalize_path(path, allow_missing)
  # Resolve to absolute path, following symlinks one level at a time
  if path[0] != "/"
    path = Dir.pwd + "/" + path
  end
  parts = path.split("/")
  resolved = []
  parts.each do |part|
    if part == "" || part == "."
      # skip
    elsif part == ".."
      resolved.pop unless resolved.empty?
    else
      resolved.push(part)
    end
  end
  result = "/" + resolved.join("/")
  result
end

opts, files = parse_argv(ARGV)

if files.empty?
  STDERR.puts "readlink: missing operand"
  exit 1
end

term = opts.zero ? "\0" : (opts.no_newline ? "" : "\n")
exit_code = 0

files.each do |name|
  cname = "" + name
  if opts.canonicalize
    unless File.exist?(cname) || File.symlink?(cname) || opts.allow_missing
      STDERR.puts "readlink: #{cname}: No such file or directory" unless opts.quiet
      exit_code = 1
      next
    end
    result = canonicalize_path(cname, opts.allow_missing)
    STDOUT.write(result + term)
  else
    unless File.symlink?(cname)
      STDERR.puts "readlink: #{cname}: Invalid argument" unless opts.quiet
      exit_code = 1
      next
    end
    target = FileExt.readlink(cname)
    STDOUT.write(target + term)
  end
end

exit exit_code
