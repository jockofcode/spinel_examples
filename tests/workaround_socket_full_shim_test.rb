# workaround_socket_full_shim_test.rb
#
# Probes whether Spinel natively provides the full Ruby Socket API — UDPSocket,
# UNIXSocket, the Socket class, and Addrinfo — without source/lib/socket_shim.rb.
# The shim exists because Spinel's require "socket" only exposes TCPSocket and
# TCPServer; the rest of the stdlib socket surface is absent.
#
# If this prints WORKAROUND RESOLVED:
#   - Remove source/lib/socket_shim.rb
#   - Replace require_relative 'lib/socket_shim' with require 'socket' in any file that uses it

if defined?(RUBY_ENGINE)
  require "socket"
end

ok = defined?(UDPSocket) == "constant" &&
     defined?(UNIXSocket) == "constant" &&
     defined?(Socket) == "constant" &&
     defined?(Addrinfo) == "constant"

if ok
  puts "WORKAROUND RESOLVED: socket_full_shim"
  puts "  Remove source/lib/socket_shim.rb."
  puts "  Replace require_relative 'lib/socket_shim' with require 'socket'."
else
  puts "socket_full_shim:still_needed"
end
