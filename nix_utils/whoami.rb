# whoami.rb, print effective user name (GNU whoami, Spinel port).
#
# Prints the name of the user associated with the current effective user ID.
# Equivalent to `id -un`.
#
# Flags:
#   --help     usage
#
# Compile: spinel nix_utils/whoami.rb -o nix_utils/bin/whoami
# Run:
#   ./bin/whoami

USAGE = "Usage: whoami [OPTION]...\n" \
        "Print the name of the current user.\n" \
        "  --help"

ARGV.each do |arg|
  if arg == "--help"
    puts USAGE
    exit 0
  elsif arg[0] == "-"
    STDERR.puts "whoami: extra operand '#{arg}'"
    exit 1
  end
end

# Try ENV["USER"] first, then fall back to /usr/bin/id -un
user = ENV["USER"] || ENV["LOGNAME"] || ENV["USERNAME"]
if user.nil?
  result = "" + `/usr/bin/id -un`.chomp
  user = result if result != ""
end

if user.nil?
  uid_s = "" + `/usr/bin/id -u`.chomp
  STDERR.puts "whoami: cannot find name for user ID " + uid_s
  exit 1
end

puts user
