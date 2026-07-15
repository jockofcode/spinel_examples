# hostname.rb, show or set the system hostname (GNU hostname, Spinel port).
#
# Prints the current hostname. Setting the hostname requires root and uses
# the system hostname command.
#
# Flags:
#   -s, --short      print short hostname (up to first '.')
#   -f, --fqdn       print fully-qualified domain name
#   -i, --ip-address print IP addresses of the host
#   -d, --domain     print DNS domain name
#   --help           usage
#
# Compile: spinel nix_utils/hostname.rb -o nix_utils/bin/hostname
# Run:
#   ./bin/hostname
#   ./bin/hostname -s

USAGE = "Usage: hostname [OPTION]... [NAME]\n" \
        "Show or set the system hostname.\n" \
        "  -s  short hostname    -f  fully-qualified domain name\n" \
        "  -i  IP address        -d  domain name\n" \
        "  --help"

class HostnameOptions
  attr_accessor :short, :fqdn, :ip, :domain
  def initialize
    @short  = false
    @fqdn   = false
    @ip     = false
    @domain = false
  end
end

def parse_argv(argv)
  opts = HostnameOptions.new
  args = []
  index = 0
  while index < argv.length
    arg = argv[index]
    if arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-s" || arg == "--short"; opts.short = true
    elsif arg == "-f" || arg == "--fqdn" || arg == "--long"; opts.fqdn = true
    elsif arg == "-i" || arg == "--ip-address" || arg == "--all-ip-addresses"
      opts.ip = true
    elsif arg == "-d" || arg == "--domain"; opts.domain = true
    elsif arg.length >= 2 && arg[0] == "-" && arg[1] != "-"
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "s"; opts.short = true
        elsif letter == "f"; opts.fqdn = true
        elsif letter == "i"; opts.ip = true
        elsif letter == "d"; opts.domain = true
        else
          STDERR.puts "hostname: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    else
      args.push(arg)
    end
    index += 1
  end
  [opts, args]
end

def get_hostname
  # Try multiple sources
  if File.exist?("/proc/sys/kernel/hostname")
    return File.read("/proc/sys/kernel/hostname").chomp
  end
  if ENV["HOSTNAME"] && ENV["HOSTNAME"] != ""
    return ENV["HOSTNAME"]
  end
  result = `hostname 2>/dev/null`.chomp
  result == "" ? "localhost" : result
end

opts, args = parse_argv(ARGV)

if args.length > 0
  # Setting hostname — requires system command
  new_name = args[0]
  result = system("hostname #{new_name}")
  exit result ? 0 : 1
end

hostname = get_hostname

if opts.short
  puts hostname.split(".")[0]
elsif opts.domain
  parts = hostname.split(".", 2)
  puts parts.length > 1 ? parts[1] : ""
elsif opts.fqdn
  # Try to get FQDN
  fqdn = `hostname -f 2>/dev/null`.chomp
  puts fqdn == "" ? hostname : fqdn
elsif opts.ip
  ip = `hostname -i 2>/dev/null`.chomp
  puts ip == "" ? "127.0.0.1" : ip
else
  puts hostname
end
