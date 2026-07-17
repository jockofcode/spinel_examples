# ls.rb, list directory contents (GNU ls, Spinel port).
#
# Lists information about each FILE (or the current directory). Sorts entries
# alphabetically by default.
#
# Flags:
#   -l           use a long listing format
#   -a, --all    do not ignore entries starting with .
#   -A, --almost-all  like -a but do not list . and ..
#   -h, --human-readable  with -l, print human-readable sizes
#   -R, --recursive  list subdirectories recursively
#   -r, --reverse  reverse order while sorting
#   -t           sort by modification time, newest first
#   -S           sort by file size, largest first
#   -s, --size   print allocated size in blocks
#   -i, --inode  print index number of each file
#   -d, --directory  list directories themselves, not their contents
#   -F, --classify  append indicator (*/=@|) to entries
#   -p           append / to directories
#   -1           list one file per line
#   -C           list in columns (default for tty; here always column)
#   -m           comma-separated list
#   -n, --numeric-uid-gid  list numeric UIDs and GIDs
#   -q, --hide-control-chars  replace non-graphic chars with ?
#   --color=WHEN  colorize (auto/always/never)
#   --help       usage
#
# Compile: spinel nix_utils/ls.rb -o nix_utils/bin/ls
# Run:
#   ./bin/ls
#   ./bin/ls -la /etc

USAGE = "Usage: ls [OPTION]... [FILE]...\n" \
        "List information about the FILEs (default: current directory).\n" \
        "  -l  long format       -a  all (incl. hidden)   -A  all except . ..\n" \
        "  -h  human sizes       -R  recursive             -r  reverse\n" \
        "  -t  sort by time      -S  sort by size          -s  print sizes\n" \
        "  -i  inodes            -d  list dirs themselves\n" \
        "  -F  classify (*/=@|)  -p  append / to dirs\n" \
        "  -1  one per line      -m  comma-separated\n" \
        "  -n  numeric uid/gid   --color=WHEN  colorize\n" \
        "  --help"

class LsOptions
  attr_accessor :long, :all, :almost_all, :human, :recursive, :reverse
  attr_accessor :sort_time, :sort_size, :no_sort, :show_size, :inode
  attr_accessor :directory, :classify, :append_slash, :one_per_line
  attr_accessor :comma, :numeric, :hide_ctrl, :color
  def initialize
    @long        = false
    @all         = false
    @almost_all  = false
    @human       = false
    @recursive   = false
    @reverse     = false
    @sort_time   = false
    @sort_size   = false
    @no_sort     = false
    @show_size   = false
    @inode       = false
    @directory   = false
    @classify    = false
    @append_slash = false
    @one_per_line = false
    @comma       = false
    @numeric     = false
    @hide_ctrl   = false
    @color       = "auto"
  end
end

def parse_argv(argv)
  opts = LsOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || (arg.length < 2 || arg[0] != "-")
      files.push(arg); index += 1; next
    end
    if arg == "--"; options_done = true; index += 1; next; end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "--all"; opts.all = true
    elsif arg == "--almost-all"; opts.almost_all = true
    elsif arg == "--human-readable"; opts.human = true
    elsif arg == "--recursive"; opts.recursive = true
    elsif arg == "--reverse"; opts.reverse = true
    elsif arg == "--size"; opts.show_size = true
    elsif arg == "--inode"; opts.inode = true
    elsif arg == "--directory"; opts.directory = true
    elsif arg == "--classify"; opts.classify = true
    elsif arg == "--numeric-uid-gid"; opts.numeric = true
    elsif arg == "--hide-control-chars"; opts.hide_ctrl = true
    elsif arg.length > 8 && arg[0, 8] == "--color="; opts.color = arg[8, arg.length - 8]
    elsif arg == "--color" || arg == "--colour"; opts.color = "auto"
    elsif arg == "--no-sort"; opts.no_sort = true
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "l"; opts.long = true
        elsif letter == "a"; opts.all = true
        elsif letter == "A"; opts.almost_all = true
        elsif letter == "h"; opts.human = true
        elsif letter == "R"; opts.recursive = true
        elsif letter == "r"; opts.reverse = true
        elsif letter == "t"; opts.sort_time = true
        elsif letter == "S"; opts.sort_size = true
        elsif letter == "s"; opts.show_size = true
        elsif letter == "i"; opts.inode = true
        elsif letter == "d"; opts.directory = true
        elsif letter == "F"; opts.classify = true
        elsif letter == "p"; opts.append_slash = true
        elsif letter == "1"; opts.one_per_line = true
        elsif letter == "C"; # column mode (default)
        elsif letter == "m"; opts.comma = true
        elsif letter == "n"; opts.numeric = true
        elsif letter == "q"; opts.hide_ctrl = true
        elsif letter == "f"; opts.no_sort = true; opts.all = true
        elsif letter == "U"; opts.no_sort = true
        elsif letter == "g"
          # like -l but without owner
          opts.long = true
        elsif letter == "o"
          # like -l but without group
          opts.long = true
        elsif letter == "b" || letter == "B" || letter == "G" || letter == "k"
          # formatting options, silently accept
        elsif letter == "v" || letter == "x" || letter == "w" || letter == "T"
          # other layout options, silently accept
        else
          STDERR.puts "ls: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

