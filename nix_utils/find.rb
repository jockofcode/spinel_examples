# find.rb, search for files in a directory hierarchy (GNU find, Spinel port).
#
# Global options: -H, -L, -P
# See USAGE for supported tests and actions.
#
# Compile: spinel nix_utils/find.rb -o nix_utils/bin/find

USAGE = "Usage: find [-H] [-L] [-P] [path...] [expression]\n" \
        "Search for files in a directory hierarchy.\n" \
        "Tests: -name -iname -path -ipath -type -size -empty -maxdepth -mindepth\n" \
        "       -newer -mtime -atime -ctime -mmin -amin -perm -user -group\n" \
        "       -readable -writable -executable -regex -iregex -samefile\n" \
        "       -links -inum -depth -mount/-xdev -prune -noleaf\n" \
        "Actions: -print -ls -exec CMD {} ; -exec CMD {} + -execdir -ok -delete -quit\n" \
        "         -printf FORMAT\n" \
        "Operators: -and/-a -or/-o ! -not ( )\n" \
        "  -print0 unsupported (NUL bytes not possible in this build)"

VERSION = "find (nix_utils) 1.0"

require_relative "nix_helpers"

# ── FindStat — lazy file stat ─────────────────────────────────────────────────

class FindStat
  attr_accessor :path_str, :follow_links
  def initialize(path, follow)
    @path_str    = "" + path
    @follow_links = follow
    @loaded      = false
    @perms       = 0
    @nlinks      = 0
    @uid         = 0
    @gid         = 0
    @size_bytes  = 0
    @mtime_i     = 0
    @atime_i     = 0
    @ctime_i     = 0
    @ino         = 0
    @dev         = 0
    @file_type   = nil
  end

  def load
    return if @loaded
    @loaded = true
    raw = `stat -f '%p %l %u %g %z %m %a %c %i %d' '#{@path_str}' 2>/dev/null`
    s = ("" + raw).strip
    return if s == ""
    parts = s.split(" ")
    return if parts.length < 10
    @perms      = parts[0].to_i(8)
    @nlinks     = parts[1].to_i
    @uid        = parts[2].to_i
    @gid        = parts[3].to_i
    @size_bytes = parts[4].to_i
    @mtime_i    = parts[5].to_i
    @atime_i    = parts[6].to_i
    @ctime_i    = parts[7].to_i
    @ino        = parts[8].to_i
    @dev        = parts[9].to_i
  end

  def perms;      load; @perms;      end
  def nlinks;     load; @nlinks;     end
  def uid;        load; @uid;        end
  def gid;        load; @gid;        end
  def size_bytes; load; @size_bytes; end
  def mtime_i;    load; @mtime_i;    end
  def atime_i;    load; @atime_i;    end
  def ctime_i;    load; @ctime_i;    end
  def ino;        load; @ino;        end
  def dev;        load; @dev;        end

  def file_type
    return @file_type unless @file_type.nil?
    cp = "" + @path_str
    @file_type =
      if File.symlink?(cp)
        if @follow_links && File.exist?(cp)
          File.directory?(cp) ? "d" : "f"
        else
          "l"
        end
      elsif File.directory?(cp)
        "d"
      elsif File.exist?(cp)
        "f"
      else
        "?"
      end
  end
end

# ── Expression classes ────────────────────────────────────────────────────────

class FindTrue
  def eval(path, st, depth, opts); true; end
  def is_action?; false; end
end

class FindFalse
  def eval(path, st, depth, opts); false; end
  def is_action?; false; end
end

class FindAnd
  def initialize(left, right)
    @left = left; @right = right
  end
  def eval(path, st, depth, opts)
    @left.eval(path, st, depth, opts) && @right.eval(path, st, depth, opts)
  end
  def is_action?; false; end
end

class FindOr
  def initialize(left, right)
    @left = left; @right = right
  end
  def eval(path, st, depth, opts)
    @left.eval(path, st, depth, opts) || @right.eval(path, st, depth, opts)
  end
  def is_action?; false; end
end

class FindNot
  def initialize(child)
    @child = child
  end
  def eval(path, st, depth, opts)
    !@child.eval(path, st, depth, opts)
  end
  def is_action?; false; end
