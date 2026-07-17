# ln.rb, make links between files (GNU ln, Spinel port).
#
# Creates hard links by default; use -s for symbolic links.
#
# Flags:
#   -s, --symbolic       make symbolic links instead of hard links
#   -f, --force          remove existing destination files
#   -n, --no-dereference treat DEST symlink as normal file (with -s)
#   -v, --verbose        print name of each linked file
#   -r, --relative       create symlinks relative to link location
#   -b, --backup         make a backup of each existing destination file
#   -t DIR               specify the DIR in which to create the links
#   --help               usage
#
# Compile: spinel nix_utils/ln.rb --link nix_utils/sp_file_ext.o -o nix_utils/bin/ln
# Run:
#   ./bin/ln -s /path/to/file linkname
#   ./bin/ln file1 file2 destdir/

require_relative 'file_ext'

USAGE = "Usage: ln [OPTION]... TARGET LINK_NAME\n" \
        "  or:  ln [OPTION]... TARGET... DIRECTORY\n" \
        "  or:  ln [OPTION]... -t DIRECTORY TARGET...\n" \
        "Create links between files.\n" \
        "  -s  symbolic link   -f  force   -v  verbose\n" \
        "  -r  relative symlink   -n  no-dereference\n" \
        "  -b  backup existing   -t DIR  link into DIR\n" \
        "  --help"

class LnOptions
  attr_accessor :symbolic, :force, :verbose, :relative, :no_deref, :backup, :target_dir
  def initialize
    @symbolic   = false
    @force      = false
    @verbose    = false
    @relative   = false
    @no_deref   = false
    @backup     = false
    @target_dir = nil
  end
end

def parse_argv(argv)
  opts = LnOptions.new
  targets = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg.length < 2 || arg[0] != "-"
      targets.push(arg)
      index += 1
      next
    end
    if arg == "--"
      options_done = true; index += 1; next
    end
    if arg == "--help"; puts USAGE; exit 0; end
    if arg == "--symbolic"; opts.symbolic = true
    elsif arg == "--force"; opts.force = true
    elsif arg == "--verbose"; opts.verbose = true
    elsif arg == "--relative"; opts.relative = true
    elsif arg == "--no-dereference"; opts.no_deref = true
    elsif arg == "--backup"; opts.backup = true
    elsif arg == "-t" || arg == "--target-directory"
      index += 1; opts.target_dir = argv[index]
    elsif arg.length > 19 && arg[0, 19] == "--target-directory="
      opts.target_dir = arg[19, arg.length - 19]
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "s"; opts.symbolic = true
        elsif letter == "f"; opts.force = true
        elsif letter == "v"; opts.verbose = true
        elsif letter == "r"; opts.relative = true
        elsif letter == "n"; opts.no_deref = true
        elsif letter == "b"; opts.backup = true
        elsif letter == "t"
          li += 1
          if li < letters.length
            opts.target_dir = letters[li, letters.length - li]; break
          else
            index += 1; opts.target_dir = argv[index]
          end
        else
          STDERR.puts "ln: invalid option -- '#{letter}'"; exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, targets]
end

def make_link(target, link_path, opts)
  ctgt  = "" + target
  clink = "" + link_path
  if File.exist?(clink) || File.symlink?(clink)
    if opts.backup
      File.rename(clink, clink + "~")
    elsif opts.force
      File.unlink(clink)
    else
      STDERR.puts "ln: failed to create link '#{clink}': File exists"
      return false
    end
  end

  if opts.symbolic
    tgt = ctgt
    if opts.relative
      link_dir = "" + File.dirname(File.expand_path(clink))
      abs_tgt  = "" + File.expand_path(ctgt)
      tgt = abs_tgt.start_with?(link_dir + "/") ?
            abs_tgt[link_dir.length + 1, abs_tgt.length] :
            ctgt
    end
    FileExt.symlink(tgt, clink)
  else
    FileExt.link(ctgt, clink)
  end
  puts "'#{ctgt}' -> '#{clink}'" if opts.verbose
  true
end

opts, args = parse_argv(ARGV)

raw_dest = ""
raw_dest_dir = ""
has_dest_dir = false
if opts.target_dir
  sources  = args
  raw_dest_dir = "" + opts.target_dir
  has_dest_dir = true
elsif args.length < 2
  STDERR.puts "ln: missing file operand"
  exit 1
else
  sources  = args[0, args.length - 1]
  raw_dest = "" + args.last
end

exit_code = 0

if has_dest_dir || sources.length > 1 || (!has_dest_dir && File.directory?(raw_dest))
  dir = has_dest_dir ? raw_dest_dir : raw_dest
  unless File.directory?(dir)
    STDERR.puts "ln: target '#{dir}' is not a directory"
    exit 1
  end
  sources.each do |src|
    csrc = "" + src
    link_path = dir + "/" + File.basename(csrc)
    ok = make_link(csrc, link_path, opts)
    exit_code = 1 unless ok
  end
else
  csrc = "" + sources[0]
  ok = make_link(csrc, raw_dest, opts)
  exit_code = 1 unless ok
end

exit exit_code
