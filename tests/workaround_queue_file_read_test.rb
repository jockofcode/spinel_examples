# workaround_queue_file_read_test.rb
#
# Probes whether File.read accepts a Queue#pop value directly (sp_RbVal).
# Currently Spinel rejects this at compile time: sp_RbVal cannot be passed
# where const char* is required. If this prints WORKAROUND RESOLVED, the
# explicit coercion in worker_loop can be removed.
#
# Affected workaround:
#   source/parallel_digest.rb worker_loop - change  path = "#{item}"  to  path = item

tmp_probe = "/tmp/spinel_probe_workaround.txt"
File.write(tmp_probe, "probe_content")

q = Queue.new
q << tmp_probe
item = q.pop

content = File.read(item)    # no "#{item}" coercion — the workaround being tested
File.delete(tmp_probe) if File.exist?(tmp_probe)

if content == "probe_content"
  puts "WORKAROUND RESOLVED: queue_pop_as_file_read_arg"
  puts '  In source/parallel_digest.rb worker_loop, change:'
  puts '    path = "#{item}"'
  puts '  to:'
  puts '    path = item'
else
  puts "queue_pop_as_file_read_arg:still_needed"
end
