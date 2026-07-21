# tail.rb, output the last part of files (GNU tail, Spinel port).
#
# Prints the last 10 lines of each FILE (or standard input when a file is "-"
# or none given). With more than one file, each is preceded by a header unless
# -q is given.
#
# Flags:
#   -n, --lines=[+]NUM      last NUM lines; with +NUM, start from line NUM
#   -c, --bytes=[+]NUM      last NUM bytes; with +NUM, start from byte NUM
#   -q, --quiet, --silent   never print file-name headers
#   -v, --verbose           always print file-name headers
#   -f, --follow[=descriptor]  output appended data as the file grows
#   -F                      same as --follow=name --retry
#   -s N, --sleep-interval=N  with -f, sleep for N seconds between polls (default 1.0)
#   --pid=PID               with -f, exit after PID dies
#   --retry                 keep trying to open an inaccessible file (with -f)
#   --help                  usage
#
# NUM multiplier suffixes: b 512, kB 1000, K/KiB 1024, MB 1000^2, M/MiB 1024^2,
#                          GB 1000^3, G/GiB 1024^3
#
# Compile: spinel nix_utils/tail.rb -o nix_utils/bin/tail
# Run:
#   ./bin/tail file.txt
#   ./bin/tail -n 3 a.txt b.txt
#   printf 'a\nb\nc\n' | ./bin/tail -n1
#   ./bin/tail -f growing.log
#
# Core Ruby only (File, STDIN, STDOUT, String, Array, Kernel#sleep); no require gate.
# Runs unmodified under CRuby (`ruby nix_utils/tail.rb ...`).

USAGE = "Usage: tail [OPTION]... [FILE]...\n" \
        "Print the last 10 lines of each FILE to standard output.\n" \
        "With no FILE, or when FILE is -, read standard input.\n" \
        "  -n [+]NUM   last NUM lines (or start at line NUM with +)\n" \
        "  -c [+]NUM   last NUM bytes (or start at byte NUM with +)\n" \
        "  -q  never print headers   -v  always print headers\n" \
        "  -f  follow   -F  follow by name\n" \
        "  -s N  poll interval (default 1.0)   --pid=PID  exit when PID dies\n" \
        "  --help"

class TailOptions
  attr_accessor :count, :from_start, :by_bytes, :quiet, :verbose
  attr_accessor :follow, :follow_name, :retry_open, :sleep_interval, :pid
  def initialize
    @count          = 10
    @from_start     = false
    @by_bytes       = false
    @quiet          = false
    @verbose        = false
    @follow         = false
    @follow_name    = false
    @retry_open     = false
    @sleep_interval = 1.0
    @pid            = nil
  end
end

# Parse multiplier suffixes for -n/-c values (returns byte/line count).
def parse_multiplier(text)
  if text.end_with?("KiB") || text.end_with?("K")
    base = text.end_with?("KiB") ? text[0, text.length - 3] : text[0, text.length - 1]
    return base.to_i * 1024
  elsif text.end_with?("MiB") || text.end_with?("M")
    base = text.end_with?("MiB") ? text[0, text.length - 3] : text[0, text.length - 1]
    return base.to_i * 1024 * 1024
  elsif text.end_with?("GiB") || text.end_with?("G")
    base = text.end_with?("GiB") ? text[0, text.length - 3] : text[0, text.length - 1]
    return base.to_i * 1024 * 1024 * 1024
  elsif text.end_with?("kB") || text.end_with?("KB")
    base = text.end_with?("kB") ? text[0, text.length - 2] : text[0, text.length - 2]
    return base.to_i * 1000
  elsif text.end_with?("MB")
    return text[0, text.length - 2].to_i * 1000 * 1000
  elsif text.end_with?("GB")
    return text[0, text.length - 2].to_i * 1000 * 1000 * 1000
  elsif text.end_with?("b")
    return text[0, text.length - 1].to_i * 512
  else
    return text.to_i
  end
end

def set_count(value, label, opts)
  text = value
  if text.length > 0 && text[0] == "+"
    opts.from_start = true
    text = text[1, text.length - 1]
  else
    opts.from_start = false
  end
  if text.length == 0
    STDERR.puts "tail: invalid number of #{label}: '#{value}'"
    exit 1
  end
  opts.count = parse_multiplier(text)
end

