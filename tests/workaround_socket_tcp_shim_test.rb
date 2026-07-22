# workaround_socket_tcp_shim_test.rb
#
# Probes whether Spinel natively supports TCPServer.open (block form) without
# the source/lib/socket_tcp.rb shim. The shim exists because Spinel's built-in
# TCPServer lacks the .open convenience method that the server examples rely on.
#
# If this prints WORKAROUND RESOLVED:
#   - Remove source/lib/socket_tcp.rb
#   - Replace require_relative 'lib/socket_tcp' with require 'socket' in all server files

if defined?(RUBY_ENGINE)
  require "socket"
end

ok = false
begin
  ok = TCPServer.respond_to?(:open)
rescue
  ok = false
end

if ok
  puts "WORKAROUND RESOLVED: socket_tcp_shim"
  puts "  Remove source/lib/socket_tcp.rb."
  puts "  Replace require_relative 'lib/socket_tcp' with require 'socket' in:"
  puts "    source/fyel_srvr_1.rb through fyel_srvr_6.rb"
  puts "    source/token_api.rb"
else
  puts "socket_tcp_shim:still_needed"
end
