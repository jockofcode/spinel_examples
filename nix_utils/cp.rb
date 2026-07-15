# cp.rb, copy files and directories (GNU cp, Spinel port).
#
# Copies each SOURCE to DEST, or copies multiple SOURCEs into DEST directory.
#
# Flags:
#   -r, -R, --recursive  copy directories recursively
#   -f, --force          do not prompt before overwriting
#   -i, --interactive    prompt before overwriting
#   -n, --no-clobber     do not overwrite existing files
#   -p, --preserve       preserve timestamps and permissions
#   -v, --verbose        explain what is being done
#   -l, --link           hard-link instead of copying files
#   -s, --symbolic-link  make symbolic links instead of copying
#   -a, --archive        same as -dpR
#   -u, --update         copy only when SOURCE is newer than DEST or DEST missing
#   -t DIR               copy into DIR instead of last argument being the dest
#   --help               usage
#
# Compile: spinel nix_utils/cp.rb -o nix_utils/bin/cp
# Run:
#   ./bin/cp src.txt dest.txt
#   ./bin/cp -r srcdir destdir

USAGE = "Usage: cp [OPTION]... SOURCE... DEST\n" \
        "  or:  cp [OPTION]... -t DIR SOURCE...\n" \
        "Copy SOURCE to DEST, or multiple SOURCEs into DEST directory.\n" \
        "  -r, -R  recursive     -f  force (no prompt)\n" \
        "  -i      interactive   -n  no-clobber\n" \
        "  -p      preserve times/perms   -v  verbose\n" \
        "  -l      hard link     -s  symlink\n" \
        "  -a      archive (same as -dpR)\n" \
        "  -u      update (copy only if source is newer)\n" \
        "  -t DIR  copy into DIR\n" \
        "  --help"

class CpOptions
  attr_accessor :recursive, :force, :interactive, :no_clobber
  attr_accessor :preserve, :verbose, :hard_link, :symlink, :update
  attr_accessor :target_dir
  def initialize
    @recursive   = false
    @force       = false
    @interactive = false
    @no_clobber  = false
    @preserve    = false
    @verbose     = false
    @hard_link   = false
    @symlink     = false
    @update      = false
    @target_dir  = nil
  end
end

def parse_argv(argv)
  opts = CpOptions.new
  sources = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg.length < 2 || arg[0] != "-"
      sources.push(arg)
      index += 1
      next
    end
    if arg == "--"
      options_done = true
      index += 1
      next
    end
    if arg == "--help"
      puts USAGE
      exit 0
    end
    if arg == "--recursive"; opts.recursive = true
    elsif arg == "--force"; opts.force = true
    elsif arg == "--interactive"; opts.interactive = true
    elsif arg == "--no-clobber"; opts.no_clobber = true
    elsif arg == "--preserve"; opts.preserve = true
    elsif arg == "--verbose"; opts.verbose = true
    elsif arg == "--archive"; opts.preserve = true; opts.recursive = true
    elsif arg == "--update"; opts.update = true
    elsif arg == "--link"; opts.hard_link = true
    elsif arg == "--symbolic-link"; opts.symlink = true
    elsif arg == "-t" || arg == "--target-directory"
      index += 1
      opts.target_dir = argv[index]
    elsif arg.length > 3 && arg[0, 3] == "-t="
      opts.target_dir = arg[3, arg.length - 3]
    elsif arg.length > 19 && arg[0, 19] == "--target-directory="
      opts.target_dir = arg[19, arg.length - 19]
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "r" || letter == "R"; opts.recursive = true
        elsif letter == "f"; opts.force = true
        elsif letter == "i"; opts.interactive = true
        elsif letter == "n"; opts.no_clobber = true
        elsif letter == "p" || letter == "d"; opts.preserve = true
        elsif letter == "v"; opts.verbose = true
        elsif letter == "a"; opts.preserve = true; opts.recursive = true
        elsif letter == "u"; opts.update = true
        elsif letter == "l"; opts.hard_link = true
        elsif letter == "s"; opts.symlink = true
        elsif letter == "t"
          li += 1
          if li < letters.length
            opts.target_dir = letters[li, letters.length - li]
            break
          else
            index += 1
            opts.target_dir = argv[index]
          end
        else
          STDERR.puts "cp: invalid option -- '#{letter}'"
          exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, sources]
end

def copy_file(src, dst, opts)
  if opts.update && File.exist?(dst)
    src_mt = File.stat(src).mtime
    dst_mt = File.stat(dst).mtime
    return if src_mt <= dst_mt
  end

  if opts.no_clobber && File.exist?(dst)
    return
  end

  if opts.interactive && File.exist?(dst) && !opts.force
    STDERR.write("cp: overwrite '#{dst}'? ")
    ans = STDIN.gets
    return unless ans && ans.strip.downcase == "y"
  end

  if opts.hard_link
    File.link(src, dst)
  elsif opts.symlink
    File.symlink(File.expand_path(src), dst)
  else
    content = File.read(src)
    f = File.open(dst, "w")
    f.write(content)
    f.close
    if opts.preserve
      stat = File.stat(src)
      File.utime(stat.atime, stat.mtime, dst)
      File.chmod(stat.mode, dst)
    end
  end
  puts "cp: '#{src}' -> '#{dst}'" if opts.verbose
end

def copy_recursive(src, dst, opts)
  if File.directory?(src)
    unless File.directory?(dst)
      Dir.mkdir(dst)
      puts "cp: created directory '#{dst}'" if opts.verbose
    end
    Dir.entries(src).each do |entry|
      next if entry == "." || entry == ".."
      copy_recursive(src + "/" + entry, dst + "/" + entry, opts)
    end
    if opts.preserve
      stat = File.stat(src)
      File.utime(stat.atime, stat.mtime, dst)
      File.chmod(stat.mode, dst)
    end
  else
    copy_file(src, dst, opts)
  end
end

opts, args = parse_argv(ARGV)

if opts.target_dir
  sources = args
  dest = opts.target_dir
elsif args.length < 2
  STDERR.puts "cp: missing file operand"
  exit 1
else
  sources = args[0, args.length - 1]
  dest = args.last
end

exit_code = 0

if sources.length > 1 || (File.exist?(dest) && File.directory?(dest))
  # Copying into a directory
  unless File.directory?(dest)
    STDERR.puts "cp: target '#{dest}' is not a directory"
    exit 1
  end
  sources.each do |src|
    unless File.exist?(src)
      STDERR.puts "cp: cannot stat '#{src}': No such file or directory"
      exit_code = 1
      next
    end
    dst = dest + "/" + File.basename(src)
    if File.directory?(src)
      unless opts.recursive
        STDERR.puts "cp: -r not specified; omitting directory '#{src}'"
        exit_code = 1
        next
      end
      copy_recursive(src, dst, opts)
    else
      copy_file(src, dst, opts)
    end
  end
else
  src = sources[0]
  unless File.exist?(src)
    STDERR.puts "cp: cannot stat '#{src}': No such file or directory"
    exit 1
  end
  if File.directory?(src)
    unless opts.recursive
      STDERR.puts "cp: -r not specified; omitting directory '#{src}'"
      exit 1
    end
    copy_recursive(src, dest, opts)
  else
    copy_file(src, dest, opts)
  end
end

exit exit_code