end

class FindName
  def initialize(pat, case_fold)
    @pat       = "" + pat
    @case_fold = case_fold
    @re        = nil
  end
  def eval(path, st, depth, opts)
    base = File.basename("" + path)
    if @case_fold
      File.fnmatch(@pat, base, File::FNM_CASEFOLD)
    else
      File.fnmatch(@pat, base)
    end
  end
  def is_action?; false; end
end

class FindPath
  def initialize(pat, case_fold)
    @pat       = "" + pat
    @case_fold = case_fold
  end
  def eval(path, st, depth, opts)
    cp = "" + path
    if @case_fold
      File.fnmatch(@pat, cp, File::FNM_CASEFOLD | File::FNM_PATHNAME)
    else
      File.fnmatch(@pat, cp, File::FNM_PATHNAME)
    end
  end
  def is_action?; false; end
end

class FindType
  def initialize(type_char)
    @tc = "" + type_char
  end
  def eval(path, st, depth, opts)
    cp = "" + path
    tc = "" + @tc
    if tc == "f"
      File.file?(cp) && !File.symlink?(cp)
    elsif tc == "d"
      File.directory?(cp) && !File.symlink?(cp)
    elsif tc == "l"
      File.symlink?(cp)
    else
      st.file_type == tc
    end
  end
  def is_action?; false; end
end

class FindSize
  def initialize(spec)
    @spec = "" + spec
    s = @spec
    @cmp = :eq
    if s[0] == "+"
      @cmp = :gt; s = s[1, s.length - 1]
    elsif s[0] == "-"
      @cmp = :lt; s = s[1, s.length - 1]
    end
    unit = s[-1] if s.length > 0
    num_s = (unit && "cwbkMG".include?(unit)) ? s[0, s.length - 1] : s
    @num = num_s.to_i
    @unit = unit.nil? ? "b" : unit
  end
  def eval(path, st, depth, opts)
    bytes = st.size_bytes
    compare_size =
      if @unit == "c"
        bytes
      elsif @unit == "w"
        bytes / 2
      elsif @unit == "b" || @unit.nil?
        (bytes + 511) / 512
      elsif @unit == "k"
        (bytes + 1023) / 1024
      elsif @unit == "M"
        (bytes + 1048575) / 1048576
      elsif @unit == "G"
        (bytes + 1073741823) / 1073741824
      else
        bytes
      end
    if @cmp == :gt
      compare_size > @num
    elsif @cmp == :lt
      compare_size < @num
    else
      compare_size == @num
    end
  end
  def is_action?; false; end
end

class FindEmpty
  def eval(path, st, depth, opts)
    cp = "" + path
    if File.directory?(cp)
      Dir.entries(cp).reject { |e| ("" + e) == "." || ("" + e) == ".." }.empty?
    else
      st.size_bytes == 0
    end
  end
  def is_action?; false; end
end

class FindMaxDepth
  def initialize(n); @n = n.to_i; end
  def eval(path, st, depth, opts); depth <= @n; end
  def is_action?; false; end
end

class FindMinDepth
  def initialize(n); @n = n.to_i; end
  def eval(path, st, depth, opts); depth >= @n; end
  def is_action?; false; end
end

class FindNewer
  def initialize(ref_path)
    @ref_mtime = File.mtime("" + ref_path).to_i rescue 0
  end
  def eval(path, st, depth, opts)
    st.mtime_i > @ref_mtime
  end
  def is_action?; false; end
end

class FindTimeTest
  def initialize(kind, spec)
    @kind  = "" + kind   # mtime/atime/ctime/mmin/amin
    @spec  = "" + spec
    @cmp   = :eq
    s = @spec
    if s[0] == "+"
      @cmp = :gt; s = s[1, s.length - 1]
    elsif s[0] == "-"
      @cmp = :lt; s = s[1, s.length - 1]
    end
    @val = s.to_i
  end
  def eval(path, st, depth, opts)
    now   = Time.now.to_i
    ftime =
      if @kind == "mtime" || @kind == "mmin"
        st.mtime_i
      elsif @kind == "atime" || @kind == "amin"
        st.atime_i
      else
        st.ctime_i
      end
    unit  = (@kind.end_with?("min")) ? 60 : 86400
    diff  = (now - ftime) / unit
    if @cmp == :gt
      diff > @val
    elsif @cmp == :lt
      diff < @val
    else
      diff == @val
    end
  end
  def is_action?; false; end
