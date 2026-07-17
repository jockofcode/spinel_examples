# env.rb, print the environment or set variables (GNU env, Spinel port).
#
# With no COMMAND, prints all environment variables (one per line). The exec
# path is not available in a compiled binary, so running a command with a
# modified environment delegates to the shell via system().
#
# Flags:
#   -i, --ignore-environment  start with an empty environment
#   -u NAME, --unset=NAME     remove variable from environment
#   -0, --null                end each output line with NUL instead of newline
#   -C DIR, --chdir=DIR       change working directory to DIR before running command
#   --help                    usage
#
# Compile: spinel nix_utils/env.rb -o nix_utils/bin/env
# Run:
#   ./bin/env
#   ./bin/env -i PATH=/usr/bin
#   ./bin/env -u HOME

USAGE = "Usage: env [OPTION]... [-] [NAME=VALUE]... [COMMAND [ARG]...]\n" \
        "Print or set the environment.\n" \
        "With no COMMAND, print the current (possibly modified) environment.\n" \
        "  -i  start with empty environment\n" \
        "  -u NAME  remove NAME from environment\n" \
        "  -0  end output lines with NUL\n" \
        "  -C DIR  change working directory to DIR\n" \
        "  --help"

class EnvOptions
  attr_accessor :ignore_env, :unset_vars, :null_delim, :chdir
  def initialize
    @ignore_env = false
    @unset_vars = []
    @unset_vars.push("")
    @unset_vars.pop
    @null_delim = false
    @chdir      = nil
  end
end

def parse_argv(argv)
  opts = EnvOptions.new
  index = 0
  while index < argv.length
    arg = argv[index]
    if arg == "-i" || arg == "--ignore-environment" || arg == "-"
      opts.ignore_env = true
    elsif arg == "-0" || arg == "--null"
      opts.null_delim = true
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "-u" || arg == "--unset"
      index += 1
      opts.unset_vars.push("" + argv[index])
    elsif arg.length > 8 && arg[0, 8] == "--unset="
      opts.unset_vars.push("" + arg[8, arg.length - 8])
    elsif arg.length > 2 && arg[0, 2] == "-u"
      opts.unset_vars.push("" + arg[2, arg.length - 2])
    elsif arg == "-C" || arg == "--chdir"
      index += 1
      opts.chdir = argv[index]
    elsif arg.length > 8 && arg[0, 8] == "--chdir="
      opts.chdir = arg[8, arg.length - 8]
    elsif arg.length > 2 && arg[0, 2] == "-C"
      opts.chdir = arg[2, arg.length - 2]
    elsif arg.length >= 2 && arg[0] == "-"
      STDERR.puts "env: invalid option -- '#{arg}'"
      exit 1
    else
      break
    end
    index += 1
  end
  [opts, argv[index, argv.length - index]]
end

opts, rest = parse_argv(ARGV)

# Build the effective environment hash
# ENV.each is not available in Spinel; parse `/usr/bin/env` output instead.
env = {}
unless opts.ignore_env
  `/usr/bin/env`.lines.each do |line|
    l = "" + line
    l = l.end_with?("\n") ? "" + l[0, l.length - 1] : l
    next if l == ""
    eq = l.index("=")
    next if eq.nil? || eq == 0
    k = "" + l[0, eq]
    v = "" + l[eq + 1, l.length - eq - 1]
    env[k] = v
  end
end
opts.unset_vars.each { |k| env.delete(k) }

# Consume NAME=VALUE pairs; remaining args are the optional command
cmd_args = []
cmd_args.push(""); cmd_args.pop
rest.each do |arg|
  carg = "" + arg
  if cmd_args.empty? && carg.include?("=") && Regexp.new('^[A-Za-z_][A-Za-z0-9_]*=').match(carg)
    parts = carg.split("=", 2)
    env[parts[0]] = parts[1]
  else
    cmd_args.push(carg)
  end
end

if cmd_args.length > 0
  # Run command with modified environment by setting ENV and using system
  # (exec is not available in Spinel compiled binaries).
  # Build an env command line so unsets and clean-env (-i) are respected.
  env_prefix = opts.ignore_env ? "/usr/bin/env -i" : "/usr/bin/env"
  opts.unset_vars.each { |k| env_prefix = env_prefix + " -u " + k }
  env.each { |k, v| env_prefix = env_prefix + " " + k + "='" + v.gsub("'", "'\\''") + "'" }
  quoted = []
  cmd_args.each { |a| quoted.push("'" + a.gsub("'", "'\\''") + "'") }
  if opts.chdir
    Dir.chdir("" + opts.chdir)
  end
  result = system(env_prefix + " " + quoted.join(" "))
  exit result ? 0 : 1
else
  term = opts.null_delim ? "\0" : "\n"
  env.keys.sort.each do |k|
    STDOUT.write("#{k}=#{env[k]}#{term}")
  end
end
