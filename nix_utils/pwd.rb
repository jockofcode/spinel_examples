# pwd.rb, print the name of the current working directory (GNU pwd, Spinel port).
#
# Flags:
#   -L  print the value of $PWD (follows logical symlinks, default)
#   -P  print the physical path with all symlinks resolved
#   --help
#
# Compile: spinel nix_utils/pwd.rb -o nix_utils/bin/pwd
# Run:
#   ./bin/pwd
#   ./bin/pwd -P
#
# Core Ruby only (Dir, ENV); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/pwd.rb ...`).

USAGE = "Usage: pwd [-LP]\nPrint the full path of the current working directory.\n  -L  logical path   -P  physical path   --help"

logical = true

ARGV.each do |arg|
  if arg == "--help"
    puts USAGE
    exit 0
  elsif arg == "-L"
    logical = true
  elsif arg == "-P"
    logical = false
  elsif arg == "-LP"
    logical = false
  elsif arg == "-PL"
    logical = true
  elsif arg.length > 1 && arg[0] == "-"
    i = 1
    while i < arg.length
      c = arg[i]
      if c == "L";    logical = true
      elsif c == "P"; logical = false
      else
        STDERR.puts "pwd: invalid option -- '#{c}'"
        exit 1
      end
      i += 1
    end
  end
end

if logical
  env_pwd = ENV["PWD"]
  if !env_pwd.nil? && env_pwd != ""
    puts env_pwd
  else
    puts Dir.pwd
  end
else
  puts Dir.pwd
end

exit 0
