# parallel_digest.rb, a worker-pool file hasher built on Thread/Queue/Mutex.
#
# Hashes every file under a directory with a fixed pool of worker threads fed
# by a Queue, then prints each file's SHA-256 prefix. This is the "Ruby
# concurrency primitives inside an AOT-compiled binary" example: Thread, Queue,
# and Mutex compile straight through Spinel and behave like real Ruby.
#
# Spinel runs Ruby threads as green threads multiplexed onto N OS workers with
# NO GVL, so they can execute in genuine parallel, which is exactly why the
# shared state below must be guarded by a Mutex. Note an honest caveat this
# example makes concrete: Spinel's File.read and Digest.hexdigest currently use
# shared static buffers and are NOT thread-safe, so the read+hash step is held
# in a critical section (effectively serial today). The lesson is precisely
# that: under a no-GVL runtime, any library backed by shared/static state must
# be treated as a critical section. See worker_loop for the full rationale.
#
# The SPINEL_WORKERS env var caps the OS-worker count under this M:N scheduler;
# SPINEL_WORKERS=1 forces deterministic cooperative execution, handy for demos.
#
# Compile: SPINEL_REQUIRE_GATE=1 spinel source/parallel_digest.rb -o bin/parallel_digest
# Run:
#   ./bin/parallel_digest source -w 4      # 4 workers over source/
#   SPINEL_WORKERS=1 ./bin/parallel_digest source -w 8
#
# Runs unmodified under CRuby (`ruby source/parallel_digest.rb source -w 4`);
# there digest is real stdlib, here a require-gated Spinel package.

require "digest"

# Return the first n characters of a string, built with a single-index [] loop
# rather than a range slice (s[0...n]). When a string reaches us as a
# poly-typed value (as digests/paths sliced back out of shared state do),
# Spinel's range slicing returns only one character, whereas single-index []
# and concatenation dispatch reliably.
def first_chars(str, n)
  out = ""
  char_index = 0
  str_copy = str.dup
  while char_index < n && char_index < str_copy.length
    out = out + str_copy[char_index]
    char_index += 1
  end
  out
end

# Split "path\tdigest" back into [path, digest] using a single-index [] loop
# (same poly-string reason as first_chars: #split / #index / range slices are
# unreliable on these values, but [] and concatenation are not).
def split_tab(line)
  str_copy = line.dup
  length = str_copy.length
  left = ""
  right = ""
  seen_tab = false
  char_index = 0
  while char_index < length
    char = str_copy[char_index]
    if !seen_tab && char == "\t"
      seen_tab = true
    elsif seen_tab
      right = right + char
    else
      left = left + char
    end
    char_index += 1
  end
  [left, right]
end

# Directories we never descend into: build output, VCS metadata, and scratch.
# Skipping them keeps the output stable and the run fast.
SKIP_DIRS = { "bin" => true, ".git" => true, "tmp" => true }

# The body every worker thread runs. This is a METHOD, not an inline block, on
# purpose: variables declared inside a `Thread.new do ... end` block are shared
# closure cells across ALL workers in Spinel, so a per-item path/digest held in
# block locals would be overwritten by another worker mid-iteration. A method's
# parameters and locals live on that call's own stack, so each worker's
# item/path/digest are private.
#
# Each worker pops paths until it sees the nil sentinel, then reads and hashes
# the file and appends [path, digest] to the shared results array.
#
# The mutex here is a hard CORRECTNESS requirement, not style, because Spinel
# runs threads in genuine parallel with NO global VM lock, and several pieces
# of shared state below are not thread-safe on the current compiler:
#
#  1. File.read and Digest::SHA256.hexdigest each return a shared, process-wide
#     static buffer. With two green threads live, a second thread's call
#     overwrites the buffer before the first has copied it out, producing
#     blank or mismatched hashes. There is no thread-safe Digest instance
#     #update API either. So the read+hash MUST be serialized.
#  2. The shared results collection must not be mutated by two threads at once.
#
# Because of (1), guarding just the append is not enough: the entire read+hash
# runs inside mutex.synchronize, so exactly one thread touches those static
# buffers at a time. That makes the hashing effectively serial on Spinel today
#, and that is precisely the lesson this example teaches: under a no-GVL M:N
# runtime you get real parallelism, so any shared/static-buffer library must be
# treated as a critical section. The Thread/Queue/Mutex machinery is entirely
# real; the Mutex is what makes it correct. synchronize is compiler-inlined
# with full ensure semantics, so the lock always releases even on error.
#
# We also store one pre-formatted "path\tdigest" STRING per file rather than a
# nested [path, digest] array: nested array/string storage shared across
# threads was observed to corrupt, whereas a single flat string per entry is
# stable.
def worker_loop(queue, results, mutex)
  loop do
    item = queue.pop
    break if item.nil?
    # queue.pop returns a poly-typed value; make a concrete String so File.read
    # (which needs a C string) type-checks.
    path = "#{item}"
    begin
      mutex.synchronize do
        digest = Digest::SHA256.hexdigest(File.read(path))
        results << "#{path}\t#{digest}"
      end
    rescue => e
      # Skip unreadable files with a warning instead of crashing the pool.
      STDERR.puts "warning: skipping #{path}: #{e.message}"
    end
  end
