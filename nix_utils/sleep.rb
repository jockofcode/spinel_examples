# sleep.rb, delay for a specified amount of time (GNU sleep, Spinel port).
#
# Pause for the sum of all given durations. Supports fractional seconds and
# unit suffixes.
#
# Synopsis:
#   sleep NUMBER[SUFFIX]...
#   SUFFIX: s (seconds, default), m (minutes), h (hours), d (days)
#
# Compile: spinel nix_utils/sleep.rb -o nix_utils/bin/sleep
# Run:
#   ./bin/sleep 1
#   ./bin/sleep 0.5
#   ./bin/sleep 1m 30s
#
# Core Ruby only (Kernel#sleep); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/sleep.rb ...`).

USAGE = "Usage: sleep NUMBER[SUFFIX]...\n" \
        "Pause for the total of the given durations.\n" \
        "SUFFIX: s seconds (default), m minutes, h hours, d days\n" \
        "  --help"

if ARGV.length == 1 && ARGV[0] == "--help"
  puts USAGE
  exit 0
end

if ARGV.empty?
  STDERR.puts "sleep: missing operand"
  STDERR.puts "Try 'sleep --help' for more information."
  exit 1
end

def valid_number?(text)
  return false if text == "" || text == "."
  dot_count = 0
  i = 0
  while i < text.length
    c = text[i]
    if c == "."
      dot_count += 1
      return false if dot_count > 1
    elsif !"0123456789".include?(c)
      return false
    end
    i += 1
  end
  true
end

def parse_duration(arg)
  text = arg
  multiplier = 1.0
  if text.length > 0
    last = text[text.length - 1]
    if last == "s"
      multiplier = 1.0
      text = text[0, text.length - 1]
    elsif last == "m"
      multiplier = 60.0
      text = text[0, text.length - 1]
    elsif last == "h"
      multiplier = 3600.0
      text = text[0, text.length - 1]
    elsif last == "d"
      multiplier = 86400.0
      text = text[0, text.length - 1]
    end
  end
  unless valid_number?(text)
    STDERR.puts "sleep: invalid time interval '#{arg}'"
    exit 1
  end
  text.to_f * multiplier
end

total = 0.0
ARGV.each { |arg| total += parse_duration(arg) }

sleep(total)

exit 0
