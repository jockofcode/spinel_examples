# du.rb, estimate file space usage (GNU du, Spinel port).
#
# Flags: -a, -A/--apparent-size, -b, -B SIZE, -c, -d N, -h, -k, -m, -s,
#   --si, -L, -P, -D, -S, -x, -t SIZE, --time[=WORD], --time-style=STYLE,
#   --exclude=PAT, -X FILE, --inodes, -l, --help, --version
#
# Skip: -0/--null, --files0-from (NUL impossible in Spinel)
#
# Compile: spinel nix_utils/du.rb -o nix_utils/bin/du

USAGE = "Usage: du [OPTION]... [FILE]...\n" \
        "Summarize device usage of the set of FILEs, recursively for directories.\n" \
        "  -a  all files   -s  summarize   -h  human-readable   --si  SI units\n" \
        "  -k  1K blocks   -m  1M blocks   -b  apparent bytes\n" \
        "  -d N, --max-depth=N   -c  total   -S  separate-dirs\n" \
        "  -L  follow symlinks   -x  one filesystem\n" \
        "  -t SIZE  threshold   --time  show modification time\n" \
        "  --exclude=PAT   -X FILE  exclude patterns\n" \
        "  --inodes   -l  count hardlinks\n" \
        "  --help    --version\n" \
        "  -0/--null and --files0-from unsupported (NUL bytes not possible in this build)"

VERSION = "du (nix_utils) 1.0"

require_relative "nix_helpers"

class DuOptions
  attr_accessor :all_files, :apparent_size, :block_size, :show_total, :max_depth
  attr_accessor :human, :si_units, :follow_links, :follow_args_links, :separate_dirs
  attr_accessor :one_filesystem, :threshold, :show_time, :time_style
  attr_accessor :exclude_pats, :inodes, :count_links
  def initialize
    @all_files       = false
    @apparent_size   = false
    @block_size      = 1024
    @show_total      = false
    @max_depth       = nil
    @human           = false
    @si_units        = false
    @follow_links    = false
    @follow_args_links = false
    @separate_dirs   = false
    @one_filesystem  = false
    @threshold       = nil    # Integer bytes; negative means "smaller than"
    @show_time       = false
    @time_style      = nil
    @exclude_pats    = []
    @inodes          = false
    @count_links     = false
  end
end

opts         = DuOptions.new
paths        = []
options_done = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if options_done || (arg[0] != "-" && arg != "-")
    paths.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-a" || arg == "--all"
    opts.all_files = true
  elsif arg == "-A" || arg == "--apparent-size"
    opts.apparent_size = true
  elsif arg == "-b" || arg == "--bytes"
    opts.apparent_size = true; opts.block_size = 1
  elsif arg == "-k"
    opts.block_size = 1024
  elsif arg == "-m"
    opts.block_size = 1024 * 1024
  elsif arg == "-h" || arg == "--human-readable"
    opts.human = true
  elsif arg == "--si"
    opts.human = true; opts.si_units = true
  elsif arg == "-c" || arg == "--total"
    opts.show_total = true
  elsif arg == "-s" || arg == "--summarize"
    opts.max_depth = 0
  elsif arg == "-d"
    index += 1; opts.max_depth = coerce(ARGV[index]).to_i
  elsif arg.length > 2 && arg[0, 2] == "-d"
    opts.max_depth = arg[2, arg.length - 2].to_i
  elsif arg.length > 12 && arg[0, 12] == "--max-depth="
    opts.max_depth = arg[12, arg.length - 12].to_i
  elsif arg == "-L" || arg == "--dereference"
    opts.follow_links = true
  elsif arg == "-P" || arg == "--no-dereference"
    opts.follow_links = false
  elsif arg == "-D" || arg == "--dereference-args"
    opts.follow_args_links = true
  elsif arg == "-S" || arg == "--separate-dirs"
    opts.separate_dirs = true
  elsif arg == "-x" || arg == "--one-file-system"
    opts.one_filesystem = true
  elsif arg == "-l" || arg == "--count-links"
    opts.count_links = true
  elsif arg == "--inodes"
    opts.inodes = true
  elsif arg == "-B"
    index += 1; opts.block_size = parse_size_suffix(coerce(ARGV[index]))
  elsif arg.length > 13 && arg[0, 13] == "--block-size="
    opts.block_size = parse_size_suffix(arg[13, arg.length - 13])
  elsif arg == "-t"
    index += 1
    sv = coerce(ARGV[index])
    if sv[0] == "+"
      opts.threshold = parse_size_suffix(sv[1, sv.length - 1])
    elsif sv[0] == "-"
      opts.threshold = -parse_size_suffix(sv[1, sv.length - 1])
    else
      opts.threshold = parse_size_suffix(sv)
    end
  elsif arg.length > 12 && arg[0, 12] == "--threshold="
    sv = arg[12, arg.length - 12]
    if sv[0] == "+"
      opts.threshold = parse_size_suffix(sv[1, sv.length - 1])
    elsif sv[0] == "-"
      opts.threshold = -parse_size_suffix(sv[1, sv.length - 1])
    else
      opts.threshold = parse_size_suffix(sv)
    end
  elsif arg == "--time"
    opts.show_time = true
  elsif arg.length > 7 && arg[0, 7] == "--time="
    opts.show_time = true; opts.time_style = arg[7, arg.length - 7]
  elsif arg.length > 13 && arg[0, 13] == "--time-style="
    opts.time_style = arg[13, arg.length - 13]
  elsif arg.length > 10 && arg[0, 10] == "--exclude="
    opts.exclude_pats.push(arg[10, arg.length - 10])
  elsif arg == "-X" || arg == "--exclude-from"
    index += 1
    xf = coerce(ARGV[index])
    File.read(xf).split("\n").each { |p| opts.exclude_pats.push("" + p) }
  elsif arg == "-0" || arg == "--null" || arg == "--files0-from"
    die("du: #{arg} is unsupported in this build (NUL bytes not possible in Spinel C strings)")
  elsif arg[0] != "-"
    paths.push(arg)
  else
    die("du: invalid option -- '#{arg}'\nTry 'du --help' for more information.")
  end
  index += 1
