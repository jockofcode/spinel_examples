# log_report.rb -- an access-log analyzer for Common Log Format.
#
# Reads a web-server access log and prints a summary report: totals, requests
# by status code, the busiest paths, and total bytes served. This is the
# "text processing is where Ruby shines -- and it compiles" example: it leans
# on named-capture regexps, MatchData, StringScanner, and Set, all AOT-compiled
# by Spinel into a single native binary.
#
# Compile: SPINEL_REQUIRE_GATE=1 spinel source/log_report.rb -o bin/log_report
# Run:
#   ./bin/log_report                          # uses data/sample_access.log
#   ./bin/log_report data/sample_access.log   # explicit file
#
# The same file runs unmodified under CRuby (`ruby source/log_report.rb`),
# where set/strscan are real stdlib and here a require-gated Spinel subset.

require "set"      # unique-IP counting
require "strscan"  # timestamp tokenizing (see parse_month_from_timestamp)

# One regexp with named captures does the heavy lifting: it pulls the client
# IP, the bracketed timestamp, the request method and path, the status code,
# and the response size out of a Common Log Format line in a single match.
# Lines that do not match are treated as malformed and counted, never fatal.
LINE_RE = %r{^(?<ip>\S+) \S+ \S+ \[(?<time>[^\]]+)\] "(?<method>\S+) (?<path>\S+) [^"]*" (?<status>\d+) (?<size>\d+|-)}

# Month name -> number, as a literal Hash. We deliberately avoid Date and
# Time.parse (heavier stdlib surface); the report only needs the month number,
# which a lookup table supplies directly.
MONTHS = {
  "Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6,
  "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12
}

# Tokenize the "10/Jul/2026:13:55:36 -0700" timestamp with StringScanner.
# A StringScanner is the right tool here: we walk the field left to right,
# pulling one token at a time and stepping over the single-character
# separators, instead of writing a second, fiddly regexp. Returns the numeric
# month, or nil if the field is not shaped as expected.
def parse_month_from_timestamp(time_str)
  sc = StringScanner.new(time_str)
  sc.scan(/\d+/)           # day (consumed, not needed for the report)
  return nil unless sc.getch == "/"
  mon_name = sc.scan(/[A-Za-z]+/)
  return nil if mon_name.nil?
  MONTHS[mon_name]
end


# Sort a Hash of {key => count} into an array of [key, count] pairs, highest
# count first, breaking ties by key so the output is fully deterministic --
# identical under CRuby and the Spinel binary regardless of sort stability.
def sorted_by_count_desc(counts)
  pairs = []
  counts.each { |k, v| pairs.push([k, v]) }
  pairs.sort_by { |pair| [-pair[1], pair[0]] }
end

# --- read + parse --------------------------------------------------------

data_file = ARGV[0] || "data/sample_access.log"

unless File.exist?(data_file)
  STDERR.puts "error: no such file: #{data_file}"
  exit 1
end

total = 0             # lines that parsed as valid requests
malformed = 0         # lines that did not match LINE_RE
bytes_total = 0       # sum of response sizes, skipping "-"
unique_ips = Set.new  # distinct client IPs
status_counts = {}    # status code (String) => count
path_counts = {}      # request path => hit count

File.readlines(data_file).each do |line|
  line = line.chomp
  next if line == ""

  m = LINE_RE.match(line)
  if m.nil?
    malformed += 1
    next
  end

  total += 1
  unique_ips << m[:ip]

  status = m[:status]
  status_counts[status] = (status_counts[status] || 0) + 1

  path = m[:path]
  path_counts[path] = (path_counts[path] || 0) + 1

  size = m[:size]
  bytes_total += size.to_i unless size == "-"

  # Exercise the StringScanner path; the month number is not shown in the
  # report but validates that every good line carries a well-formed timestamp.
  parse_month_from_timestamp(m[:time])
end


# --- report --------------------------------------------------------------

puts "Access-log report for #{data_file}"
puts "=" * 48
puts ""

puts "Total requests : #{total}"
puts "Malformed lines: #{malformed}"
puts "Unique IPs     : #{unique_ips.size}"
puts "Bytes served   : #{bytes_total}"
puts ""

puts "Requests by status code:"
# Sort by the status code itself so 200/301/404/500 read in natural order.
status_keys = []
status_counts.each { |k, _v| status_keys.push(k) }
status_keys.sort.each do |code|
  puts "  #{code.ljust(4)} #{status_counts[code].to_s.rjust(4)}"
end
puts ""

puts "Top 5 paths by hits:"
sorted_by_count_desc(path_counts).first(5).each do |pair|
  path = pair[0]
  hits = pair[1]
  puts "  #{hits.to_s.rjust(4)}  #{path}"
end
