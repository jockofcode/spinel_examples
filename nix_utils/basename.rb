# basename.rb, strip directory and suffix from a path (GNU basename, Spinel port).
#
# Print NAME with any leading directory components removed. With SUFFIX, also
# remove a trailing SUFFIX if present.
#
# Synopsis:
#   basename NAME [SUFFIX]
#   basename [OPTION]... NAME...
#
# Flags:
#   -a, --multiple          treat each argument as a NAME
#   -s SUFFIX, --suffix=SUFFIX  remove a trailing SUFFIX (implies -a)
#   -z, --zero              end output lines with NUL instead of newline
#   --help
#
# Compile: spinel nix_utils/basename.rb -o nix_utils/bin/basename
# Run:
#   ./bin/basename /usr/local/bin/ruby
#   ./bin/basename /lib/libfoo.so .so
#   ./bin/basename -a /a/b /c/d
#
# Core Ruby only (File.basename); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/basename.rb ...`).

USAGE = "Usage: basename NAME [SUFFIX]\n" \
        "  or:  basename [OPTION]... NAME...\n" \
        "Print NAME with leading directory components removed.\n" \
        "  -a  multiple args   -s SUFFIX  strip suffix   -z  NUL-terminated   --help"

class BasenameOptions
  attr_accessor :multiple, :suffix, :zero
  def initialize
    @multiple = false
    @suffix   = nil
    @zero     = false
  end
end

def parse_argv(argv)
  opts  = BasenameOptions.new
  names = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done
      names.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-a" || arg == "--multiple"
      opts.multiple = true
    elsif arg == "-z" || arg == "--zero"
      opts.zero = true
    elsif arg == "-s" || arg == "--suffix"
      index += 1
      opts.suffix = argv[index]
      opts.multiple = true
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.suffix = arg[2, arg.length - 2]
      opts.multiple = true
    elsif arg.length > 9 && arg[0, 9] == "--suffix="
      opts.suffix = arg[9, arg.length - 9]
      opts.multiple = true
    elsif arg.length > 1 && arg[0] == "-"
      # Combined flags like -az.
      i = 1
      while i < arg.length
        c = arg[i]
        if c == "a";    opts.multiple = true
        elsif c == "z"; opts.zero = true
        else
          STDERR.puts "basename: invalid option -- '#{c}'"
          exit 1
        end
        i += 1
      end
    else
      names.push(arg)
    end
    index += 1
  end
  [opts, names]
end

def strip_suffix(name, suffix)
  return name if suffix.nil? || suffix.length == 0
  return name if name == suffix
  name.end_with?(suffix) ? name[0, name.length - suffix.length] : name
end

opts, names = parse_argv(ARGV)

if names.empty?
  STDERR.puts "basename: missing operand"
  STDERR.puts "Try 'basename --help' for more information."
  exit 1
end

eol = opts.zero ? "\0" : "\n"

if !opts.multiple && names.length <= 2
  # Traditional two-argument form: basename NAME [SUFFIX].
  name   = "" + names[0]
  suffix = names.length == 2 ? names[1] : opts.suffix
  result = File.basename(name)
  result = strip_suffix(result, suffix)
  STDOUT.write(result + eol)
else
  names.each do |name|
    cname = "" + name
    result = File.basename(cname)
    result = strip_suffix(result, opts.suffix)
    STDOUT.write(result + eol)
  end
end

exit 0
