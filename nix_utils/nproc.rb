# nproc.rb, print the number of processing units available (GNU nproc, Spinel port).
#
# Flags:
#   --all        print the total installed processors (ignore OMP env vars)
#   --ignore=N   subtract N from result (minimum 1)
#   --help, --version
#
# Compile: spinel nix_utils/nproc.rb -o nix_utils/bin/nproc

USAGE = "Usage: nproc [OPTION]...\n" \
        "Print the number of processing units available to the current process,\n" \
        "which may be less than the number of online processors.\n" \
        "  --all       print the number of installed processors\n" \
        "  --ignore=N  if possible, exclude N processing units\n" \
        "  --help      display this help and exit\n" \
        "  --version   output version information and exit"

VERSION = "nproc (nix_utils) 1.0"

require_relative "nix_helpers"

show_all = false
ignore_n = 0

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "--all"
    show_all = true
  elsif arg.length > 9 && arg[0, 9] == "--ignore="
    ignore_n = arg[9, arg.length - 9].to_i
  else
    die("nproc: unrecognized option '#{arg}'\nTry 'nproc --help' for more information.")
  end
  index += 1
end

def cpu_count_all
  # macOS
  if File.exist?("/usr/sbin/sysctl")
    raw = `sysctl -n hw.logicalcpu 2>/dev/null`
    n = ("" + raw).strip.to_i
    return n if n > 0
  end
  # Linux
  if File.exist?("/proc/cpuinfo")
    count = 0
    File.read("/proc/cpuinfo").split("\n").each do |line|
      count += 1 if ("" + line).start_with?("processor")
    end
    return count if count > 0
  end
  1
end

def cpu_count_available
  # macOS active CPUs
  if File.exist?("/usr/sbin/sysctl")
    raw = `sysctl -n hw.activecpu 2>/dev/null`
    n = ("" + raw).strip.to_i
    return n if n > 0
  end
  cpu_count_all
end

if show_all
  count = cpu_count_all
else
  count = cpu_count_available
  # Respect OMP_NUM_THREADS and OMP_THREAD_LIMIT
  omp_num = ENV["OMP_NUM_THREADS"]
  omp_lim = ENV["OMP_THREAD_LIMIT"]
  unless omp_num.nil? || ("" + omp_num) == ""
    n = ("" + omp_num).to_i
    count = n if n > 0 && n < count
  end
  unless omp_lim.nil? || ("" + omp_lim) == ""
    n = ("" + omp_lim).to_i
    count = n if n > 0 && n < count
  end
end

count = count - ignore_n
count = 1 if count < 1
puts count
