# rm.rb, remove files or directories (GNU rm, Spinel port).
#
# Removes each FILE. By default, does not remove directories.
#
# Flags:
#   -r, -R, --recursive  remove directories and their contents recursively
#   -f, --force          ignore nonexistent files; never prompt
#   -i                   prompt before every removal
#   -I                   prompt before removing 3+ files or -r
#   -v, --verbose        explain what is being done
#   -d, --dir            remove empty directories
#   --help               usage
#
# Compile: spinel nix_utils/rm.rb -o nix_utils/bin/rm
# Run:
#   ./bin/rm file.txt
#   ./bin/rm -rf tmpdir/

USAGE = "Usage: rm [OPTION]... FILE...\n" \
        "Remove (unlink) each FILE.\n" \
        "  -r, -R  recursively remove directories\n" \
        "  -f      force (ignore nonexistent, never prompt)\n" \
        "  -i      prompt before every removal\n" \
        "  -v      verbose\n" \
        "  -d      remove empty directories\n" \
        "  --help"

class RmOptions
  attr_accessor :recursive, :force, :interactive, :interactive_once, :verbose, :dir
  def initialize
    @recursive        = false
    @force            = false
    @interactive      = false
    @interactive_once = false
    @verbose          = false
    @dir              = false
  end
end

def parse_argv(argv)
  opts = RmOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
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
    elsif arg == "--verbose"; opts.verbose = true
    elsif arg == "--dir"; opts.dir = true
    elsif arg == "--interactive"; opts.interactive = true
    else
      letters = arg[1, arg.length - 1]
      li = 0
      while li < letters.length
        letter = letters[li]
        if letter == "r" || letter == "R"; opts.recursive = true
        elsif letter == "f"; opts.force = true; opts.interactive = false
        elsif letter == "i"; opts.interactive = true; opts.force = false
        elsif letter == "I"; opts.interactive_once = true
        elsif letter == "v"; opts.verbose = true
        elsif letter == "d"; opts.dir = true
        else
          STDERR.puts "rm: invalid option -- '#{letter}'"
          exit 1
        end
        li += 1
      end
    end
    index += 1
  end
  [opts, files]
end

def rm_file(path, opts)
  unless File.exist?(path) || File.symlink?(path)
    unless opts.force
      STDERR.puts "rm: cannot remove '#{path}': No such file or directory"
      return false
    end
    return true
  end

  if opts.interactive
    STDERR.write("rm: remove '#{path}'? ")
    ans = STDIN.gets
    return true unless ans && ans.strip.downcase == "y"
  end

  if File.directory?(path) && !File.symlink?(path)
    if opts.recursive
      Dir.entries(path).each do |entry|
        next if entry == "." || entry == ".."
        rm_file(path + "/" + entry, opts)
      end
      Dir.rmdir(path)
      puts "removed directory '#{path}'" if opts.verbose
    elsif opts.dir
      entries = Dir.entries(path).reject { |e| e == "." || e == ".." }
      if entries.empty?
        Dir.rmdir(path)
        puts "removed directory '#{path}'" if opts.verbose
      else
        STDERR.puts "rm: cannot remove '#{path}': Directory not empty"
        return false
      end
    else
      STDERR.puts "rm: cannot remove '#{path}': Is a directory"
      return false
    end
  else
    File.unlink(path)
    puts "removed '#{path}'" if opts.verbose
  end
  true
end

opts, files = parse_argv(ARGV)

if files.empty? && !opts.force
  STDERR.puts "rm: missing operand"
  exit 1
end

# -I: prompt once if removing 3+ files or with -r
if opts.interactive_once && !opts.interactive
  if opts.recursive || files.length >= 3
    STDERR.write("rm: remove #{files.length} argument(s)? ")
    ans = STDIN.gets
    exit 0 unless ans && ans.strip.downcase == "y"
  end
end

exit_code = 0
files.each do |f|
  ok = rm_file(f, opts)
  exit_code = 1 unless ok
end

exit exit_code