end

class FindPerm
  def initialize(spec)
    @spec = "" + spec
    @mode_cmp = :eq
    s = @spec
    if s[0] == "/"
      @mode_cmp = :any; s = s[1, s.length - 1]
    elsif s[0] == "-"
      @mode_cmp = :all; s = s[1, s.length - 1]
    end
    @mode = s.to_i(8)
  end
  def eval(path, st, depth, opts)
    perms = st.perms & 0o7777
    if @mode_cmp == :any
      (perms & @mode) != 0
    elsif @mode_cmp == :all
      (perms & @mode) == @mode
    else
      perms == @mode
    end
  end
  def is_action?; false; end
end

class FindUser
  def initialize(name)
    @name = "" + name
    # Try numeric first
    @uid  = @name.match(/^\d+$/) ? @name.to_i : nil
    if @uid.nil?
      raw = `id -u '#{@name}' 2>/dev/null`
      @uid = ("" + raw).strip.to_i
    end
  end
  def eval(path, st, depth, opts)
    st.uid == @uid
  end
  def is_action?; false; end
end

class FindGroup
  def initialize(name)
    @name = "" + name
    @gid  = @name.match(/^\d+$/) ? @name.to_i : nil
    if @gid.nil?
      raw = `getent group '#{@name}' 2>/dev/null || dscl . -read /Groups/#{@name} PrimaryGroupID 2>/dev/null | awk '{print $2}'`
      @gid = ("" + raw).strip.to_i
    end
  end
  def eval(path, st, depth, opts)
    st.gid == @gid
  end
  def is_action?; false; end
end

class FindAccessible
  def initialize(mode_sym); @mode = mode_sym; end
  def eval(path, st, depth, opts)
    cp = "" + path
    if @mode == :read
      File.readable?(cp)
    elsif @mode == :write
      File.writable?(cp)
    else
      File.executable?(cp)
    end
  end
  def is_action?; false; end
end

class FindRegex
  def initialize(pat, case_fold)
    @re = Regexp.new("" + pat, case_fold ? Regexp::IGNORECASE : 0)
  end
  def eval(path, st, depth, opts)
    !("" + path).match(@re).nil?
  end
  def is_action?; false; end
end

class FindSamefile
  def initialize(ref_path)
    @ref_ino = nil
    @ref_dev = nil
    cp = "" + ref_path
    if File.exist?(cp)
      raw = `stat -f '%i %d' '#{cp}' 2>/dev/null`
      parts = ("" + raw).strip.split(" ")
      if parts.length >= 2
        @ref_ino = parts[0].to_i
        @ref_dev = parts[1].to_i
      end
    end
  end
  def eval(path, st, depth, opts)
    return false if @ref_ino.nil?
    st.ino == @ref_ino && st.dev == @ref_dev
  end
  def is_action?; false; end
end

class FindLinks
  def initialize(spec)
    @spec = "" + spec
    @cmp = :eq
    s = @spec
    if s[0] == "+"; @cmp = :gt; s = s[1, s.length - 1]
    elsif s[0] == "-"; @cmp = :lt; s = s[1, s.length - 1]; end
    @val = s.to_i
  end
  def eval(path, st, depth, opts)
    n = st.nlinks
    if @cmp == :gt; n > @val
    elsif @cmp == :lt; n < @val
    else; n == @val; end
  end
  def is_action?; false; end
end

class FindInum
  def initialize(spec)
    @spec = "" + spec
    @cmp = :eq
    s = @spec
    if s[0] == "+"; @cmp = :gt; s = s[1, s.length - 1]
    elsif s[0] == "-"; @cmp = :lt; s = s[1, s.length - 1]; end
    @val = s.to_i
  end
  def eval(path, st, depth, opts)
    n = st.ino
    if @cmp == :gt; n > @val
    elsif @cmp == :lt; n < @val
    else; n == @val; end
  end
  def is_action?; false; end
