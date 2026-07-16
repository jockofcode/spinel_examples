# uname.rb, print system information (GNU uname, Spinel port).
#
# Prints information about the current system by reading /proc/version (Linux)
# or running system commands. Falls back to sensible defaults.
#
# Flags:
#   -a, --all           print all information (same as -snrvmo)
#   -s, --kernel-name   print kernel name
#   -n, --nodename      print network node hostname
#   -r, --kernel-release  print kernel release
#   -v, --kernel-version  print kernel version
#   -m, --machine       print machine hardware name
#   -p, --processor     print processor type
#   -i, --hardware-platform  print hardware platform
#   -o, --operating-system   print operating system
#   --help              usage
#
# Compile: spinel nix_utils/uname.rb -o nix_utils/bin/uname
# Run:
#   ./bin/uname -a
#   ./bin/uname -sr

USAGE = "Usage: uname [OPTION]...\n" \
        "Print certain system information.\n" \
        "  -a  all info   -s  kernel name   -n  hostname\n" \
        "  -r  kernel release   -v  kernel version\n" \
        "  -m  machine   -p  processor   -i  hardware platform\n" \
        "  -o  operating system\n" \
        "  --help"

class UnameOptions
  attr_accessor :all, :kernel_name, :nodename, :kernel_release
  attr_accessor :kernel_version, :machine, :processor, :hardware, :os
  def initialize
    @all            = false
    @kernel_name    = false
    @nodename       = false
    @kernel_release = false
    @kernel_version = false
    @machine        = false
    @processor      = false
    @hardware       = false
    @os             = false
  end
  def any?
    @all || @kernel_name || @nodename || @kernel_release ||
      @kernel_version || @machine || @processor || @hardware || @os
  end
end

def parse_argv(argv)
  opts = UnameOptions.new
  index = 0
  while index < argv.length
    arg = argv[index]
    if arg == "--help"
      puts USAGE; exit 0
    elsif arg == "--all"; opts.all = true
    elsif arg == "--kernel-name"; opts.kernel_name = true
    elsif arg == "--nodename"; opts.nodename = true
    elsif arg == "--kernel-release"; opts.kernel_release = true
    elsif arg == "--kernel-version"; opts.kernel_version = true
    elsif arg == "--machine"; opts.machine = true
    elsif arg == "--processor"; opts.processor = true
    elsif arg == "--hardware-platform"; opts.hardware = true
    elsif arg == "--operating-system"; opts.os = true
    elsif arg.length >= 2 && arg[0] == "-" && arg[1] != "-"
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "a"; opts.all = true
        elsif letter == "s"; opts.kernel_name = true
        elsif letter == "n"; opts.nodename = true
        elsif letter == "r"; opts.kernel_release = true
        elsif letter == "v"; opts.kernel_version = true
        elsif letter == "m"; opts.machine = true
        elsif letter == "p"; opts.processor = true
        elsif letter == "i"; opts.hardware = true
        elsif letter == "o"; opts.os = true
        else
          STDERR.puts "uname: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    else
      STDERR.puts "uname: extra operand '#{arg}'"
      exit 1
    end
    index += 1
  end
  opts
end

def read_proc_info
  info = { sysname: "Linux", nodename: "localhost", release: "", version: "", machine: "" }
  if File.exist?("/proc/sys/kernel/ostype")
    info[:sysname] = File.read("/proc/sys/kernel/ostype").chomp
  end
  if File.exist?("/proc/sys/kernel/hostname")
    info[:nodename] = File.read("/proc/sys/kernel/hostname").chomp
  end
  if File.exist?("/proc/sys/kernel/osrelease")
    info[:release] = File.read("/proc/sys/kernel/osrelease").chomp
  end
  if File.exist?("/proc/version")
    ver_line = File.read("/proc/version").chomp
    info[:version] = ver_line
    m = Regexp.new(' version (\S+)').match(ver_line)
    if m
      info[:release] = "" + m[1].to_s if info[:release] == ""
    end
  end
  if File.exist?("/proc/sys/kernel/version")
    info[:version] = File.read("/proc/sys/kernel/version").chomp
  end
  # Machine: try /proc/cpuinfo
  if File.exist?("/proc/cpuinfo")
    File.read("/proc/cpuinfo").lines.each do |line|
      if line.start_with?("model name") || line.start_with?("Hardware")
        parts = line.split(":")
        info[:machine] = parts[1].strip if parts.length > 1
        break
      end
    end
  end
  info[:machine] = ENV["HOSTTYPE"] || "x86_64" if info[:machine] == ""
  info
end

# Try to get uname from the system
def system_uname
  result = `uname -a 2>/dev/null`.chomp
  parts = result.split(" ")
  {
    sysname:  parts[0] || "Linux",
    nodename: parts[1] || "localhost",
    release:  parts[2] || "",
    version:  parts[3] || "",
    machine:  parts[-1] || "x86_64"
  }
end

opts = parse_argv(ARGV)
opts.kernel_name = true unless opts.any?  # default: print kernel name

info = if File.exist?("/proc/version") || File.exist?("/proc/sys/kernel/ostype")
  read_proc_info
else
  system_uname
end

parts = []
show_all = opts.all

parts.push(info[:sysname])                           if show_all || opts.kernel_name
parts.push(info[:nodename])                          if show_all || opts.nodename
parts.push(info[:release])                           if show_all || opts.kernel_release
parts.push(info[:version])                           if show_all || opts.kernel_version
parts.push(info[:machine])                           if show_all || opts.machine
parts.push("unknown")                                if show_all || opts.processor
parts.push("unknown")                                if show_all || opts.hardware
parts.push(File.exist?("/proc") ? "GNU/Linux" : RUBY_PLATFORM.split("-").last || "GNU/Linux") if show_all || opts.os

puts parts.join(" ")
