# stat.rb, display file or filesystem status (GNU stat, Spinel port).
#
# Prints detailed status information about each FILE.
#
# Flags:
#   -f, --file-system   display filesystem status instead of file status
#   -c FORMAT, --format=FORMAT  use FORMAT instead of default; FORMAT uses %
#      directives: %n name, %s size, %b blocks, %B block size, %f raw mode hex,
#      %F file type, %u UID, %U user name, %g GID, %G group name,
#      %i inode, %h hard links, %a access rights in octal, %A access rights,
#      %x access time, %y mod time, %z change time, %N quoted name,
#      %d device number, %l link count for symlinks
#   -t, --terse         print the information in terse form
#   -L, --dereference   follow symlinks
#   --help              usage
#
# Compile: spinel nix_utils/stat.rb -o nix_utils/bin/stat
# Run:
#   ./bin/stat file.txt
#   ./bin/stat -c '%n %s' file.txt

USAGE = "Usage: stat [OPTION]... FILE...\n" \
        "Display file or filesystem status.\n" \
        "  -f  filesystem status   -L  follow symlinks\n" \
        "  -c FORMAT   use FORMAT (%-directives: %n %s %f %F %u %g %i %h %a %A %x %y %z)\n" \
        "  -t  terse output\n" \
        "  --help"

class StatOptions
  attr_accessor :filesystem, :format, :terse, :dereference
  def initialize
    @filesystem  = false
    @format      = nil
    @terse       = false
    @dereference = false
  end
end

def parse_argv(argv)
  opts = StatOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg.length < 2 || arg[0] != "-"
      files.push(arg)
      index += 1
      next
    end
    if arg == "--"; options_done = true; index += 1; next; end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "-f" || arg == "--file-system"; opts.filesystem = true
    elsif arg == "-t" || arg == "--terse"; opts.terse = true
    elsif arg == "-L" || arg == "--dereference"; opts.dereference = true
    elsif arg == "-c" || arg == "--format"
      index += 1; opts.format = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-c"
      opts.format = arg[2, arg.length - 2]
    elsif arg.length > 9 && arg[0, 9] == "--format="
      opts.format = arg[9, arg.length - 9]
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "f"; opts.filesystem = true
        elsif letter == "t"; opts.terse = true
        elsif letter == "L"; opts.dereference = true
        else
          STDERR.puts "stat: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

# File.stat / File.lstat are not in the Spinel runtime.
# StatInfo wraps data from /usr/bin/stat -f on macOS.

class StatInfo
  attr_accessor :mode_str, :mode_hex, :nlinks, :uid, :gid, :size, :blocks, :ino, :dev, :uname, :gname, :atime_ep, :mtime_ep, :ctime_ep, :ftype
  def initialize
    @mode_str  = "-rw-r--r--"
    @mode_hex  = "81a4"
    @nlinks    = 1
    @uid       = 0
    @gid       = 0
    @size      = 0
    @blocks    = 0
    @ino       = 0
    @dev       = 0
    @uname     = "?"
    @gname     = "?"
    @atime_ep  = "0"
    @mtime_ep  = "0"
    @ctime_ep  = "0"
    @ftype     = "regular file"
  end
end

def get_stat_info(path, follow)
  info = StatInfo.new
  flag = follow ? "-L " : ""
  raw = "" + `/usr/bin/stat #{flag}-f '%Sp %l %u %g %z %b %i %d %Xp %Su %Sg %a %m %c' '#{path}' 2>/dev/null`
  craw = "" + raw.chomp
  parts = craw.split(" ")
  if parts.length >= 14
    info.mode_str = "" + parts[0]
    info.nlinks   = parts[1].to_i
    info.uid      = parts[2].to_i
    info.gid      = parts[3].to_i
    info.size     = parts[4].to_i
    info.blocks   = parts[5].to_i
    info.ino      = parts[6].to_i
    info.dev      = parts[7].to_i
    info.mode_hex = "" + parts[8]
    info.uname    = "" + parts[9]
    info.gname    = "" + parts[10]
    info.atime_ep = "" + parts[11]
    info.mtime_ep = "" + parts[12]
    info.ctime_ep = "" + parts[13]
  end
  tc = info.mode_str.length > 0 ? info.mode_str[0] : "-"
  info.ftype = if tc == "d"; "directory"
  elsif tc == "l"; "symbolic link"
  elsif tc == "b"; "block special file"
  elsif tc == "c"; "character special file"
  elsif tc == "p"; "FIFO"
  elsif tc == "s"; "socket"
  else "regular file"
  end
  info
end

def mode_to_octal_from_hex(hex_str)
  (hex_str.to_i(16) & 0o7777).to_s(8)
end

