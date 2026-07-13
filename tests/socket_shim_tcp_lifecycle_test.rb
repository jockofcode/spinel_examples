# socket_shim_tcp_lifecycle_test.rb
#
# No-network TCP compatibility test: run with both CRuby and Spinel and compare stdout.
# Live bind/accept coverage belongs in a separate smoke test because sandboxed
# environments may block bind(2).

require_relative "../source/socket_shim"

def check(label, value)
  if value
    puts label + ":ok"
  else
    puts label + ":bad"
  end
end

host = IPSocket.getaddress("127.0.0.1")
check("IPSocket.getaddress loopback", host == "127.0.0.1")

host_info = TCPSocket.gethostbyname("127.0.0.1")
check("TCPSocket.gethostbyname shape", host_info.length == 4)
check("TCPSocket.gethostbyname name", host_info[0] == "127.0.0.1")

addrinfo = Socket.getaddrinfo("127.0.0.1", 80)
check("Socket.getaddrinfo array", addrinfo.length > 0)
check("Socket.getaddrinfo first tuple", addrinfo[0].length >= 4)

tcp_server = TCPServer.allocate
check("TCPServer.open", TCPServer.respond_to?(:open))
check("TCPServer#accept", tcp_server.respond_to?(:accept))
check("TCPServer#accept_nonblock", tcp_server.respond_to?(:accept_nonblock))
check("TCPServer#listen", tcp_server.respond_to?(:listen))
check("TCPServer#sysaccept", tcp_server.respond_to?(:sysaccept))
