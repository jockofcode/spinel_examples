# dirname.rb, strip last component from a path (GNU dirname, Spinel port).
#
# Print each NAME with its last non-slash component and trailing slashes
# removed.  If NAME contains no /, output . (the current directory).
#
# Synopsis:
#   dirname [OPTION] NAME...
#
# Flags:
#   -z, --zero  end output lines with NUL instead of newline
#   --help
#
# Compile: spinel nix_utils/dirname.rb -o nix_utils/bin/dirname
# Run:
#   ./bin/dirname /usr/local/bin/ruby   # -> /usr/local/bin
#   ./bin/dirname foo                   # -> .
#   ./bin/dirname /                     # -> /
#
# Core Ruby only (File.dirname); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/dirname.rb ...`).

USAGE = "Usage: dirname [OPTION] NAME...\n" \
        "Output each NAME with its last non-slash component and trailing slashes removed.\n" \
        "If NAME contains no /, output . (current directory).\n" \
        "  -z  NUL-terminated output   --help"

zero  = false
names = []
options_done = false

ARGV.each do |arg|
  if options_done
    names.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE
    exit 0
  elsif arg == "-z" || arg == "--zero"
    zero = true
  elsif arg.length > 1 && arg[0] == "-"
    i = 1
    while i < arg.length
      c = arg[i]
      if c == "z"; zero = true
      else
        STDERR.puts "dirname: invalid option -- '#{c}'"
        exit 1
      end
      i += 1
    end
  else
    names.push(arg)
  end
end

if names.empty?
  STDERR.puts "dirname: missing operand"
  STDERR.puts "Try 'dirname --help' for more information."
  exit 1
end

eol = zero ? "\0" : "\n"
names.each { |name| STDOUT.write(File.dirname(name) + eol) }

exit 0
