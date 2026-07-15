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

LS_MODE_BITS = [[0o400, "r"], [0o200, "w"], [0o100, "x"],
               [0o040, "r"], [0o020, "w"], [0o010, "x"],
               [0o004, "r"], [0o002, "w"], [0o001, "x"]]

def mode_to_string(mode, ftype_char)
  bits = ""
  LS_MODE_BITS.each do |pair|
    bits += (mode & pair[0]) != 0 ? pair[1] : "-"
  end
  bits[2] = (mode & 0o4000) != 0 ? ((mode & 0o100) != 0 ? "s" : "S") : bits[2]
  bits[5] = (mode & 0o2000) != 0 ? ((mode & 0o010) != 0 ? "s" : "S") : bits[5]
  bits[8] = (mode & 0o1000) != 0 ? ((mode & 0o001) != 0 ? "t" : "T") : bits[8]
  ftype_char + bits
end

def ftype_char(stat)
  if stat.directory?; "d"
  elsif stat.symlink?; "l"
  elsif stat.blockdev?; "b"
  elsif stat.chardev?; "c"
  elsif stat.pipe?; "p"
  elsif stat.socket?; "s"
  else "-"
  end
end

def lookup_name_for_uid(uid)
  if File.exist?("/etc/passwd")
    File.read("/etc/passwd").lines.each do |line|
      parts = line.chomp.split(":")
      return parts[0] if parts.length >= 3 && parts[2].to_i == uid
    end
  end
  uid.to_s
end

def lookup_name_for_gid(gid)
  if File.exist?("/etc/group")
    File.read("/etc/group").lines.each do |line|
      parts = line.chomp.split(":")
      return parts[0] if parts.length >= 3 && parts[2].to_i == gid
    end
  end
  gid.to_s
end

def format_time(t)
  now = Time.now
  y  = t.year.to_s.rjust(4)
  mo = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][t.month - 1]
  d  = t.day.to_s.rjust(2)
  if (now - t).abs < 15552000  # 6 months
    h  = t.hour.to_s.rjust(2, "0")
    mi = t.min.to_s.rjust(2, "0")
    "#{mo} #{d} #{h}:#{mi}"
  else
    "#{mo} #{d}  #{y}"
  end
end

def classify_suffix(stat, name)
  if stat.directory?; "/"
  elsif stat.symlink?; "@"
  elsif stat.pipe?; "|"
  elsif stat.socket?; "="
  elsif (stat.mode & 0o111) != 0; "*"
  else ""
  end
end

def print_entry(name, dir, opts, stat_method = :lstat)
  full = dir ? dir + "/" + name : name
  stat = File.send(stat_method, full)
  ftype = ftype_char(stat)

  if opts.hide_ctrl
    display = ""
    name.bytes.each do |b|
      display += (b >= 0x20 && b <= 0x7e) ? b.chr : "?"
    end
  else
    display = name
  end

  if opts.inode
    display = stat.ino.to_s.rjust(8) + " " + display
  end

  if opts.show_size
    blk = (stat.blocks / 2).to_s.rjust(5)
    display = blk + " " + display
  end

  if opts.classify
    display += classify_suffix(stat, name)
  elsif opts.append_slash && stat.directory?
    display += "/"
  end

  if opts.long
    mode_str  = mode_to_string(stat.mode, ftype)
    nlink     = stat.nlink.to_s.rjust(3)
    uid_str   = opts.numeric ? stat.uid.to_s : lookup_name_for_uid(stat.uid)
    gid_str   = opts.numeric ? stat.gid.to_s : lookup_name_for_gid(stat.gid)
    size_str  = opts.human ? human_size(stat.size).rjust(6) : stat.size.to_s.rjust(8)
    time_str  = format_time(stat.mtime)
    link_target = stat.symlink? ? " -> " + File.readlink(full) : ""
    puts "#{mode_str} #{nlink} #{uid_str.ljust(8)} #{gid_str.ljust(8)} #{size_str} #{time_str} #{display}#{link_target}"
  else
    display
  end
end

def list_dir(path, opts, header = false)
  entries = Dir.entries(path)

  # Filter hidden
  visible = []
  entries.each do |e|
    if e.start_with?(".")
      next unless opts.all || opts.almost_all
      next if (e == "." || e == "..") && opts.almost_all
    end
    visible.push(e)
  end

  # Sort
  unless opts.no_sort
    if opts.sort_time
      visible = visible.sort_by { |e|
        full = path + "/" + e
        File.exist?(full) || File.symlink?(full) ? File.lstat(full).mtime.to_i : 0
      }
    elsif opts.sort_size
      visible = visible.sort_by { |e|
        full = path + "/" + e
        File.exist?(full) || File.symlink?(full) ? -File.lstat(full).size : 0
      }
    else
      visible = visible.sort
    end
    visible = visible.reverse if opts.reverse
  end

  puts "#{path}:" if header

  if opts.long
    # Print total blocks
    total_blocks = 0
    visible.each do |e|
      full = path + "/" + e
      next unless File.exist?(full) || File.symlink?(full)
      total_blocks += File.lstat(full).blocks
    end
    puts "total #{total_blocks / 2}"
    visible.each { |e| print_entry(e, path, opts) }
  elsif opts.comma
    parts = []
    visible.each do |e|
      full = path + "/" + e
      next unless File.exist?(full) || File.symlink?(full)
      stat = File.lstat(full)
      name = opts.classify ? e + classify_suffix(stat, e) : e
      name = opts.append_slash && stat.directory? ? e + "/" : name
      parts.push(name)
    end
    puts parts.join(", ")
  elsif opts.one_per_line || opts.long
    visible.each do |e|
      full = path + "/" + e
      next unless File.exist?(full) || File.symlink?(full)
      puts print_entry(e, path, opts)
    end
  else
    names = []
    visible.each do |e|
      full = path + "/" + e
      next unless File.exist?(full) || File.symlink?(full)
      names.push(print_entry(e, path, opts) || e)
    end
    # Multi-column layout (simple: 2 columns)
    puts names.join("  ")
  end

  if opts.recursive
    visible.each do |e|
      full = path + "/" + e
      if File.directory?(full) && !File.symlink?(full) && e != "." && e != ".."
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
non_dirs = []

files.each do |f|
  if !File.exist?(f) && !File.symlink?(f)
    STDERR.puts "ls: cannot access '#{f}': No such file or directory"
    exit_code = 1
    next
  end
  if File.directory?(f) && !opts.directory
    dirs.push(f)
  else
    non_dirs.push(f)
  end
end

# Print non-directories first
non_dirs.each do |f|
  stat = File.lstat(f)
  if opts.long
    name = File.basename(f)
    dir  = File.dirname(f)
    print_entry(name, dir, opts)
  else
    name = File.basename(f)
    suffix = opts.classify ? (stat.directory? ? "/" : (stat.symlink? ? "@" : ((stat.mode & 0o111) != 0 ? "*" : ""))) : (opts.append_slash && stat.directory? ? "/" : "")
    puts name + suffix
  end
end

show_header = files.length > 1 || (dirs.length > 0 && non_dirs.length > 0)

dirs.each do |d|
  puts "" if show_header && (non_dirs.length > 0 || dirs.index(d) > 0)
  list_dir(d, opts, show_header)
end

exit exit_code