def human_size(n)
  if n < 1024; return n.to_s; end
  units = ["K", "M", "G", "T", "P", "E"]
  i = 0
  val = n.to_f
  while val >= 1024.0 && i < units.length - 1
    val /= 1024.0; i += 1
  end
  # Format with at most 1 decimal place
  if val < 10.0
    whole = val.to_i
    frac = ((val - whole) * 10).to_i
    "#{whole}.#{frac}#{units[i]}"
  else
    "#{val.to_i}#{units[i]}"
  end
end

# File.stat / File.lstat are not available in Spinel.
# All stat info comes from /usr/bin/stat -f on macOS.

class LsStatInfo
  attr_accessor :mode_str, :nlinks, :user_s, :group_s, :size, :time_str, :link_tgt, :is_dir, :is_sym
  def initialize
    @mode_str = "-rw-r--r--"
    @nlinks   = 1
    @user_s   = "?"
    @group_s  = "?"
    @size     = 0
    @time_str = "Jan 01 00:00"
    @link_tgt = ""
    @is_dir   = false
    @is_sym   = false
  end
end

def get_stat_info(path, follow_sym)
  info = LsStatInfo.new
  info.is_dir = File.directory?(path)
  info.is_sym = File.symlink?(path)
  flag = follow_sym ? "-L " : ""
  raw = "" + `/usr/bin/stat #{flag}-f '%Sp %l %Su %Sg %z %Sm' -t '%b %d %H:%M' '#{path}' 2>/dev/null`
  craw = "" + raw.chomp
  parts = craw.split(" ")
  if parts.length >= 8
    info.mode_str = "" + parts[0]
    info.nlinks   = parts[1].to_i
    info.user_s   = "" + parts[2]
    info.group_s  = "" + parts[3]
    info.size     = parts[4].to_i
    info.time_str = "" + parts[5] + " " + parts[6] + " " + parts[7]
  end
  if info.is_sym
    lraw = "" + `/usr/bin/stat -f '%Y' '#{path}' 2>/dev/null`
    info.link_tgt = "" + lraw.chomp
  end
  info
end

def classify_suffix_from_info(info)
  if info.is_dir; "/"
  elsif info.is_sym; "@"
  elsif info.mode_str.length >= 4 && info.mode_str[3] == "x"; "*"
  else ""
  end
end

def print_entry(name, dir, opts)
  cname = "" + name
  full = dir != "" ? dir + "/" + cname : cname
  info = get_stat_info(full, false)

  display = cname
  if opts.hide_ctrl
    display = ""
    ci = 0
    while ci < cname.length
      b = cname[ci].ord
      display = display + (b >= 0x20 && b <= 0x7e ? cname[ci] : "?")
      ci += 1
    end
  end

  if opts.classify
    display = display + classify_suffix_from_info(info)
  elsif opts.append_slash && info.is_dir
    display = display + "/"
  end

  if opts.long
    nlink_s  = info.nlinks.to_s.rjust(3)
    size_str = opts.human ? human_size(info.size).rjust(6) : info.size.to_s.rjust(8)
    link_part = info.is_sym ? " -> " + info.link_tgt : ""
    puts "" + info.mode_str + " " + nlink_s + " " + info.user_s.ljust(8) + " " + info.group_s.ljust(8) + " " + size_str + " " + info.time_str + " " + display + link_part
  else
    display
  end
