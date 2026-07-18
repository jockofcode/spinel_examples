# logname.rb, print the current login name (GNU logname, Spinel port).
#
# Compile: spinel nix_utils/logname.rb -o nix_utils/bin/logname

USAGE = "Usage: logname [OPTION]\n" \
        "Print the name of the current user.\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit"

VERSION = "logname (nix_utils) 1.0"

require_relative "nix_helpers"

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  else
    die("logname: extra operand '#{arg}'\nTry 'logname --help' for more information.")
  end
  index += 1
end

name = ENV["LOGNAME"] || ENV["USER"]
if name.nil? || ("" + name) == ""
  die("logname: no login name")
end
puts name
