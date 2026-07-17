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
#   -P, --no-dereference copy symlinks as symlinks (do not follow)
#   -L, --dereference    always follow symbolic links in SOURCE (default)
#   -a, --archive        same as -dpR
#   -u, --update         copy only when SOURCE is newer than DEST or DEST missing
#   -t DIR               copy into DIR instead of last argument being the dest
#   --help               usage
#
# Compile: spinel nix_utils/cp.rb --link nix_utils/sp_file_ext.o -o nix_utils/bin/cp
# Run:
#   ./bin/cp src.txt dest.txt
#   ./bin/cp -r srcdir destdir

require_relative 'file_ext'

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
  attr_accessor :preserve, :verbose, :hard_link, :symlink, :update, :no_deref
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
    @no_deref    = false
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
    elsif arg == "--no-dereference"; opts.no_deref = true
    elsif arg == "--dereference"; opts.no_deref = false
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
        elsif letter == "P"; opts.no_deref = true
        elsif letter == "L"; opts.no_deref = false
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
  csrc = "" + src
  cdst = "" + dst
  if opts.no_deref && File.symlink?(csrc)
    if File.exist?(cdst) || File.symlink?(cdst)
      return if opts.no_clobber
      if opts.interactive && !opts.force
        STDERR.write("cp: overwrite '#{cdst}'? ")
        ans = STDIN.gets
        return unless ans && ans.strip.downcase == "y"
      end
      File.unlink(cdst) if opts.force || opts.interactive
    end
    tgt = FileExt.readlink(csrc)
    FileExt.symlink(tgt, cdst)
    puts "cp: '#{csrc}' -> '#{cdst}'" if opts.verbose
    return
  end
  if opts.update && File.exist?(cdst)
    # File.stat.mtime not in Spinel; delegate to system cp -u.
    system("/bin/cp -u " + csrc + " " + cdst)
    return
  end

  if opts.no_clobber && File.exist?(cdst)
    return
  end

  if opts.interactive && File.exist?(cdst) && !opts.force
    STDERR.write("cp: overwrite '#{cdst}'? ")
    ans = STDIN.gets
    return unless ans && ans.strip.downcase == "y"
  end

  if opts.hard_link
    FileExt.link(csrc, cdst)
  elsif opts.symlink
    abs_src = csrc[0] == "/" ? csrc : Dir.pwd + "/" + csrc
    FileExt.symlink(abs_src, cdst)
  else
    content = File.read(csrc)
    f = File.open(cdst, "w")
    f.write(content)
    f.close
    if opts.preserve
      # File.stat / File.utime / File.chmod not in Spinel; delegate to system cp -p.
      system("/bin/cp -p " + csrc + " " + cdst)
    end
  end
  puts "cp: '#{csrc}' -> '#{cdst}'" if opts.verbose
end

def copy_recursive(src, dst, opts)
  csrc = "" + src
  cdst = "" + dst
  if File.directory?(csrc)
    unless File.directory?(cdst)
      Dir.mkdir(cdst)
      puts "cp: created directory '#{cdst}'" if opts.verbose
    end
    Dir.entries(csrc).each do |entry|
      centry = "" + entry
      next if centry == "." || centry == ".."
      copy_recursive(csrc + "/" + centry, cdst + "/" + centry, opts)
    end
    if opts.preserve
      system("/bin/cp -p " + csrc + " " + cdst)
    end
  else
    copy_file(csrc, cdst, opts)
  end
end

opts, args = parse_argv(ARGV)

raw_dest = ""
if opts.target_dir
  sources = args
  raw_dest = "" + opts.target_dir
elsif args.length < 2
  STDERR.puts "cp: missing file operand"
  exit 1
else
  sources = args[0, args.length - 1]
  raw_dest = "" + args.last
end
dest = raw_dest

exit_code = 0

if sources.length > 1 || (File.exist?(dest) && File.directory?(dest))
  # Copying into a directory
  unless File.directory?(dest)
    STDERR.puts "cp: target '#{dest}' is not a directory"
    exit 1
  end
  sources.each do |src|
    csrc = "" + src
    unless File.exist?(csrc)
      STDERR.puts "cp: cannot stat '#{csrc}': No such file or directory"
      exit_code = 1
      next
    end
    dst = dest + "/" + File.basename(csrc)
    if File.directory?(csrc)
      unless opts.recursive
        STDERR.puts "cp: -r not specified; omitting directory '#{csrc}'"
        exit_code = 1
        next
      end
      copy_recursive(csrc, dst, opts)
    else
      copy_file(csrc, dst, opts)
    end
  end
else
  csrc = "" + sources[0]
  unless File.exist?(csrc)
    STDERR.puts "cp: cannot stat '#{csrc}': No such file or directory"
    exit 1
  end
  if File.directory?(csrc)
    unless opts.recursive
      STDERR.puts "cp: -r not specified; omitting directory '#{csrc}'"
      exit 1
    end
    copy_recursive(csrc, dest, opts)
  else
    copy_file(csrc, dest, opts)
  end
end

exit exit_code
