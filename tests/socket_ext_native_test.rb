# socket_ext_native_test.rb
#
# Runtime smoke test for the project-local native socket extension. Run with
# both CRuby and Spinel and compare stdout. Spinel needs:
#
#   ~/Projects/spinel/spinel -E --link native/socket_ext/socket_ext.c tests/socket_ext_native_test.rb

require_relative "../source/socket_shim"

def check(label, value)
  if value
    puts label + ":ok"
  else
    puts label + ":bad"
  end
end

hostname = Socket.gethostname
check("Socket.gethostname", hostname.length > 0)

http_port = Socket.getservbyname("http", "tcp")
check("Socket.getservbyname http", http_port == 80)

http_name = Socket.getservbyport(80, "tcp")
check("Socket.getservbyport 80", http_name.length > 0)

packed = Socket.pack_sockaddr_in(12345, "127.0.0.1")
unpacked = Socket.unpack_sockaddr_in(packed)
check("Socket.pack_sockaddr_in native", unpacked[0] == 12345 && unpacked[1] == "127.0.0.1")

info = Socket.getaddrinfo("127.0.0.1", 80)
check("Socket.getaddrinfo native", info.length > 0 && info[0].length >= 4)

ifaddrs = Socket.getifaddrs
check("Socket.getifaddrs native", ifaddrs.length > 0 && ifaddrs[0].name.length > 0)

ip_addrs = Socket.ip_address_list
check("Socket.ip_address_list native", ip_addrs.length > 0)

raw = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
check("Socket.new native closed before close", !raw.closed?)
raw.close
check("Socket.new native closed after close", raw.closed?)

if defined?(RUBY_ENGINE)
  ipv6_family = Socket::AF_INET6
else
  ipv6_family = Socket.native_constants[3]
end
ipv6 = Socket.new(ipv6_family, Socket::SOCK_STREAM, 0)
check("Socket#ipv6only! native", ipv6.ipv6only! == 0)
ipv6.close

server = UDPSocket.new
server.bind("127.0.0.1", 0)
port = Socket.unpack_sockaddr_in(server.getsockname)[0]
client = UDPSocket.new
client.connect("127.0.0.1", port)
sent = client.write("hello")
received = server.recvfrom(16)
check("UDPSocket.write native", sent >= 0)
check("UDPSocket.recvfrom_nonblock native", received[0] == "hello")
client.close
server.close

left, right = UNIXSocket.socketpair
peer_ids = left.getpeereid
check("BasicSocket#getpeereid native", peer_ids.length == 2 && peer_ids[0] >= 0 && peer_ids[1] >= 0)
left.write("ping")
check("UNIXSocket.socketpair native", right.recv(16) == "ping")

pass_left, pass_right = UNIXSocket.socketpair
left.send_io(pass_right)
received_io = right.recv_io(UNIXSocket)
pass_left.write("fdpass")
check("UNIXSocket send_io/recv_io native", received_io.recv(16) == "fdpass")
received_io.close
pass_left.close
pass_right.close

msg_left, msg_right = UNIXSocket.socketpair
msg_pass_left, msg_pass_right = UNIXSocket.socketpair
msg_control = Socket::AncillaryData.unix_rights(msg_pass_right)
msg_left.sendmsg("msgfd", 0, nil, msg_control)
msg_result = msg_right.recvmsg(16)
if defined?(RUBY_ENGINE)
  check("BasicSocket sendmsg/recvmsg rights native", msg_result[0] == "msgfd" && msg_result.length == 4)
else
  msg_received = msg_result[3].unix_rights[0]
  msg_pass_left.write("msgpass")
  check("BasicSocket sendmsg/recvmsg rights native", msg_result[0] == "msgfd" && msg_received.recv(16) == "msgpass")
  msg_received.close
end
msg_pass_left.close
msg_pass_right.close
msg_left.close
msg_right.close
left.close
right.close

if !defined?(RUBY_ENGINE)
  constants = Socket.native_constants
  check("Socket.native_constants", constants.length == 13 && constants[2] > 0 && constants[3] > 0)
end
