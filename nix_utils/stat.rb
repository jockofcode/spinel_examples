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

def mode_to_octal(mode)
  (mode & 0o7777).to_s(8)
end

MODE_BIT_DEFS = [[0o400, "r"], [0o200, "w"], [0o100, "x"],
                 [0o040, "r"], [0o020, "w"], [0o010, "x"],
                 [0o004, "r"], [0o002, "w"], [0o001, "x"]]

def mode_to_string(mode, ftype)
  type_char = if ftype == "regular file"; "-"
  elsif ftype == "directory"; "d"
  elsif ftype == "symbolic link"; "l"
  elsif ftype == "block special file"; "b"
  elsif ftype == "character special file"; "c"
  elsif ftype == "socket"; "s"
  elsif ftype == "FIFO"; "p"
  else "?"
  end
  bits = ""
  MODE_BIT_DEFS.each do |pair|
    bits += (mode & pair[0]) != 0 ? pair[1] : "-"
  end
  # setuid/setgid/sticky
  bits[2] = (mode & 0o4000) != 0 ? ((mode & 0o100) != 0 ? "s" : "S") : bits[2]
  bits[5] = (mode & 0o2000) != 0 ? ((mode & 0o010) != 0 ? "s" : "S") : bits[5]
  bits[8] = (mode & 0o1000) != 0 ? ((mode & 0o001) != 0 ? "t" : "T") : bits[8]
  type_char + bits
end

def file_type_str(stat)
  if stat.file?; "regular file"
  elsif stat.directory?; "directory"
  elsif stat.symlink?; "symbolic link"
  elsif stat.blockdev?; "block special file"
  elsif stat.chardev?; "character special file"
  elsif stat.socket?; "socket"
  elsif stat.pipe?; "FIFO"
  else "unknown"
  end
end

def time_str(t)
  # Format: 2024-01-15 10:30:45.123456789 +0000
  y  = t.year.to_s.rjust(4, "0")
  mo = t.month.to_s.rjust(2, "0")
  d  = t.day.to_s.rjust(2, "0")
  h  = t.hour.to_s.rjust(2, "0")
  mi = t.min.to_s.rjust(2, "0")
  s  = t.sec.to_s.rjust(2, "0")
  ns = (t.nsec).to_s.rjust(9, "0")
  off = t.utc_offset
  sign = off >= 0 ? "+" : "-"
  off = off.abs
  oh = (off / 3600).to_s.rjust(2, "0")
  om = ((off % 3600) / 60).to_s.rjust(2, "0")
  "#{y}-#{mo}-#{d} #{h}:#{mi}:#{s}.#{ns} #{sign}#{oh}#{om}"
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

def apply_format(fmt, name, st, ftype, opts)
  result = ""
  i = 0
  while i < fmt.length
    if fmt[i] == "%" && i + 1 < fmt.length
      i += 1
      directive = fmt[i]
      val = case directive
      when "n" then name
      when "N" then "'" + name + "'"
      when "s" then st.size.to_s
      when "b" then st.blocks.to_s
      when "B" then "512"
      when "f" then (st.mode & 0xFFFF).to_s(16)
      when "F" then ftype
      when "u" then st.uid.to_s
      when "U" then lookup_name_for_uid(st.uid)
      when "g" then st.gid.to_s
      when "G" then lookup_name_for_gid(st.gid)
      when "i" then st.ino.to_s
      when "h" then st.nlink.to_s
      when "a" then mode_to_octal(st.mode)
      when "A" then mode_to_string(st.mode, ftype)
      when "d" then st.dev.to_s
      when "x" then time_str(st.atime)
      when "y" then time_str(st.mtime)
      when "z" then time_str(st.ctime)
      when "%" then "%"
      else "?" + directive
      end
      result += val
    elsif fmt[i] == "\\" && i + 1 < fmt.length
      i += 1
      result += case fmt[i]
      when "n" then "\n"
      when "t" then "\t"
      when "\\" then "\\"
      else "\\" + fmt[i]
      end
    else
      result += fmt[i]
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
  unless File.exist?(name) || File.symlink?(name)
    STDERR.puts "stat: cannot stat '#{name}': No such file or directory"
    exit_code = 1
    next
  end

  st = opts.dereference ? File.stat(name) : File.lstat(name)
  ftype = file_type_str(st)

  if opts.format
    print apply_format(opts.format, name, st, ftype, opts)
    print "\n" unless opts.format.end_with?("\n")
  elsif opts.terse
    puts "#{name} #{st.size} #{st.blocks} #{(st.mode & 0xFFFF).to_s(16)} #{st.uid} #{st.gid} #{st.dev} #{st.ino} #{st.nlink} #{st.atime.to_i} #{st.mtime.to_i} #{st.ctime.to_i}"
  else
    uname = lookup_name_for_uid(st.uid)
    gname = lookup_name_for_gid(st.gid)
    puts "  File: #{name}"
    puts "  Size: #{st.size}\t\tBlocks: #{st.blocks}\t IO Block: 4096   #{ftype}"
    puts "Device: #{st.dev.to_s(16)}h/#{st.dev}d\tInode: #{st.ino}\t Links: #{st.nlink}"
    puts "Access: (#{mode_to_octal(st.mode)}/#{mode_to_string(st.mode, ftype)})  Uid: (#{st.uid}/#{uname})   Gid: (#{st.gid}/#{gname})"
    puts "Access: #{time_str(st.atime)}"
    puts "Modify: #{time_str(st.mtime)}"
    puts "Change: #{time_str(st.ctime)}"
    puts " Birth: -"
  end
end

exit exit_code
