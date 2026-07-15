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

# Try ENV["USER"] first, then Etc-equivalent via id command
user = ENV["USER"] || ENV["LOGNAME"] || ENV["USERNAME"]
if user.nil?
  # Fall back: parse /etc/passwd for current UID
  uid = Process.uid.to_s
  if File.exist?("/etc/passwd")
    File.read("/etc/passwd").lines.each do |line|
      parts = line.chomp.split(":")
      if parts.length >= 3 && parts[2] == uid
        user = parts[0]
        break
      end
    end
  end
end

if user.nil?
  STDERR.puts "whoami: cannot find name for user ID #{Process.uid}"
  exit 1
end

puts user
