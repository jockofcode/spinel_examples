# id.rb, print user and group information (GNU id, Spinel port).
#
# Prints the real and effective user and group IDs, plus supplementary groups.
# Without options, prints all info; with options prints one field.
#
# Flags:
#   -u, --user        print only the effective user ID
#   -g, --group       print only the effective group ID
#   -G, --groups      print all group IDs
#   -n, --name        print names instead of numbers (with -u/-g/-G)
#   -r, --real        print real IDs instead of effective (with -u/-g/-G)
#   -z, --zero        NUL-separate output (with -G)
#   --help            usage
#
# Compile: spinel nix_utils/id.rb -o nix_utils/bin/id
# Run:
#   ./bin/id
#   ./bin/id -un

USAGE = "Usage: id [OPTION]... [USER]\n" \
        "Print user and group information for USER (or the current user).\n" \
        "  -u  effective user ID    -g  effective group ID\n" \
        "  -G  all group IDs        -n  print names\n" \
        "  -r  use real IDs         -z  NUL delimiter\n" \
        "  --help"

class IdOptions
  attr_accessor :user_only, :group_only, :groups_only, :use_name, :use_real, :zero
  def initialize
    @user_only   = false
    @group_only  = false
    @groups_only = false
    @use_name    = false
    @use_real    = false
    @zero        = false
  end
end

def parse_argv(argv)
  opts = IdOptions.new
  users = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || (arg.length < 2 || arg[0] != "-")
      users.push(arg)
      index += 1
      next
    end
    if arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "--user"; opts.user_only = true
    elsif arg == "--group"; opts.group_only = true
    elsif arg == "--groups"; opts.groups_only = true
    elsif arg == "--name"; opts.use_name = true
    elsif arg == "--real"; opts.use_real = true
    elsif arg == "--zero"; opts.zero = true
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "u"; opts.user_only = true
        elsif letter == "g"; opts.group_only = true
        elsif letter == "G"; opts.groups_only = true
        elsif letter == "n"; opts.use_name = true
        elsif letter == "r"; opts.use_real = true
        elsif letter == "z"; opts.zero = true
        else
          STDERR.puts "id: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, users]
end

def lookup_name_for_uid(uid)
  if File.exist?("/etc/passwd")
    File.read("/etc/passwd").lines.each do |line|
      parts = ("" + line).chomp.split(":")
      return parts[0] if parts.length >= 3 && parts[2].to_i == uid
    end
  end
  if File.exist?("/usr/bin/dscacheutil")
    raw = "" + `/usr/bin/dscacheutil -q user -a uid #{uid} 2>/dev/null`
    raw.lines.each do |line|
      cline = "" + line.chomp
      return cline[6, cline.length - 6] if cline.start_with?("name: ")
    end
  end
  uid.to_s
end

def lookup_name_for_gid(gid)
  if File.exist?("/etc/group")
    File.read("/etc/group").lines.each do |line|
      parts = ("" + line).chomp.split(":")
      return parts[0] if parts.length >= 3 && parts[2].to_i == gid
    end
  end
  if File.exist?("/usr/bin/dscacheutil")
    raw = "" + `/usr/bin/dscacheutil -q group -a gid #{gid} 2>/dev/null`
    raw.lines.each do |line|
      cline = "" + line.chomp
      return cline[6, cline.length - 6] if cline.start_with?("name: ")
    end
  end
  gid.to_s
end

# Returns uid as int, or -1 if not found.
def lookup_uid_for_name(name)
  if File.exist?("/etc/passwd")
    File.read("/etc/passwd").lines.each do |line|
      parts = ("" + line).chomp.split(":")
      return parts[2].to_i if parts.length >= 3 && parts[0] == name
    end
  end
  if File.exist?("/usr/bin/dscacheutil")
    raw = "" + `/usr/bin/dscacheutil -q user -a name #{name} 2>/dev/null`
    raw.lines.each do |line|
      cline = "" + line.chomp
      return cline[5, cline.length - 5].to_i if cline.start_with?("uid: ")
    end
  end
  -1
end

