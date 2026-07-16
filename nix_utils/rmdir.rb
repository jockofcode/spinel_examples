# rmdir.rb, remove empty directories (GNU rmdir, Spinel port).
#
# Removes each DIRECTORY, which must be empty. Use rm -r for non-empty dirs.
#
# Flags:
#   -p, --parents  remove DIRECTORY and its ancestors (e.g. rmdir -p a/b/c
#                  is like rmdir a/b/c a/b a)
#   -v, --verbose  print a message for each removed directory
#   --help         usage
#
# Compile: spinel nix_utils/rmdir.rb -o nix_utils/bin/rmdir
# Run:
#   ./bin/rmdir emptydir
#   ./bin/rmdir -p a/b/c

USAGE = "Usage: rmdir [OPTION]... DIRECTORY...\n" \
        "Remove the DIRECTORY(ies), if they are empty.\n" \
        "  -p  remove DIRECTORY and its empty parent directories\n" \
        "  -v  print a message for each removed directory\n" \
        "  --help"

class RmdirOptions
  attr_accessor :parents, :verbose
  def initialize
    @parents = false
    @verbose = false
  end
end

def parse_argv(argv)
  opts = RmdirOptions.new
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
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "p"; opts.parents = true
        elsif letter == "v"; opts.verbose = true
        else
          STDERR.puts "rmdir: invalid option -- '#{letter}'"
          exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, dirs]
end

def remove_dir(path, opts)
  path = "" + path
  unless File.directory?(path)
    STDERR.puts "rmdir: failed to remove '#{path}': No such file or directory"
    return false
  end
  entries = Dir.entries(path).reject { |e| e == "." || e == ".." }
  unless entries.empty?
    STDERR.puts "rmdir: failed to remove '#{path}': Directory not empty"
    return false
  end
  Dir.rmdir(path)
  puts "rmdir: removing directory, '#{path}'" if opts.verbose
  true
end

opts, dirs = parse_argv(ARGV)

if dirs.empty?
  STDERR.puts "rmdir: missing operand"
  exit 1
end

exit_code = 0
dirs.each do |dir|
  cdir = "" + dir
  ok = remove_dir(cdir, opts)
  unless ok
    exit_code = 1
    next
  end

  if opts.parents
    # Walk up removing each parent that becomes empty
    current = cdir
    loop do
      parent = File.dirname(current)
      break if parent == current || parent == "." || parent == "/"
      break unless remove_dir(parent, opts)
      current = parent
    end
  end
end

exit exit_code