def parse_argv(argv, opts)
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-q" || arg == "--quiet" || arg == "--silent"
      opts.quiet = true
    elsif arg == "-v" || arg == "--verbose"
      opts.verbose = true
    elsif arg == "-f" || arg == "--follow" || arg == "--follow=descriptor"
      opts.follow = true
    elsif arg == "--follow=name"
      opts.follow = true; opts.follow_name = true
    elsif arg == "-F"
      opts.follow = true; opts.follow_name = true; opts.retry_open = true
    elsif arg == "--retry"
      opts.retry_open = true
    elsif arg == "--debug"
      # Accepted for compatibility; this port emits no extra diagnostics.

    elsif arg == "-n" || arg == "--lines"
      index += 1; set_count(argv[index], "lines", opts)
    elsif arg.length > 2 && arg[0, 2] == "-n"
      set_count(arg[2, arg.length - 2], "lines", opts)
    elsif arg.length > 8 && arg[0, 8] == "--lines="
      set_count(arg[8, arg.length - 8], "lines", opts)
    elsif arg == "-c" || arg == "--bytes"
      index += 1; opts.by_bytes = true; set_count(argv[index], "bytes", opts)
    elsif arg.length > 2 && arg[0, 2] == "-c"
      opts.by_bytes = true; set_count(arg[2, arg.length - 2], "bytes", opts)
    elsif arg.length > 8 && arg[0, 8] == "--bytes="
      opts.by_bytes = true; set_count(arg[8, arg.length - 8], "bytes", opts)
    elsif arg == "-s" || arg == "--sleep-interval"
      index += 1; opts.sleep_interval = argv[index].to_f
    elsif arg.length > 2 && arg[0, 2] == "-s"
      opts.sleep_interval = arg[2, arg.length - 2].to_f
    elsif arg.length > 17 && arg[0, 17] == "--sleep-interval="
      opts.sleep_interval = arg[17, arg.length - 17].to_f
    elsif arg.length > 6 && arg[0, 6] == "--pid="
      opts.pid = arg[6, arg.length - 6].to_i
    else
      STDERR.puts "tail: unrecognized option '#{arg}'"
      STDERR.puts "Try 'tail --help' for more information."
      exit 1
    end
    index += 1
  end
  files
end

def read_source(name)
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

def split_lines(content)
  lines = content.split("\n", -1)
  lines.pop if !lines.empty? && lines.last == ""
  lines
end

def rejoin_lines(lines)
  lines.empty? ? "" : lines.join("\n") + "\n"
end

def byte_tail(content, opts)
  total = content.bytesize
  if opts.from_start
    start = opts.count - 1
    start = total if start > total
    return start < total ? content[start, total - start] : ""
  end
  keep = opts.count < total ? opts.count : total
  content[total - keep, keep]
end

def line_tail(content, opts)
  lines = split_lines(content)
  if opts.from_start
    start = opts.count - 1
    start = lines.length if start > lines.length
    return rejoin_lines(lines[start, lines.length - start])
  end
  keep = opts.count < lines.length ? opts.count : lines.length
  rejoin_lines(lines[lines.length - keep, keep])
end

def tail_slice(content, opts)
  opts.by_bytes ? byte_tail(content, opts) : line_tail(content, opts)
end

# Check if a process is still running. Uses /proc on Linux; returns true
# (assume alive) on platforms where /proc is not available.
def pid_alive?(pid)
  return true if pid.nil?
  File.exist?("/proc/#{pid}")
end

opts = TailOptions.new
files = parse_argv(ARGV, opts)
files = ["-"] if files.empty?

print_headers = (files.length > 1 || opts.verbose) && !opts.quiet
exit_code = 0
first = true

files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    unless opts.retry_open
      STDERR.puts "tail: cannot open '#{cname}' for reading: No such file or directory"
      exit_code = 1
      next
    end
  end
  if cname != "-" && File.exist?(cname) && File.directory?(cname)
    STDERR.puts "tail: error reading '#{cname}': Is a directory"
    exit_code = 1
    next
  end

  if print_headers
    puts "" unless first
    label = (cname == "-") ? "standard input" : cname
    puts "==> #{label} <=="
  end
  first = false

  STDOUT.write(tail_slice(read_source(cname), opts))
end

# -f / --follow: poll for new content on the last file.
if opts.follow && !files.empty?
  STDOUT.sync = true
  follow_name = files.last
  is_stdin    = follow_name == "-"

  # Determine how many bytes we have already output so we can seek past them.
  last_size =
    if is_stdin
      0
    elsif File.exist?(follow_name)
      File.size(follow_name)
    else
      0
    end

  # For --follow=name / -F, track the inode so we detect rotation.
  # File.stat.ino not available in Spinel; use shell stat -f %i instead.
  last_inode = 0
  if !is_stdin && File.exist?(follow_name)
    last_inode = `stat -f '%i' '#{follow_name}'`.to_i
  end

  while pid_alive?(opts.pid)
    sleep(opts.sleep_interval)

    if is_stdin
      # Can't meaningfully follow stdin after initial read; just idle.
      next
    end

    # Handle file rotation (-F / --follow=name).
    if opts.follow_name && File.exist?(follow_name)
      current_inode = `stat -f '%i' '#{follow_name}'`.to_i
      if current_inode != last_inode
        # File was replaced. Announce the new file and reset.
        STDERR.puts "tail: '#{follow_name}' has been replaced; following new file"
        last_size  = 0
        last_inode = current_inode
      end
    elsif opts.retry_open && !File.exist?(follow_name)
      next
    elsif !File.exist?(follow_name)
      break
    end

    current_size = File.size(follow_name)
    if current_size > last_size
      # Read and print only the new bytes.
      f = File.open(follow_name, "rb")
      f.seek(last_size)
      chunk = f.read(current_size - last_size)
      f.close
      STDOUT.write(chunk)
      last_size = current_size
    elsif current_size < last_size
      # File was truncated.
      last_size = current_size
    end
  end
end

exit exit_code