def mode_to_string_from_int(mode)
  type_char = if (mode & 0o170000) == 0o040000; "d"
  elsif (mode & 0o170000) == 0o120000; "l"
  elsif (mode & 0o170000) == 0o060000; "b"
  elsif (mode & 0o170000) == 0o020000; "c"
  elsif (mode & 0o170000) == 0o010000; "p"
  elsif (mode & 0o170000) == 0o140000; "s"
  else "-"
  end
  r1 = (mode & 0o400) != 0 ? "r" : "-"
  w1 = (mode & 0o200) != 0 ? "w" : "-"
  x1 = (mode & 0o4000) != 0 ? ((mode & 0o100) != 0 ? "s" : "S") : ((mode & 0o100) != 0 ? "x" : "-")
  r2 = (mode & 0o040) != 0 ? "r" : "-"
  w2 = (mode & 0o020) != 0 ? "w" : "-"
  x2 = (mode & 0o2000) != 0 ? ((mode & 0o010) != 0 ? "s" : "S") : ((mode & 0o010) != 0 ? "x" : "-")
  r3 = (mode & 0o004) != 0 ? "r" : "-"
  w3 = (mode & 0o002) != 0 ? "w" : "-"
  x3 = (mode & 0o1000) != 0 ? ((mode & 0o001) != 0 ? "t" : "T") : ((mode & 0o001) != 0 ? "x" : "-")
  type_char + r1 + w1 + x1 + r2 + w2 + x2 + r3 + w3 + x3
end

def time_str_from_epoch(epoch_s)
  raw = "" + `/bin/date -r #{epoch_s} '+%Y-%m-%d %H:%M:%S.000000000 %z' 2>/dev/null`
  "" + raw.chomp
end

def apply_format(fmt, cname, info)
  result = ""
  i = 0
  mode_int = info.mode_hex.to_i(16)
  while i < fmt.length
    if fmt[i] == "%" && i + 1 < fmt.length
      i += 1
      d = fmt[i]
      val = if d == "n"; cname
      elsif d == "N"; "'" + cname + "'"
      elsif d == "s"; info.size.to_s
      elsif d == "b"; info.blocks.to_s
      elsif d == "B"; "512"
      elsif d == "f"; info.mode_hex
      elsif d == "F"; info.ftype
      elsif d == "u"; info.uid.to_s
      elsif d == "U"; info.uname
      elsif d == "g"; info.gid.to_s
      elsif d == "G"; info.gname
      elsif d == "i"; info.ino.to_s
      elsif d == "h"; info.nlinks.to_s
      elsif d == "a"; mode_to_octal_from_hex(info.mode_hex)
      elsif d == "A"; mode_to_string_from_int(mode_int)
      elsif d == "d"; info.dev.to_s
      elsif d == "x"; time_str_from_epoch(info.atime_ep)
      elsif d == "y"; time_str_from_epoch(info.mtime_ep)
      elsif d == "z"; time_str_from_epoch(info.ctime_ep)
      elsif d == "%"; "%"
      else "?" + d
      end
      result = result + val
    elsif fmt[i] == "\\" && i + 1 < fmt.length
      i += 1
      ec = if fmt[i] == "n"; "\n"
      elsif fmt[i] == "t"; "\t"
      elsif fmt[i] == "\\"; "\\"
      else "\\" + fmt[i]
      end
      result = result + ec
    else
      result = result + fmt[i]
    end
    i += 1
  end
  result
end

opts, files = parse_argv(ARGV)

if files.empty?
  STDERR.puts "stat: missing operand"
  exit 1
end

exit_code = 0
files.each do |name|
  cname = "" + name
  unless File.exist?(cname) || File.symlink?(cname)
    STDERR.puts "stat: cannot stat '#{cname}': No such file or directory"
    exit_code = 1
    next
  end

  info = get_stat_info(cname, opts.dereference)

  if opts.format
    cfmt = "" + opts.format
    out = apply_format(cfmt, cname, info)
    STDOUT.write(out)
    STDOUT.write("\n") unless cfmt.end_with?("\n")
  elsif opts.terse
    puts "" + cname + " " + info.size.to_s + " " + info.blocks.to_s + " " + info.mode_hex + " " + info.uid.to_s + " " + info.gid.to_s + " " + info.dev.to_s + " " + info.ino.to_s + " " + info.nlinks.to_s + " " + info.atime_ep + " " + info.mtime_ep + " " + info.ctime_ep
  else
    mode_int = info.mode_hex.to_i(16)
    octal = mode_to_octal_from_hex(info.mode_hex)
    mode_full = mode_to_string_from_int(mode_int)
    puts "  File: " + cname
    puts "  Size: " + info.size.to_s + "\t\tBlocks: " + info.blocks.to_s + "\t IO Block: 4096   " + info.ftype
    puts "Device: " + info.dev.to_s(16) + "h/" + info.dev.to_s + "d\tInode: " + info.ino.to_s + "\t Links: " + info.nlinks.to_s
    puts "Access: (" + octal + "/" + mode_full + ")  Uid: (" + info.uid.to_s + "/" + info.uname + ")   Gid: (" + info.gid.to_s + "/" + info.gname + ")"
    puts "Access: " + time_str_from_epoch(info.atime_ep)
    puts "Modify: " + time_str_from_epoch(info.mtime_ep)
    puts "Change: " + time_str_from_epoch(info.ctime_ep)
    puts " Birth: -"
  end
end

exit exit_code
