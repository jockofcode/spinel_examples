# workaround_argv_file_path_test.rb
#
# Probes whether an ARGV-sourced value (sp_RbVal from array element access)
# can be passed directly to File.exist? and File.read without coercion.
# If this prints WORKAROUND RESOLVED, the explicit "#{...}" coercion in
# todo_cli.rb can be removed.
#
# Affected workaround:
#   source/todo_cli.rb line ~134 - change  data_file = "#{file_value}"  to  data_file = file_value

tmp_probe = "/tmp/spinel_probe_argv_path.txt"
File.write(tmp_probe, "argv_probe")

args = [tmp_probe]    # simulates ARGV[n] — array element access is sp_RbVal in Spinel
file_value = args[0]

ok = File.exist?(file_value) && File.read(file_value) == "argv_probe"
File.delete(tmp_probe) if File.exist?(tmp_probe)

if ok
  puts "WORKAROUND RESOLVED: argv_element_as_file_path"
  puts "  In source/todo_cli.rb, change:"
  puts '    data_file = "#{file_value}"'
  puts "  to:"
  puts "    data_file = file_value"
else
  puts "argv_element_as_file_path:still_needed"
end