end

paths = ["."] if paths.empty?

def device_of(path)
  raw = `stat -f '%d' '#{path}' 2>/dev/null`
  ("" + raw).strip.to_i
end

def excluded?(path, pats)
  base = File.basename("" + path)
  pats.each do |pat|
    return true if File.fnmatch("" + pat, base)
  end
  false
end

def file_size_blocks(path, opts)
  s = "" + path
  if opts.inodes
    return 1
  end
  if opts.apparent_size
    begin
      sz = File.size(s)
    rescue
      sz = 0
    end
    if opts.block_size == 1
      return sz
    end
    return (sz + opts.block_size - 1) / opts.block_size
  end
  # Disk blocks: approximate as size rounded to 512-byte blocks, then convert
  begin
    sz = File.size(s)
  rescue
    return 0
  end
  blocks_512 = (sz + 511) / 512
  if opts.block_size == 1
    return sz
  end
  (blocks_512 * 512 + opts.block_size - 1) / opts.block_size
end

def du_recurse(path, depth, root_device, opts, output_lines)
  cp = "" + path
  return 0 if excluded?(cp, opts.exclude_pats)

  is_symlink = File.symlink?(cp)
  is_dir     =
    if is_symlink && opts.follow_links
      File.exist?(cp) && File.directory?(cp)
    elsif is_symlink
      false
    else
      File.directory?(cp)
    end

  unless is_dir
    sz = file_size_blocks(cp, opts)
    if opts.all_files
      max_d = opts.max_depth
      if max_d.nil? || depth <= max_d
        output_lines.push([sz, cp, File.mtime(cp)])
      end
    end
    return sz
  end

  # Directory
  if opts.one_filesystem
    dev = device_of(cp)
    if dev != root_device
      return 0
    end
  end

  begin
    entries = Dir.entries(cp)
  rescue
    STDERR.puts "du: cannot read directory '#{cp}'"
    return 0
  end

  dir_total = 0
  child_total = 0
  entries.each do |e|
    ce = "" + e
    next if ce == "." || ce == ".."
    child_path = cp + "/" + ce
    child_sz   = du_recurse(child_path, depth + 1, root_device, opts, output_lines)
    child_total += child_sz
  end

  own_sz = file_size_blocks(cp, opts)
  if opts.separate_dirs
    dir_total = own_sz
  else
    dir_total = own_sz + child_total
  end

  max_d = opts.max_depth
  if max_d.nil? || depth <= max_d
    output_lines.push([dir_total, cp, File.mtime(cp)])
  end

  dir_total
end

def format_size(size, opts)
  if opts.human
    format_human(size * opts.block_size, opts.si_units)
  else
    size.to_s
  end
end

def format_time_val(t, style)
  if style.nil? || ("" + style) == "full-iso"
    t.strftime("%Y-%m-%d %H:%M:%S.%N %z")
  elsif ("" + style) == "long-iso"
    t.strftime("%Y-%m-%d %H:%M")
  elsif ("" + style) == "iso"
    t.strftime("%Y-%m-%d")
  else
    # treat as strftime format
    t.strftime("" + style)
  end
end

grand_total = 0
output_lines = []

paths.each do |p|
  cp = "" + p
  unless File.exist?(cp) || File.symlink?(cp)
    STDERR.puts "du: cannot access '#{cp}': No such file or directory"
    next
  end
  root_dev = opts.one_filesystem ? device_of(cp) : 0
  sz = du_recurse(cp, 0, root_dev, opts, output_lines)
  grand_total += sz
end

# Sort output by path for readability; du actually prints in traversal order
# so we replay the output_lines array as-is.
output_lines.each do |entry|
  sz   = entry[0]
  path = "" + entry[1]
  mtime = entry[2]
  next if !opts.threshold.nil? && opts.threshold > 0 && sz * opts.block_size < opts.threshold
  next if !opts.threshold.nil? && opts.threshold < 0 && sz * opts.block_size > -opts.threshold

  size_str = format_size(sz, opts)
  if opts.show_time
    time_str = format_time_val(mtime, opts.time_style)
    puts "#{size_str}\t#{time_str}\t#{path}"
  else
    puts "#{size_str}\t#{path}"
  end
end

if opts.show_total
  size_str = format_size(grand_total, opts)
  puts "#{size_str}\ttotal"
end
