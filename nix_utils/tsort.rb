# tsort.rb, topological sort of a directed graph (GNU tsort, Spinel port).
#
# Reads pairs of tokens (whitespace-separated) from stdin or FILE. Each pair
# "A B" means A must come before B. Prints a topological ordering one node per
# line. Detects and reports cycles, then continues by printing cycle members.
#
# Flags:
#   --help, --version
#
# Compile: spinel nix_utils/tsort.rb -o nix_utils/bin/tsort

USAGE = "Usage: tsort [OPTION] [FILE]\n" \
        "Write the topological ordering of the graph given in FILE.\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit"

VERSION = "tsort (nix_utils) 1.0"

require_relative "nix_helpers"

file = nil
index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "--"
    index += 1
    file = coerce(ARGV[index]) if index < ARGV.length
    break
  elsif arg[0] == "-"
    die("tsort: unrecognized option '#{arg}'\nTry 'tsort --help' for more information.")
  else
    file = arg
  end
  index += 1
end

content = file.nil? ? STDIN.read : read_source(file)

# Tokenise: split on any whitespace
tokens = content.split
if tokens.length.odd?
  die("tsort: input contains an odd number of tokens")
end

# Build adjacency lists and track all nodes
successors = {}   # node -> [node, ...]
in_degree  = {}   # node -> count
all_nodes  = []   # insertion order for determinism

add_node = lambda do |n|
  cn = "" + n
  unless successors.key?(cn)
    successors[cn] = []
    in_degree[cn]  = 0
    all_nodes.push(cn)
  end
end

i = 0
while i < tokens.length
  a = "" + tokens[i]
  b = "" + tokens[i + 1]
  add_node.call(a)
  add_node.call(b)
  if a != b
    successors[a].push(b)
    in_degree[b] = in_degree[b] + 1
  end
  i += 2
end

# Kahn's algorithm
queue = []
all_nodes.each { |n| queue.push(n) if in_degree[n] == 0 }

exit_code = 0

while !queue.empty?
  node = "" + queue.shift
  puts node
  succs = successors[node]
  j = 0
  while j < succs.length
    s = "" + succs[j]
    in_degree[s] = in_degree[s] - 1
    queue.push(s) if in_degree[s] == 0
    j += 1
  end
end

# Any remaining nodes with in_degree > 0 are in a cycle
remaining = []
all_nodes.each { |n| remaining.push("" + n) if in_degree[n] > 0 }

unless remaining.empty?
  STDERR.puts "tsort: #{file || "stdin"}: input contains a loop:"
  remaining.each do |n|
    STDERR.puts "tsort: #{n}"
    puts n
  end
  exit_code = 1
end

exit exit_code
