# printenv.rb, print all or part of the environment (GNU printenv, Spinel port).
#
# Flags:
#   VARIABLE...  print only those variables; exit 1 for any not set
#   (no args)    print all KEY=VALUE pairs sorted by key
#   --help, --version
#
# Note: -0/--null (NUL terminator) is unsupported — NUL bytes are impossible
# in Spinel C strings.
#
# Compile: spinel nix_utils/printenv.rb -o nix_utils/bin/printenv

USAGE = "Usage: printenv [OPTION]... [VARIABLE]...\n" \
        "Print the values of the specified environment VARIABLE(s).\n" \
        "If no VARIABLE is specified, print name and value pairs for them all.\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit\n" \
        "  -0/--null  unsupported (NUL terminator not possible in this build)"

VERSION = "printenv (nix_utils) 1.0"

require_relative "nix_helpers"

vars = []
index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-0" || arg == "--null"
    die("printenv: -0/--null is unsupported in this build (NUL bytes not possible in Spinel C strings)")
  elsif arg == "--"
    index += 1
    while index < ARGV.length
      vars.push(coerce(ARGV[index]))
      index += 1
    end
    break
  else
    vars.push(arg)
  end
  index += 1
end

exit_code = 0

if vars.empty?
  keys = []
  ENV.each { |k, _v| keys.push("" + k) }
  keys.sort.each do |k|
    ck = "" + k
    val = ENV[ck]
    puts "#{ck}=#{val}" unless val.nil?
  end
else
  vars.each do |v|
    cv = "" + v
    val = ENV[cv]
    if val.nil?
      exit_code = 1
    else
      puts val
    end
  end
end

exit exit_code