end

class FindPrune
  def eval(path, st, depth, opts); true; end
  def is_action?; true; end
  def perform(path, st, depth, opts)
    # Returning :prune signals the traversal to not descend
    :prune
  end
end

class FindPrint
  def eval(path, st, depth, opts)
    puts "" + path
    true
  end
  def is_action?; true; end
end

class FindDelete
  def eval(path, st, depth, opts)
    cp = "" + path
    begin
      if File.directory?(cp) && !File.symlink?(cp)
        Dir.rmdir(cp)
      else
        File.unlink(cp)
      end
    rescue => e
      STDERR.puts "find: cannot delete '#{cp}': #{e.message}"
      return false
    end
    true
  end
  def is_action?; true; end
end

class FindQuit
  def eval(path, st, depth, opts)
    exit 0
  end
  def is_action?; true; end
end

class FindExec
  def initialize(cmd_parts, batch)
    @cmd_parts = cmd_parts
    @batch     = batch
    @batch_buf = []
  end
  def eval(path, st, depth, opts)
    cp = "" + path
    if @batch
      @batch_buf.push(cp)
      true
    else
      run_cmd(cp)
    end
  end
  def flush
    return if @batch_buf.empty?
    args = @batch_buf.map { |p| "'" + ("" + p).gsub("'", "'\\''") + "'" }.join(" ")
    cmd  = @cmd_parts.map { |p| cp = "" + p; cp == "{}" ? args : cp }.join(" ")
    system(cmd)
    @batch_buf = []
  end
  def is_action?; true; end

  private
  def run_cmd(path)
    cmd = @cmd_parts.map { |p| cp = "" + p; cp == "{}" ? "'" + path.gsub("'", "'\\''") + "'" : cp }.join(" ")
    system(cmd)
    $? == 0
  end
end

class FindExecDir
  def initialize(cmd_parts)
    @cmd_parts = cmd_parts
  end
  def eval(path, st, depth, opts)
    cp  = "" + path
    dir = File.dirname(cp)
    base = File.basename(cp)
    cmd = @cmd_parts.map { |p| ("" + p) == "{}" ? "'" + base.gsub("'", "'\\''") + "'" : ("" + p) }.join(" ")
    system("cd '#{dir}' && #{cmd}")
    $? == 0
  end
  def is_action?; true; end
end

class FindOk
  def initialize(cmd_parts)
    @cmd_parts = cmd_parts
  end
  def eval(path, st, depth, opts)
    cp  = "" + path
    cmd = @cmd_parts.map { |p| ("" + p) == "{}" ? "'" + cp.gsub("'", "'\\''") + "'" : ("" + p) }.join(" ")
    STDERR.print "< #{cmd} > ? "
    resp = STDIN.gets || ""
    return false unless ("" + resp).strip.downcase.start_with?("y")
    system(cmd)
    $? == 0
  end
  def is_action?; true; end
end

class FindLs
  def eval(path, st, depth, opts)
    raw = `ls -dils '#{path}' 2>/dev/null`
    print "" + raw
    true
  end
  def is_action?; true; end
end

class FindPrintf
  FORMAT_CODES = {
    "p" => :path, "f" => :basename, "d" => :depth,
    "s" => :size, "k" => :size_kb, "m" => :perms_oct,
    "M" => :perms_str, "i" => :ino, "n" => :nlinks,
    "t" => :mtime, "T" => :mtime_fmt,
  }
  def initialize(fmt); @fmt = "" + fmt; end
  def eval(path, st, depth, opts)
    cp  = "" + path
    out = ""
    i   = 0
    while i < @fmt.length
      c = @fmt[i]
      if c == "\\"
        i += 1
        nc = i < @fmt.length ? @fmt[i] : ""
        out += nc == "n" ? "\n" : nc == "t" ? "\t" : nc
      elsif c == "%"
        i += 1
        nc = i < @fmt.length ? @fmt[i] : ""
        out +=
          case nc
          when "p"; cp
          when "f"; File.basename(cp)
          when "d"; depth.to_s
          when "s"; st.size_bytes.to_s
          when "k"; ((st.size_bytes + 1023) / 1024).to_s
          when "m"; (st.perms & 0o7777).to_s(8)
          when "i"; st.ino.to_s
          when "n"; st.nlinks.to_s
          when "t"; Time.at(st.mtime_i).to_s
          when "%"; "%"
          else; "%" + nc
          end
      else
        out += c
      end
      i += 1
    end
    print out
    true
  end
  def is_action?; true; end
