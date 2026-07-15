# tee.rb, read from stdin and write to stdout and files (GNU tee, Spinel port).
#
# Copy standard input to each FILE and also to standard output.
#
# Flags:
#   -a, --append   append to the given FILEs, do not overwrite
#   -i, --ignore-interrupts  (accepted, no-op)
#   --help
#
# Compile: spinel nix_utils/tee.rb -o nix_utils/bin/tee
# Run:
#   echo hello | ./bin/tee /tmp/out.txt
#   echo hello | ./bin/tee -a log.txt
#
# Core Ruby only (File, STDIN, STDOUT); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/tee.rb ...`).

USAGE = "Usage: tee [OPTION]... [FILE]...\n" \
        "Copy standard input to each FILE and to standard output.\n" \
        "  -a  append to files   -i  ignore interrupts (no-op)   --help"

append = false
file_names = []
options_done = false

ARGV.each do |arg|
  if options_done || (arg.length < 2 || arg[0] != "-")
    file_names.push(arg)
  elsif arg == "--"
    options_done = true
  elsif arg == "--help"
    puts USAGE
    exit 0
  elsif arg == "-a" || arg == "--append"
    append = true
  elsif arg == "-i" || arg == "--ignore-interrupts"
    # no-op
  else
    i = 1
    valid = true
    while i < arg.length
      c = arg[i]
      if c == "a";    append = true
      elsif c == "i"; # no-op
      else valid = false; break
      end
      i += 1
    end
    unless valid
      STDERR.puts "tee: invalid option -- '#{arg}'"
      STDERR.puts "Try 'tee --help' for more information."
      exit 1
    end
  end
end

mode = append ? "a" : "w"
out_files = []
exit_code = 0
file_names.each do |name|
  out_files.push(File.open(name, mode))
end

content = STDIN.read
STDOUT.write(content)
out_files.each do |f|
  f.write(content)
  f.close
end

exit exit_code