end

# Recursively collect file paths under dir. We use an explicit Dir.entries
# walker (rather than Dir.glob) so we can prune SKIP_DIRS as we descend and so
# the traversal reads the same under both runtimes.
def collect_files(dir, acc)
  Dir.entries(dir).each do |name|
    next if name == "." || name == ".."
    path = "#{dir}/#{name}"
    if File.directory?(path)
      next if SKIP_DIRS[name]
      collect_files(path, acc)
    elsif File.file?(path)
      acc.push(path)
    end
    # Note: on Spinel a file with no read permission reports File.file? == false
    # and is quietly skipped here (never queued). The worker's begin/rescue is
    # still a real safety net for files that pass File.file? but fail at read
    # time (e.g. removed between the walk and the read, or other I/O errors),
    # and it is what produces the stderr warning under CRuby.
  end
end

# --- CLI ------------------------------------------------------------------

# Manual ARGV loop (same dependency-free style as fyel_srvr_6.rb): the
# first non-flag argument is the directory, -w N sets the worker count.
dir = "."
workers = 4
arg_index = 0
while arg_index < ARGV.length
  arg = ARGV[arg_index]
  if arg == "-w"
    worker_value = ARGV[arg_index + 1]
    if worker_value
      workers = worker_value.to_i
      arg_index += 1
    end
  else
    dir = arg
  end
  arg_index += 1
end
workers = 1 if workers < 1

unless File.directory?(dir)
  STDERR.puts "error: not a directory: #{dir}"
  exit 1
end


# --- work distribution ----------------------------------------------------

# Gather the file list up front on the main thread.
files = []
collect_files(dir, files)

# The job queue and the shared results array. `results` is written by every
# worker, so it is the shared mutable state that needs protection.
queue = Queue.new
results = []
mutex = Mutex.new

# Enqueue every path, then push one nil "poison pill" per worker. A worker that
# pops nil knows the work is done and exits its loop. (Queue#close would also
# work, pop returns nil on a drained, closed queue, but explicit sentinels
# make the one-pill-per-worker handshake obvious.)
files.each { |file_path| queue << file_path }
workers.times { queue << nil }

# Spawn the worker pool. The block does nothing but call worker_loop, so no
# per-item state lives in the (shared) block scope, see worker_loop.
threads = []
workers.times do
  threads << Thread.new do
    worker_loop(queue, results, mutex)
  end
end

# Wait for every worker to drain the queue and exit.
threads.each { |thread| thread.join }

# --- report ---------------------------------------------------------------

# Each entry is "path\tdigest". Sorting the raw strings orders by path (the
# leading field), giving deterministic output regardless of worker count or
# scheduling order. We split each entry back apart for display and print the
# first 12 hex chars of the digest.
results.sort.each do |line|
  parts = split_tab(line)
  path = parts[0]
  digest = parts[1]
  puts "#{first_chars(digest, 12)}  #{path}"
end

puts "hashed #{results.length} files with #{workers} workers"
