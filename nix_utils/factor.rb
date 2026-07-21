# factor.rb, factor integers into prime factors (GNU factor, Spinel port).
#
# Flags:
#   -h, --exponents  use exponent notation (e.g. 2^2 3 instead of 2 2 3)
#   --help, --version
#   Numbers from ARGV or stdin (one per line)
#
# Compile: spinel nix_utils/factor.rb -o nix_utils/bin/factor

USAGE = "Usage: factor [OPTION]... [NUMBER]...\n" \
        "Print the prime factors of each specified integer NUMBER.\n" \
        "If no arguments are given, read from standard input.\n" \
        "  -h, --exponents  print repeated factors as p^e\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit"

VERSION = "factor (nix_utils) 1.0"

require_relative "nix_helpers"

use_exponents = false
numbers       = []
options_done  = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || (arg[0] != "-" && arg != "--")
    numbers.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-h" || arg == "--exponents"
    use_exponents = true
  else
    die("factor: invalid option -- '#{arg}'\nTry 'factor --help' for more information.")
  end
  index += 1
end

if numbers.empty?
  stdin_lines = STDIN.read.to_s.split("\n")
  li = 0
  while li < stdin_lines.length
    line = "" + stdin_lines[li]
    numbers.push(line) unless line == ""
    li += 1
  end
end

def factorize(n)
  factors = []
  if n < 0
    factors.push(-1)
    n = -n
  end
  if n <= 1
    return factors
  end
  d = 2
  while d * d <= n
    while n % d == 0
      factors.push(d)
      n = n / d
    end
    d += 1
  end
  factors.push(n) if n > 1
  factors
end

exit_code = 0
numbers.each do |num_str|
  s = "" + num_str
  n = s.to_i
  if n.to_s != s && ("-" + n.abs.to_s) != s
    STDERR.puts "factor: '#{s}' is not a valid positive integer"
    exit_code = 1
    next
  end

  factors = factorize(n)

  if use_exponents
    grouped = []
    i = 0
    while i < factors.length
      f = factors[i]
      count = 1
      while i + count < factors.length && factors[i + count] == f
        count += 1
      end
      if count > 1
        grouped.push("#{f}^#{count}")
      else
        grouped.push(f.to_s)
      end
      i += count
    end
    puts "#{n}: #{grouped.join(" ")}"
  else
    puts "#{n}: #{factors.join(" ")}"
  end
end

exit exit_code