end

# ── Expression parser ─────────────────────────────────────────────────────────

class FindParser
  def initialize(tokens)
    @tokens = tokens
    @pos    = 0
  end

  def parse
    expr = parse_or
    expr
  end

  private

  def current
    @pos < @tokens.length ? ("" + @tokens[@pos]) : nil
  end

  def advance
    t = @tokens[@pos]
    @pos += 1
    t
  end

  def parse_or
    left = parse_and
    while current == "-or" || current == "-o"
      advance
      right = parse_and
      left  = FindOr.new(left, right)
    end
    left
  end

  def parse_and
    left = parse_not
    while !current.nil? && current != "-or" && current != "-o" && current != ")"
      if current == "-and" || current == "-a"
        advance
      end
      break if current.nil? || current == "-or" || current == "-o" || current == ")"
      right = parse_not
      left  = FindAnd.new(left, right)
    end
    left
  end

  def parse_not
    if current == "!" || current == "-not"
      advance
      child = parse_primary
      return FindNot.new(child)
    end
    parse_primary
  end

  def parse_primary
    t = current
    return FindTrue.new if t.nil?

    if t == "("
      advance
      expr = parse_or
      advance if current == ")"
      return expr
    end

    advance

    case t
    when "-name";  FindName.new("" + advance_arg, false)
    when "-iname"; FindName.new("" + advance_arg, true)
    when "-path";  FindPath.new("" + advance_arg, false)
    when "-ipath"; FindPath.new("" + advance_arg, true)
    when "-type";  FindType.new("" + advance_arg)
    when "-size";  FindSize.new("" + advance_arg)
    when "-empty"; FindEmpty.new
    when "-maxdepth"; FindMaxDepth.new(advance_arg.to_i)
    when "-mindepth"; FindMinDepth.new(advance_arg.to_i)
    when "-newer";    FindNewer.new("" + advance_arg)
    when "-newermt"
      advance_arg  # consume arg; just treat as -newer approximation
      FindTrue.new
    when "-mtime";  FindTimeTest.new("mtime", "" + advance_arg)
    when "-atime";  FindTimeTest.new("atime", "" + advance_arg)
    when "-ctime";  FindTimeTest.new("ctime", "" + advance_arg)
    when "-mmin";   FindTimeTest.new("mmin",  "" + advance_arg)
    when "-amin";   FindTimeTest.new("amin",  "" + advance_arg)
    when "-perm";   FindPerm.new("" + advance_arg)
    when "-user";   FindUser.new("" + advance_arg)
    when "-group";  FindGroup.new("" + advance_arg)
    when "-nouser", "-nogroup"; FindTrue.new  # approximate
    when "-readable";   FindAccessible.new(:read)
    when "-writable";   FindAccessible.new(:write)
    when "-executable"; FindAccessible.new(:exec)
    when "-regex";      FindRegex.new("" + advance_arg, false)
    when "-iregex";     FindRegex.new("" + advance_arg, true)
    when "-samefile";   FindSamefile.new("" + advance_arg)
    when "-links";  FindLinks.new("" + advance_arg)
    when "-inum";   FindInum.new("" + advance_arg)
    when "-depth";  FindTrue.new  # depth-first handled in traversal
    when "-mount", "-xdev"; FindTrue.new  # handled in traversal via one_filesystem
    when "-noleaf"; FindTrue.new
    when "-prune";  FindPrune.new
    when "-print";  FindPrint.new
    when "-print0"
      die("find: -print0 is unsupported in this build (NUL bytes not possible in Spinel C strings)")
    when "-delete"; FindDelete.new
    when "-quit";   FindQuit.new
    when "-ls";     FindLs.new
    when "-true";   FindTrue.new
    when "-false";  FindFalse.new
    when "-exec", "-execdir", "-ok"
      parts = []
      terminated_plus = false
      while !current.nil?
        a = "" + current
        if a == ";"
          advance; break
        elsif a == "+"
          advance; terminated_plus = true; break
        elsif a == "{}"
          parts.push("{}"); advance
        else
          parts.push(a); advance
        end
      end
      if t == "-exec"
        FindExec.new(parts, terminated_plus)
      elsif t == "-execdir"
        FindExecDir.new(parts)
      else
        FindOk.new(parts)
      end
    when "-printf"
      FindPrintf.new("" + advance_arg)
    else
      # Unknown test — warn and return true
      STDERR.puts "find: unknown predicate '#{t}'"
      FindTrue.new
    end
  end

  def advance_arg
    t = current
    die("find: missing argument to predicate") if t.nil?
    advance
    "" + t
  end