end

def list_dir(path, opts, header)
  cpath = "" + path
  entries = Dir.entries(cpath)

  # Collect visible entries into a typed StrArray
  visible = []
  visible.push(""); visible.pop
  entries.each do |e|
    ce = "" + e
    if ce.start_with?(".")
      next unless opts.all || opts.almost_all
      next if (ce == "." || ce == "..") && opts.almost_all
    end
    visible.push(ce)
  end

  # Sort alphabetically (sort_time/-S require File.lstat which is not available)
  visible = visible.sort unless opts.no_sort
  visible = visible.reverse if opts.reverse

  puts "" + cpath + ":" if header

  if opts.long
    puts "total 0"
    visible.each do |e|
      ce = "" + e
      full = cpath + "/" + ce
      next unless File.exist?(full) || File.symlink?(full)
      print_entry(ce, cpath, opts)
    end
  elsif opts.comma
    cparts = []
    cparts.push(""); cparts.pop
    visible.each do |e|
      ce = "" + e
      full = cpath + "/" + ce
      next unless File.exist?(full) || File.symlink?(full)
      info = get_stat_info(full, false)
      entry_name = opts.classify ? ce + classify_suffix_from_info(info) : ce
      entry_name = (opts.append_slash && info.is_dir) ? ce + "/" : entry_name
      cparts.push(entry_name)
    end
    puts cparts.join(", ")
  elsif opts.one_per_line
    visible.each do |e|
      ce = "" + e
      full = cpath + "/" + ce
      next unless File.exist?(full) || File.symlink?(full)
      result = print_entry(ce, cpath, opts)
      puts result
    end
  else
    names = []
    names.push(""); names.pop
    visible.each do |e|
      ce = "" + e
      full = cpath + "/" + ce
      next unless File.exist?(full) || File.symlink?(full)
      result = print_entry(ce, cpath, opts)
      names.push(result)
    end
    puts names.join("  ")
  end

  if opts.recursive
    visible.each do |e|
      ce = "" + e
      full = cpath + "/" + ce
      if File.directory?(full) && !File.symlink?(full) && ce != "." && ce != ".."
        puts ""
        list_dir(full, opts, true)
      end
    end
  end
end

opts, files = parse_argv(ARGV)
files = ["."] if files.empty?

exit_code = 0
dirs = []
dirs.push(""); dirs.pop
non_dirs = []
non_dirs.push(""); non_dirs.pop

files.each do |f|
  cf = "" + f
  if !File.exist?(cf) && !File.symlink?(cf)
    STDERR.puts "ls: cannot access '#{cf}': No such file or directory"
    exit_code = 1
    next
  end
  if File.directory?(cf) && !opts.directory
    dirs.push(cf)
  else
    non_dirs.push(cf)
  end
end

# Print non-directories first
non_dirs.each do |f|
  cf = "" + f
  if opts.long
    cname = "" + File.basename(cf)
    cdir  = "" + File.dirname(cf)
    print_entry(cname, cdir, opts)
  else
    cname = "" + File.basename(cf)
    info = get_stat_info(cf, false)
    suffix = opts.classify ? classify_suffix_from_info(info) : (opts.append_slash && info.is_dir ? "/" : "")
    puts cname + suffix
  end
end

show_header = files.length > 1 || (dirs.length > 0 && non_dirs.length > 0)

dir_idx = 0
dirs.each do |d|
  cd = "" + d
  puts "" if show_header && (non_dirs.length > 0 || dir_idx > 0)
  list_dir(cd, opts, show_header)
  dir_idx += 1
end

exit exit_code
