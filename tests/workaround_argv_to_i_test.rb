# workaround_argv_to_i_test.rb
#
# Probes whether .to_i can be called directly on an ARGV-sourced value
# (sp_RbVal from array element access) without first coercing via "#{...}".
# If this prints WORKAROUND RESOLVED, the extra interpolation in token_api.rb
# can be removed.
#
# Affected workaround:
#   source/token_api.rb line ~216 - change  port = "#{port_value}".to_i  to  port = port_value.to_i

args = ["8080"]    # simulates ARGV[n] — array element access is sp_RbVal in Spinel
port_value = args[0]

port = port_value.to_i    # no "#{...}" coercion — the workaround being tested

if port == 8080
  puts "WORKAROUND RESOLVED: argv_element_to_i"
  puts "  In source/token_api.rb, change:"
  puts '    port = "#{port_value}".to_i'
  puts "  to:"
  puts "    port = port_value.to_i"
else
  puts "argv_element_to_i:still_needed"
end