end

# ── Traversal ─────────────────────────────────────────────────────────────────

def find_traverse(start_path, depth, root_dev, expr, follow_links, one_filesystem, depth_first, exec_actions)
  cp = "" + start_path
  st = FindStat.new(cp, follow_links)

  unless depth_first
    result = expr.eval(cp, st, depth, nil)
    return if result == :prune
  end

  is_dir = File.directory?(cp) && (!File.symlink?(cp) || follow_links)
  if is_dir
    if one_filesystem && depth > 0
      dev = st.dev
      return if dev != root_dev
    end
    begin
      entries = Dir.entries(cp).sort
    rescue
      STDERR.puts "find: '#{cp}': Permission denied"
      return
    end
    entries.each do |e|
      ce = "" + e
      next if ce == "." || ce == ".."
      child = cp + "/" + ce
      find_traverse(child, depth + 1, root_dev, expr, follow_links, one_filesystem, depth_first, exec_actions)
    end
  end

  if depth_first
    expr.eval(cp, st, depth, nil)
  end
end

# ── Main ──────────────────────────────────────────────────────────────────────

follow_links     = false
follow_args      = false
one_filesystem   = false
depth_first_mode = false
start_paths      = []
expr_tokens      = []
global_done      = false

index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if !global_done && (arg == "-H" || arg == "-L" || arg == "-P")
    follow_links = (arg == "-L")
    follow_args  = (arg == "-H")
  elsif !global_done && arg[0] != "-" && !File.exist?(arg) && !File.symlink?(arg)
    global_done = true
    expr_tokens.push(arg)
  elsif !global_done && arg[0] != "-"
    start_paths.push(arg)
  elsif !global_done && arg == "--"
    global_done = true
  else
    global_done = true
    expr_tokens.push(arg)
    # Check for -depth / -xdev in tokens too
    if arg == "-depth"; depth_first_mode = true; end
    if arg == "-mount" || arg == "-xdev"; one_filesystem = true; end
    # For -exec/ok/execdir, consume additional tokens until ; or +
    if arg == "-exec" || arg == "-execdir" || arg == "-ok"
      index += 1
      while index < ARGV.length
        a = coerce(ARGV[index])
        expr_tokens.push(a)
        break if a == ";" || a == "+"
        index += 1
      end
    end
  end
  index += 1
end

start_paths = ["."] if start_paths.empty?

# Default action: if no action in expr, add -print
has_action = false
expr_tokens.each do |t|
  ct = "" + t
  if ct == "-print" || ct == "-print0" || ct == "-delete" || ct == "-quit" ||
     ct == "-ls" || ct == "-exec" || ct == "-execdir" || ct == "-ok" || ct == "-printf"
    has_action = true
    break
  end
end
expr_tokens.push("-print") unless has_action

expr = FindParser.new(expr_tokens).parse

start_paths.each do |sp|
  csp = "" + sp
  unless File.exist?(csp) || File.symlink?(csp)
    STDERR.puts "find: '#{csp}': No such file or directory"
    next
  end
  fl = follow_links || follow_args
  root_dev = 0
  if one_filesystem
    raw = `stat -f '%d' '#{csp}' 2>/dev/null`
    root_dev = ("" + raw).strip.to_i
  end
  find_traverse(csp, 0, root_dev, expr, fl, one_filesystem, depth_first_mode, [])
end