# Returns gid as int, or 0 if not found.
def lookup_gid_for_name(name)
  if File.exist?("/etc/passwd")
    File.read("/etc/passwd").lines.each do |line|
      parts = ("" + line).chomp.split(":")
      return parts[3].to_i if parts.length >= 4 && parts[0] == name
    end
  end
  if File.exist?("/usr/bin/dscacheutil")
    raw = "" + `/usr/bin/dscacheutil -q user -a name #{name} 2>/dev/null`
    raw.lines.each do |line|
      cline = "" + line.chomp
      return cline[5, cline.length - 5].to_i if cline.start_with?("gid: ")
    end
  end
  0
end

# Returns an int array of all group IDs the user belongs to, starting with
# the primary gid. Falls back to dscacheutil on macOS.
def lookup_groups_for_user(name, primary_gid)
  groups = []
  groups.push(0); groups.pop
  groups.push(primary_gid)
  if File.exist?("/etc/group")
    File.read("/etc/group").lines.each do |line|
      cline = "" + line
      parts = cline.chomp.split(":")
      if parts.length >= 4
        mstr = "" + parts[3]
        mstr.split(",").each do |u|
          if ("" + u) == name
            gnum = parts[2].to_i
            groups.push(gnum) unless groups.include?(gnum)
          end
        end
      end
    end
  end
  # On macOS, /etc/group doesn't contain supplementary groups.
  # Use dscl -search to get explicit memberships (small output, avoids buffer cap),
  # then query each group's gid individually via dscacheutil.
  if File.exist?("/usr/bin/dscl") && File.exist?("/usr/bin/dscacheutil")
    dscl_out = "" + `/usr/bin/dscl . -search /Groups GroupMembership #{name} 2>/dev/null`
    dscl_out.lines.each do |line|
      cline = "" + line.chomp
      next if cline == ""
      ch0 = cline[0]
      next if ch0 == " " || ch0 == "\t" || ch0 == ")"
      gname = ""
      ci = 0
      while ci < cline.length && cline[ci] != " " && cline[ci] != "\t"
        gname = gname + cline[ci]
        ci += 1
      end
      if gname != ""
        gout = "" + `/usr/bin/dscacheutil -q group -a name #{gname} 2>/dev/null`
        gout.lines.each do |gl|
          gcline = "" + gl.chomp
          if gcline.start_with?("gid: ")
            gnum = gcline[5, gcline.length - 5].to_i
            groups.push(gnum) unless groups.include?(gnum)
          end
        end
      end
    end
  end
  groups
end

opts, users = parse_argv(ARGV)

# users[0] on an empty PolyArray returns 0 (not nil) in Spinel, so check
# by length and always coerce to const char* with "" + .
if users.length == 0
  cu = ENV["USER"] || ENV["LOGNAME"] || ENV["USERNAME"] || ""
  target_user = "" + cu
else
  target_user = "" + users[0]
end

uid = lookup_uid_for_name(target_user)
if uid < 0
  STDERR.puts "id: '#{target_user}': no such user"
  exit 1
end
euid = uid
gid  = lookup_gid_for_name(target_user)
egid = gid
groups = lookup_groups_for_user(target_user, gid)

use_uid  = opts.use_real ? uid  : euid
use_gid  = opts.use_real ? gid  : egid

term = opts.zero ? "\0" : "\n"

if opts.user_only
  val = opts.use_name ? lookup_name_for_uid(use_uid) : use_uid.to_s
  STDOUT.write(val + term)
elsif opts.group_only
  val = opts.use_name ? lookup_name_for_gid(use_gid) : use_gid.to_s
  STDOUT.write(val + term)
elsif opts.groups_only
  parts = []
  groups.each do |g|
    parts.push(opts.use_name ? lookup_name_for_gid(g) : g.to_s)
  end
  sep = opts.zero ? "\0" : " "
  STDOUT.write(parts.join(sep) + term)
else
  # Default: uid=N(name) gid=N(name) groups=N(name),...
  uname = lookup_name_for_uid(uid)
  euname = lookup_name_for_uid(euid)
  gname = lookup_name_for_gid(gid)
  egname = lookup_name_for_gid(egid)

  out = "uid=#{uid}(#{uname}) gid=#{gid}(#{gname})"
  if euid != uid
    out += " euid=#{euid}(#{euname})"
  end
  if egid != gid
    out += " egid=#{egid}(#{egname})"
  end
  grp_parts = []
  groups.each do |g|
    grp_parts.push("#{g}(#{lookup_name_for_gid(g)})")
  end
  out += " groups=#{grp_parts.join(",")}"
  puts out
end
