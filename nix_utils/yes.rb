# yes.rb, repeatedly output a string (GNU yes, Spinel port).
#
# Repeatedly output the given STRING(s) joined by a space (default: "y"),
# one line per iteration, until killed.  Useful for confirming interactive
# prompts in scripts: yes | some-command.
#
# Compile: spinel nix_utils/yes.rb -o nix_utils/bin/yes
# Run:
#   ./bin/yes | head -3
#   ./bin/yes no | head -2
#
# Core Ruby only (STDOUT); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/yes.rb ...`).

if ARGV[0] == "--help"
  puts "Usage: yes [STRING]..."
  puts "Repeatedly output a line with STRING (default: y)."
  exit 0
end

words = []
ARGV.each { |a| words.push(a) }
line = words.empty? ? "y" : words.join(" ")

while true
  STDOUT.puts line
end
