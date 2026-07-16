# mkdir.rb, make directories (GNU mkdir, Spinel port).
#
# Creates each DIRECTORY named by an argument. Fails if the directory
# already exists, unless -p is given.
#
# Flags:
#   -p, --parents  create parent directories as needed; no error if exists
#   -m MODE        set file mode (octal, e.g. 755); applied after umask
#   -v, --verbose  print a message for each created directory
#   -z             set SELinux context (accepted, ignored)
#   --help         usage
#
# Compile: spinel nix_utils/mkdir.rb -o nix_utils/bin/mkdir
# Run:
#   ./bin/mkdir newdir
#   ./bin/mkdir -p a/b/c

USAGE = "Usage: mkdir [OPTION]... DIRECTORY...\n" \
        "Create the DIRECTORY(ies), if they do not already exist.\n" \
        "  -m MODE  set file permission bits (default: umask)\n" \
        "  -p       no error if existing, make parent directories as needed\n" \
        "  -v       print a message for each created directory\n" \
        "  --help"

class MkdirOptions
  attr_accessor :parents, :mode, :verbose
  def initialize
    @parents = false
    @mode    = nil
    @verbose = false
  end
end

def parse_argv(argv)
  opts = MkdirOptions.new
  dirs = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg.length < 2 || arg[0] != "-"
      dirs.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE
      exit 0
    elsif arg == "-p" || arg == "--parents"
      opts.parents = true
    elsif arg == "-v" || arg == "--verbose"
      opts.verbose = true
    elsif arg == "-z"
      # SELinux context, ignore
    elsif arg == "-m" || arg == "--mode"
      index += 1
      opts.mode = argv[index].to_i(8)
    elsif arg.length > 2 && arg[0, 2] == "-m"
      opts.mode = arg[2, arg.length - 2].to_i(8)
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "p"
          opts.parents = true
        elsif letter == "v"
          opts.verbose = true
        else
          STDERR.puts "mkdir: invalid option -- '#{letter}'"
          exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, dirs]
end

def mkdir_p(path, opts)
  is_abs = path.length > 0 && path[0] == "/"
  current = is_abs ? "/" : ""
  path.split("/").each do |seg|
    next if seg == "" || seg == "."
    current = current == "" ? seg : current.end_with?("/") ? current + seg : current + "/" + seg
    next if File.directory?(current)
    if File.exist?(current)
      STDERR.puts "mkdir: cannot create directory '#{path}': Not a directory"
      return false
    end
    if opts.mode
      Dir.mkdir(current, opts.mode)
    else
      Dir.mkdir(current)
    end
    puts "mkdir: created directory '#{current}'" if opts.verbose
  end
  true
end

opts, dirs = parse_argv(ARGV)

if dirs.empty?
  STDERR.puts "mkdir: missing operand"
  exit 1
end

exit_code = 0
dirs.each do |dir|
  cdir = "" + dir
  if opts.parents
    ok = mkdir_p(cdir, opts)
    exit_code = 1 unless ok
  else
    if File.directory?(cdir)
      STDERR.puts "mkdir: cannot create directory '#{cdir}': File exists"
      exit_code = 1
      next
    end
    if File.exist?(cdir)
      STDERR.puts "mkdir: cannot create directory '#{cdir}': File exists"
      exit_code = 1
      next
    end
    parent = File.dirname(cdir)
    if parent != "." && parent != "/" && !File.directory?(parent)
      STDERR.puts "mkdir: cannot create directory '#{cdir}': No such file or directory"
      exit_code = 1
      next
    end
    if opts.mode
      Dir.mkdir(cdir, opts.mode)
    else
      Dir.mkdir(cdir)
    end
    puts "mkdir: created directory '#{cdir}'" if opts.verbose
  end
end

exit exit_code
