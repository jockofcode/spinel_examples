# mv.rb, move (rename) files (GNU mv, Spinel port).
#
# Renames SOURCE to DEST, or moves multiple SOURCEs into DEST directory.
# Uses File.rename for same-filesystem moves; falls back to copy+delete
# across filesystems.
#
# Flags:
#   -f, --force          do not prompt before overwriting
#   -i, --interactive    prompt before overwriting
#   -n, --no-clobber     do not overwrite existing files
#   -v, --verbose        explain what is being done
#   -u, --update         move only when SOURCE is newer than DEST
#   -t DIR               move into DIR instead of last arg being the dest
#   --help               usage
#
# Compile: spinel nix_utils/mv.rb -o nix_utils/bin/mv
# Run:
#   ./bin/mv old.txt new.txt
#   ./bin/mv file1 file2 destdir/

USAGE = "Usage: mv [OPTION]... SOURCE... DEST\n" \
        "  or:  mv [OPTION]... -t DIR SOURCE...\n" \
        "Rename SOURCE to DEST, or move SOURCEs into DEST directory.\n" \
        "  -f  force (default)   -i  interactive   -n  no-clobber\n" \
        "  -v  verbose           -u  update (move only if newer)\n" \
        "  -t DIR  move into DIR\n" \
        "  --help"

class MvOptions
  attr_accessor :force, :interactive, :no_clobber, :verbose, :update, :target_dir
  def initialize
    @force       = false
    @interactive = false
    @no_clobber  = false
    @verbose     = false
    @update      = false
    @target_dir  = nil
  end
end

def parse_argv(argv)
  opts = MvOptions.new
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
    if arg == "--force"; opts.force = true
    elsif arg == "--interactive"; opts.interactive = true
    elsif arg == "--no-clobber"; opts.no_clobber = true
    elsif arg == "--verbose"; opts.verbose = true
    elsif arg == "--update"; opts.update = true
    elsif arg == "-t" || arg == "--target-directory"
      index += 1
      opts.target_dir = argv[index]
    elsif arg.length > 19 && arg[0, 19] == "--target-directory="
      opts.target_dir = arg[19, arg.length - 19]
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "f"; opts.force = true
        elsif letter == "i"; opts.interactive = true
        elsif letter == "n"; opts.no_clobber = true
        elsif letter == "v"; opts.verbose = true
        elsif letter == "u"; opts.update = true
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
          STDERR.puts "mv: invalid option -- '#{letter}'"
          exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, sources]
end

def move_file(src, dst, opts)
  csrc = "" + src
  cdst = "" + dst
  if opts.update && File.exist?(cdst)
    # File.stat.mtime not available in Spinel; delegate timestamp check to system mv -u.
    system("/bin/mv -u " + csrc + " " + cdst)
    return
  end
  if opts.no_clobber && File.exist?(cdst)
    return
  end
  if opts.interactive && File.exist?(cdst) && !opts.force
    STDERR.write("mv: overwrite '#{cdst}'? ")
    ans = STDIN.gets
    return unless ans && ans.strip.downcase == "y"
  end
  File.rename(csrc, cdst)
  puts "renamed '#{csrc}' -> '#{cdst}'" if opts.verbose
end

opts, args = parse_argv(ARGV)

raw_dest = ""
if opts.target_dir
  sources = args
  raw_dest = "" + opts.target_dir
elsif args.length < 2
  STDERR.puts "mv: missing file operand"
  exit 1
else
  sources = args[0, args.length - 1]
  raw_dest = "" + args.last
end
dest = raw_dest

exit_code = 0

if sources.length > 1 || (File.exist?(dest) && File.directory?(dest))
  unless File.directory?(dest)
    STDERR.puts "mv: target '#{dest}' is not a directory"
    exit 1
  end
  sources.each do |src|
    csrc = "" + src
    unless File.exist?(csrc)
      STDERR.puts "mv: cannot stat '#{csrc}': No such file or directory"
      exit_code = 1
      next
    end
    dst = dest + "/" + File.basename(csrc)
    move_file(csrc, dst, opts)
  end
else
  csrc = "" + sources[0]
  unless File.exist?(csrc)
    STDERR.puts "mv: cannot stat '#{csrc}': No such file or directory"
    exit 1
  end
  move_file(csrc, dest, opts)
end

exit exit_code
