# socket_shim_value_test.rb
#
# Deterministic value behavior test: run with both CRuby and Spinel and compare stdout.

require_relative "../source/lib/socket_shim"

def check(label, value)
  if value
    puts label + ":ok"
  else
    puts label + ":bad"
  end
end

check("Socket::AF_INET", Socket::AF_INET == Socket::Constants::AF_INET)
check("Socket::SOCK_STREAM", Socket::SOCK_STREAM == Socket::Constants::SOCK_STREAM)
check("Socket::SHUT_RDWR", Socket::SHUT_RDWR == Socket::Constants::SHUT_RDWR)
check("Socket::Constants::AF_INET", Socket::Constants::AF_INET == Socket::AF_INET)
check("Socket::Constants::SOCK_STREAM", Socket::Constants::SOCK_STREAM == Socket::SOCK_STREAM)

packed_in = Socket.pack_sockaddr_in(80, "127.0.0.1")
unpacked_in = Socket.unpack_sockaddr_in(packed_in)
check("Socket.pack/unpack sockaddr_in port", unpacked_in[0] == 80)
check("Socket.pack/unpack sockaddr_in host", unpacked_in[1] == "127.0.0.1")

packed_un = Socket.pack_sockaddr_un("/tmp/spinel.sock")
unpacked_un = Socket.unpack_sockaddr_un(packed_un)
check("Socket.pack/unpack sockaddr_un", unpacked_un == "/tmp/spinel.sock")

tcp_info = Addrinfo.tcp("127.0.0.1", 80)
check("Addrinfo.tcp ip?", tcp_info.ip?)
check("Addrinfo.tcp ipv4?", tcp_info.ipv4?)
check("Addrinfo.tcp address", tcp_info.ip_address == "127.0.0.1")
check("Addrinfo.tcp port", tcp_info.ip_port == 80)
check("Addrinfo.tcp afamily", tcp_info.afamily == Socket::AF_INET)
check("Addrinfo.tcp socktype", tcp_info.socktype == Socket::SOCK_STREAM)

udp_info = Addrinfo.udp("127.0.0.1", 53)
check("Addrinfo.udp ip?", udp_info.ip?)
check("Addrinfo.udp socktype", udp_info.socktype == Socket::SOCK_DGRAM)
check("Addrinfo.udp port", udp_info.ip_port == 53)

ip_info = Addrinfo.ip("127.0.0.1")
check("Addrinfo.ip ip?", ip_info.ip?)
check("Addrinfo.ip address", ip_info.ip_address == "127.0.0.1")

unix_info = Addrinfo.unix("/tmp/spinel.sock")
check("Addrinfo.unix unix?", unix_info.unix?)
check("Addrinfo.unix path", unix_info.unix_path == "/tmp/spinel.sock")

seen_foreach = false
Addrinfo.foreach("127.0.0.1", 80) do |info|
  seen_foreach = info.ip?
end
check("Addrinfo.foreach yields", seen_foreach)
check("Addrinfo.getaddrinfo array", Addrinfo.getaddrinfo("127.0.0.1", 80).length > 0)

option_bool = Socket::Option.bool(Socket::AF_INET, Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
option_byte = Socket::Option.byte(Socket::AF_INET, Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 7)
option_int = Socket::Option.int(Socket::AF_INET, Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)

check("Socket::Option.bool", option_bool.bool)
check("Socket::Option.byte", option_byte.byte == 7)
check("Socket::Option.int", option_int.int == 1)
check("Socket::Option family", option_int.family == Socket::AF_INET)
check("Socket::Option level", option_int.level == Socket::SOL_SOCKET)
check("Socket::Option optname", option_int.optname == Socket::SO_REUSEADDR)
check("Socket::Option data method", option_int.respond_to?(:data))
check("Socket::Option unpack", option_int.unpack("i")[0] == 1)

ancillary = Socket::AncillaryData.int(Socket::AF_INET, Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 7)
check("Socket::AncillaryData family", ancillary.family == Socket::AF_INET)
check("Socket::AncillaryData level", ancillary.level == Socket::SOL_SOCKET)
check("Socket::AncillaryData type", ancillary.type == Socket::SO_REUSEADDR)
check("Socket::AncillaryData int", ancillary.int == 7)
check("Socket::AncillaryData data method", ancillary.respond_to?(:data))
check("Socket::AncillaryData cmsg_is?", ancillary.cmsg_is?(Socket::SOL_SOCKET, Socket::SO_REUSEADDR))
