# socket_shim.rb

if defined?(RUBY_ENGINE)
  require "socket"
end

if defined?(TCPServer)
  # CRuby already loaded the real socket classes.
else
  class SocketError < StandardError
  end

  module SpinelSocketNative
    ffi_func :sp_net_listen, [:int, :int], :int
    ffi_func :sp_net_accept, [:int], :int
    ffi_func :sp_net_accept_nb, [:int], :int
    ffi_func :sp_net_connect, [:str, :int], :int
    ffi_func :sp_net_close, [:int], :int
    ffi_func :sp_net_set_nonblock, [:int], :int
    ffi_func :sp_net_write_str, [:int, :str], :int
    ffi_func :sp_net_recv_some, [:int, :int], :binstr
    ffi_func :sp_net_recv_all, [:int, :int], :binstr
    ffi_func :sp_net_poll_reset, [], :int
    ffi_func :sp_net_poll_add, [:int, :int], :int
    ffi_func :sp_net_poll_run, [:int], :int
    ffi_func :sp_net_poll_ready, [:int], :int
    ffi_func :sp_net_install_term_handlers, [], :int
    ffi_func :sp_net_shutdown_requested, [], :int
  end

  module SpinelSocketShim
    def self.unsupported(name)
      raise "Socket method not implemented in Spinel socket_shim: #{name}"
    end

    def self.normalize_host(host)
      if host
        host
      else
        "0.0.0.0"
      end
    end
  end

  class BasicSocket
    def self.for_fd(fd)
      new(fd)
    end

    def self.do_not_reverse_lookup
      false
    end

    def self.do_not_reverse_lookup=(value)
      value
    end

    def initialize(fd)
      @fd = fd
      @socket_family = "socket"
      @remote_host = nil
      @remote_port = nil
      @local_host = nil
      @local_port = nil
    end

    def recv(maxlen, flags = 0)
      if flags != 0
        SpinelSocketShim.unsupported("BasicSocket#recv flags")
      end
      SpinelSocketNative.sp_net_recv_some(@fd, maxlen)
    end

    def recv_nonblock(maxlen, flags = 0)
      if flags != 0
        SpinelSocketShim.unsupported("BasicSocket#recv_nonblock flags")
      end
      SpinelSocketNative.sp_net_set_nonblock(@fd)
      SpinelSocketNative.sp_net_recv_some(@fd, maxlen)
    end

    def recvmsg(maxlen = 2048, flags = 0)
      if flags != 0
        SpinelSocketShim.unsupported("BasicSocket#recvmsg flags")
      end
      [recv(maxlen), nil, nil]
    end

    def recvmsg_nonblock(maxlen = 2048, flags = 0)
      if flags != 0
        SpinelSocketShim.unsupported("BasicSocket#recvmsg_nonblock flags")
      end
      [recv_nonblock(maxlen), nil, nil]
    end

    def send(data, flags = 0, dest_sockaddr = nil)
      if flags != 0 || dest_sockaddr
        SpinelSocketShim.unsupported("BasicSocket#send flags or destination")
      end
      SpinelSocketNative.sp_net_write_str(@fd, data)
    end

    def sendmsg(data, flags = 0, dest_sockaddr = nil, controls = nil)
      if controls
        SpinelSocketShim.unsupported("BasicSocket#sendmsg controls")
      end
      send(data, flags, dest_sockaddr)
    end

    def sendmsg_nonblock(data, flags = 0, dest_sockaddr = nil, controls = nil)
      SpinelSocketNative.sp_net_set_nonblock(@fd)
      sendmsg(data, flags, dest_sockaddr, controls)
    end

    def write(data)
      SpinelSocketNative.sp_net_write_str(@fd, data)
    end

    def readpartial(maxlen)
      recv(maxlen)
    end

    def close
      if @fd >= 0
        fd = @fd
        @fd = -1
        SpinelSocketNative.sp_net_close(fd)
      else
        0
      end
    end

    def closed?
      @fd < 0
    end

    def close_read
      shutdown(Socket::SHUT_RD)
    end

    def close_write
      shutdown(Socket::SHUT_WR)
    end

    def shutdown(how = Socket::SHUT_RDWR)
      SpinelSocketShim.unsupported("BasicSocket#shutdown")
    end

    def getsockname
      if @local_host && @local_port
        Socket.pack_sockaddr_in(@local_port, @local_host)
      else
        ""
      end
    end

    def getpeername
      if @remote_host && @remote_port
        Socket.pack_sockaddr_in(@remote_port, @remote_host)
      else
        ""
      end
    end

    def getsockopt(level, optname)
      SpinelSocketShim.unsupported("BasicSocket#getsockopt")
    end

    def setsockopt(level, optname, optval)
      SpinelSocketShim.unsupported("BasicSocket#setsockopt")
    end

    def local_address
      Addrinfo.tcp(@local_host || "0.0.0.0", @local_port || 0)
    end

    def remote_address
      Addrinfo.tcp(@remote_host || "0.0.0.0", @remote_port || 0)
    end

    def connect_address
      remote_address
    end

    def do_not_reverse_lookup
      BasicSocket.do_not_reverse_lookup
    end

    def do_not_reverse_lookup=(value)
      BasicSocket.do_not_reverse_lookup = value
    end

    def getpeereid
      SpinelSocketShim.unsupported("BasicSocket#getpeereid")
    end
  end

  class IPSocket < BasicSocket
    def self.getaddress(host)
      host
    end

    def addr(reverse_lookup = false)
      ["AF_INET", @local_port || 0, @local_host || "0.0.0.0", @local_host || "0.0.0.0"]
    end

    def peeraddr(reverse_lookup = false)
      ["AF_INET", @remote_port || 0, @remote_host || "0.0.0.0", @remote_host || "0.0.0.0"]
    end

    def recvfrom(maxlen, flags = 0)
      [recv(maxlen, flags), peeraddr]
    end

    def inspect
      "#<#{self.class}:fd #{@fd}>"
    end
  end

  class TCPSocket < IPSocket
    def self.__from_fd(fd)
      socket = new(fd)
      socket.__set_socket_family("tcp")
      socket
    end

    def self.gethostbyname(host)
      [host, [], Socket::AF_INET, host]
    end

    def initialize(host_or_fd, port = nil)
      if port
        fd = SpinelSocketNative.sp_net_connect(host_or_fd, port)
        if fd < 0
          raise "Failed to connect to #{host_or_fd}:#{port}."
        end
        super(fd)
        @socket_family = "tcp"
        @remote_host = host_or_fd
        @remote_port = port
      else
        super(host_or_fd)
        @socket_family = "tcp"
      end
    end

    def __set_socket_family(socket_family)
      @socket_family = socket_family
    end
  end

  class TCPServer < TCPSocket
    def self.open(host_or_port, port = nil)
      if port
        server = new(host_or_port, port)
      else
        server = new(host_or_port)
      end
      if block_given?
        begin
          yield server
        ensure
          server.close
        end
      else
        server
      end
    end

    def initialize(host_or_port, port = nil)
      if port
        @local_host = host_or_port
        @local_port = port
      else
        @local_host = "0.0.0.0"
        @local_port = host_or_port
      end

      fd = SpinelSocketNative.sp_net_listen(@local_port, 1)
      if fd < 0
        raise "Failed to bind to port #{@local_port}."
      end
      super(fd)
      @socket_family = "tcp_server"
    end

    def accept
      client_fd = SpinelSocketNative.sp_net_accept(@fd)
      while client_fd < 0
        client_fd = SpinelSocketNative.sp_net_accept(@fd)
      end
      TCPSocket.__from_fd(client_fd)
    end

    def accept_nonblock
      SpinelSocketNative.sp_net_set_nonblock(@fd)
      client_fd = SpinelSocketNative.sp_net_accept_nb(@fd)
      if client_fd < 0
        raise "No pending connection."
      end
      TCPSocket.__from_fd(client_fd)
    end

    def listen(backlog)
      0
    end

    def sysaccept
      client_fd = SpinelSocketNative.sp_net_accept(@fd)
      while client_fd < 0
        client_fd = SpinelSocketNative.sp_net_accept(@fd)
      end
      client_fd
    end
  end

  class UDPSocket < IPSocket
    def initialize(domain = Socket::AF_INET)
      SpinelSocketShim.unsupported("UDPSocket.new")
    end

    def bind(host, port)
      SpinelSocketShim.unsupported("UDPSocket#bind")
    end

    def connect(host, port)
      SpinelSocketShim.unsupported("UDPSocket#connect")
    end

    def send(data, flags = 0, host = nil, port = nil)
      SpinelSocketShim.unsupported("UDPSocket#send")
    end

    def recvfrom_nonblock(maxlen, flags = 0)
      SpinelSocketShim.unsupported("UDPSocket#recvfrom_nonblock")
    end
  end

  class UNIXSocket < BasicSocket
    def self.pair(type = Socket::SOCK_STREAM, protocol = 0)
      socketpair(type, protocol)
    end

    def self.socketpair(type = Socket::SOCK_STREAM, protocol = 0)
      SpinelSocketShim.unsupported("UNIXSocket.socketpair")
    end

    def initialize(path)
      SpinelSocketShim.unsupported("UNIXSocket.new")
    end

    def addr
      ["AF_UNIX", @path || ""]
    end

    def peeraddr
      ["AF_UNIX", @path || ""]
    end

    def path
      @path || ""
    end

    def recvfrom(maxlen, flags = 0)
      [recv(maxlen, flags), peeraddr]
    end

    def recv_io(klass = IO, mode = nil)
      SpinelSocketShim.unsupported("UNIXSocket#recv_io")
    end

    def send_io(io)
      SpinelSocketShim.unsupported("UNIXSocket#send_io")
    end
  end

  class UNIXServer < UNIXSocket
    def accept
      SpinelSocketShim.unsupported("UNIXServer#accept")
    end

    def accept_nonblock
      SpinelSocketShim.unsupported("UNIXServer#accept_nonblock")
    end

    def listen(backlog)
      SpinelSocketShim.unsupported("UNIXServer#listen")
    end

    def sysaccept
      SpinelSocketShim.unsupported("UNIXServer#sysaccept")
    end
  end

  class Socket < BasicSocket
    AF_UNSPEC = 0
    AF_UNIX = 1
    AF_LOCAL = 1
    AF_INET = 2
    AF_INET6 = 30
    PF_UNSPEC = 0
    PF_UNIX = 1
    PF_LOCAL = 1
    PF_INET = 2
    PF_INET6 = 30
    SOCK_STREAM = 1
    SOCK_DGRAM = 2
    SOCK_RAW = 3
    SOL_SOCKET = 0xffff
    SO_REUSEADDR = 0x0004
    SO_REUSEPORT = 0x0200
    SO_KEEPALIVE = 0x0008
    SO_BROADCAST = 0x0020
    SO_LINGER = 0x0080
    SO_RCVBUF = 0x1002
    SO_SNDBUF = 0x1001
    TCP_NODELAY = 0x01
    SHUT_RD = 0
    SHUT_WR = 1
    SHUT_RDWR = 2
    MSG_OOB = 0x1
    MSG_PEEK = 0x2
    MSG_DONTROUTE = 0x4
    MSG_WAITALL = 0x40
    AI_PASSIVE = 0x1
    AI_CANONNAME = 0x2
    AI_NUMERICHOST = 0x4
    AI_NUMERICSERV = 0x1000
    NI_NUMERICHOST = 0x1
    NI_NUMERICSERV = 0x2
    NI_NAMEREQD = 0x4
    EAI_AGAIN = 2
    EAI_FAIL = 4
    EAI_NONAME = 8
    EAI_SERVICE = 9

    module Constants
      AF_UNSPEC = 0
      AF_UNIX = 1
      AF_LOCAL = 1
      AF_INET = 2
      AF_INET6 = 30
      PF_UNSPEC = 0
      PF_UNIX = 1
      PF_LOCAL = 1
      PF_INET = 2
      PF_INET6 = 30
      SOCK_STREAM = 1
      SOCK_DGRAM = 2
      SOCK_RAW = 3
      SOL_SOCKET = 0xffff
      SO_REUSEADDR = 0x0004
      SO_REUSEPORT = 0x0200
      TCP_NODELAY = 0x01
      SHUT_RD = 0
      SHUT_WR = 1
      SHUT_RDWR = 2
    end

    class WaitReadable < StandardError
    end

    class WaitWritable < StandardError
    end

    class EAGAINWaitReadable < WaitReadable
    end

    class EAGAINWaitWritable < WaitWritable
    end

    class EWOULDBLOCKWaitReadable < WaitReadable
    end

    class EWOULDBLOCKWaitWritable < WaitWritable
    end

    class EINPROGRESSWaitReadable < WaitReadable
    end

    class EINPROGRESSWaitWritable < WaitWritable
    end

    def self.tcp(host, port, local_host = nil, local_port = nil)
      socket = TCPSocket.new(host, port)
      if block_given?
        begin
          yield socket
        ensure
          socket.close
        end
      else
        socket
      end
    end

    def self.tcp_server_loop(host_or_port, port = nil)
      if port
        TCPServer.open(host_or_port, port) do |server|
          loop do
            yield server.accept
          end
        end
      else
        TCPServer.open(host_or_port) do |server|
          loop do
            yield server.accept
          end
        end
      end
    end

    def self.tcp_server_sockets(host_or_port, port = nil)
      if port
        [TCPServer.new(host_or_port, port)]
      else
        [TCPServer.new(host_or_port)]
      end
    end

    def self.accept_loop(server)
      loop do
        yield server.accept
      end
    end

    def self.udp_server_sockets(host, port)
      SpinelSocketShim.unsupported("Socket.udp_server_sockets")
    end

    def self.udp_server_loop(host, port)
      SpinelSocketShim.unsupported("Socket.udp_server_loop")
    end

    def self.udp_server_loop_on(sockets)
      SpinelSocketShim.unsupported("Socket.udp_server_loop_on")
    end

    def self.udp_server_recv(sockets)
      SpinelSocketShim.unsupported("Socket.udp_server_recv")
    end

    def self.unix(path)
      SpinelSocketShim.unsupported("Socket.unix")
    end

    def self.unix_server_socket(path)
      SpinelSocketShim.unsupported("Socket.unix_server_socket")
    end

    def self.unix_server_loop(path)
      SpinelSocketShim.unsupported("Socket.unix_server_loop")
    end

    def self.pair(domain = AF_UNIX, type = SOCK_STREAM, protocol = 0)
      socketpair(domain, type, protocol)
    end

    def self.socketpair(domain = AF_UNIX, type = SOCK_STREAM, protocol = 0)
      SpinelSocketShim.unsupported("Socket.socketpair")
    end

    def self.getaddrinfo(host, service, family = nil, socktype = nil, protocol = nil, flags = nil)
      [[family || "AF_INET", service, host, host, family || AF_INET, socktype || SOCK_STREAM, protocol || 0]]
    end

    def self.getnameinfo(sockaddr, flags = 0)
      unpack_sockaddr_in(sockaddr)
    end

    def self.gethostbyname(host)
      TCPSocket.gethostbyname(host)
    end

    def self.gethostbyaddr(address, family = AF_INET)
      [address, [], family, address]
    end

    def self.gethostname
      SpinelSocketShim.unsupported("Socket.gethostname")
    end

    def self.getifaddrs
      SpinelSocketShim.unsupported("Socket.getifaddrs")
    end

    def self.ip_address_list
      SpinelSocketShim.unsupported("Socket.ip_address_list")
    end

    def self.getservbyname(service, protocol = "tcp")
      SpinelSocketShim.unsupported("Socket.getservbyname")
    end

    def self.getservbyport(port, protocol = "tcp")
      SpinelSocketShim.unsupported("Socket.getservbyport")
    end

    def self.pack_sockaddr_in(port, host)
      "#{host}:#{port}"
    end

    def self.sockaddr_in(port, host)
      pack_sockaddr_in(port, host)
    end

    def self.unpack_sockaddr_in(sockaddr)
      parts = sockaddr.split(":")
      host = parts[0] || "0.0.0.0"
      port_text = parts[1] || "0"
      [port_text.to_i, host]
    end

    def self.pack_sockaddr_un(path)
      path
    end

    def self.sockaddr_un(path)
      pack_sockaddr_un(path)
    end

    def self.unpack_sockaddr_un(sockaddr)
      sockaddr
    end

    def initialize(domain = AF_INET, type = SOCK_STREAM, protocol = 0)
      SpinelSocketShim.unsupported("Socket.new")
    end

    def accept
      client_fd = SpinelSocketNative.sp_net_accept(@fd)
      if client_fd < 0
        raise "No pending connection."
      end
      [Socket.for_fd(client_fd), ""]
    end

    def accept_nonblock
      SpinelSocketNative.sp_net_set_nonblock(@fd)
      client_fd = SpinelSocketNative.sp_net_accept_nb(@fd)
      if client_fd < 0
        raise "No pending connection."
      end
      [Socket.for_fd(client_fd), ""]
    end

    def bind(sockaddr)
      SpinelSocketShim.unsupported("Socket#bind")
    end

    def connect(sockaddr)
      SpinelSocketShim.unsupported("Socket#connect")
    end

    def connect_nonblock(sockaddr)
      SpinelSocketShim.unsupported("Socket#connect_nonblock")
    end

    def listen(backlog)
      SpinelSocketShim.unsupported("Socket#listen")
    end

    def recvfrom(maxlen, flags = 0)
      [recv(maxlen, flags), ""]
    end

    def recvfrom_nonblock(maxlen, flags = 0)
      [recv_nonblock(maxlen, flags), ""]
    end

    def sysaccept
      SpinelSocketNative.sp_net_accept(@fd)
    end

    def ipv6only!
      SpinelSocketShim.unsupported("Socket#ipv6only!")
    end
  end

  class Addrinfo
    def self.foreach(host, service = nil, family = nil, socktype = nil, protocol = nil, flags = nil)
      info = tcp(host, service || 0)
      if block_given?
        yield info
      else
        [info]
      end
    end

    def self.getaddrinfo(host, service = nil, family = nil, socktype = nil, protocol = nil, flags = nil)
      [tcp(host, service || 0)]
    end

    def self.ip(host)
      new(Socket::AF_INET, 0, 0, host, 0, nil)
    end

    def self.tcp(host, port)
      new(Socket::AF_INET, Socket::SOCK_STREAM, 0, host, port, nil)
    end

    def self.udp(host, port)
      new(Socket::AF_INET, Socket::SOCK_DGRAM, 0, host, port, nil)
    end

    def self.unix(path)
      new(Socket::AF_UNIX, Socket::SOCK_STREAM, 0, nil, 0, path)
    end

    def initialize(afamily, socktype, protocol, ip_address, ip_port, unix_path)
      @afamily = afamily
      @pfamily = afamily
      @socktype = socktype
      @protocol = protocol
      @ip_address = ip_address
      @ip_port = ip_port
      @unix_path = unix_path
      @canonname = nil
    end

    def afamily
      @afamily
    end

    def pfamily
      @pfamily
    end

    def socktype
      @socktype
    end

    def protocol
      @protocol
    end

    def canonname
      @canonname
    end

    def ip?
      @afamily == Socket::AF_INET || @afamily == Socket::AF_INET6
    end

    def ipv4?
      @afamily == Socket::AF_INET
    end

    def ipv6?
      @afamily == Socket::AF_INET6
    end

    def unix?
      @afamily == Socket::AF_UNIX
    end

    def ip_address
      @ip_address || ""
    end

    def ip_port
      @ip_port || 0
    end

    def unix_path
      @unix_path || ""
    end

    def ip_unpack
      [ip_address, ip_port]
    end

    def to_sockaddr
      if unix?
        Socket.pack_sockaddr_un(unix_path)
      else
        Socket.pack_sockaddr_in(ip_port, ip_address)
      end
    end

    def to_s
      to_sockaddr
    end

    def inspect_sockaddr
      to_sockaddr
    end

    def inspect
      "#<Addrinfo: #{to_sockaddr}>"
    end

    def getnameinfo(flags = 0)
      if unix?
        [unix_path, nil]
      else
        [ip_address, ip_port]
      end
    end

    def connect
      TCPSocket.new(ip_address, ip_port)
    end

    def connect_from(local_addrinfo)
      connect
    end

    def connect_to(remote_addrinfo)
      remote_addrinfo.connect
    end

    def connect_internal(local_addrinfo = nil)
      connect
    end

    def bind
      TCPServer.new(ip_address, ip_port)
    end

    def listen(backlog = 5)
      TCPServer.new(ip_address, ip_port)
    end

    def family_addrinfo
      self
    end

    def marshal_dump
      [@afamily, @socktype, @protocol, @ip_address, @ip_port, @unix_path]
    end

    def marshal_load(values)
      @afamily = values[0]
      @pfamily = @afamily
      @socktype = values[1]
      @protocol = values[2]
      @ip_address = values[3]
      @ip_port = values[4]
      @unix_path = values[5]
      @canonname = nil
    end

    def ipv4_loopback?
      ip_address == "127.0.0.1"
    end

    def ipv4_private?
      ip_address.start_with?("10.") || ip_address.start_with?("192.168.") || ip_address.start_with?("172.")
    end

    def ipv4_multicast?
      false
    end

    def ipv6_loopback?
      ip_address == "::1"
    end

    def ipv6_multicast?
      false
    end

    def ipv6_unspecified?
      ip_address == "::"
    end

    def ipv6_linklocal?
      false
    end

    def ipv6_sitelocal?
      false
    end

    def ipv6_unique_local?
      false
    end

    def ipv6_v4compat?
      false
    end

    def ipv6_v4mapped?
      false
    end

    def ipv6_to_ipv4
      nil
    end

    def ipv6_mc_global?
      false
    end

    def ipv6_mc_linklocal?
      false
    end

    def ipv6_mc_nodelocal?
      false
    end

    def ipv6_mc_orglocal?
      false
    end

    def ipv6_mc_sitelocal?
      false
    end
  end

  class Socket::Option
    def self.bool(family, level, optname, bool)
      new(family, level, optname, bool ? 1 : 0)
    end

    def self.byte(family, level, optname, integer)
      new(family, level, optname, integer)
    end

    def self.int(family, level, optname, integer)
      new(family, level, optname, integer)
    end

    def self.linger(onoff, secs)
      new(Socket::AF_UNSPEC, Socket::SOL_SOCKET, Socket::SO_LINGER, [onoff, secs])
    end

    def self.ipv4_multicast_loop(value)
      new(Socket::AF_INET, 0, 0, value)
    end

    def self.ipv4_multicast_ttl(value)
      new(Socket::AF_INET, 0, 0, value)
    end

    def initialize(family, level, optname, data)
      @family = family
      @level = level
      @optname = optname
      @data = data
    end

    def family
      @family
    end

    def level
      @level
    end

    def optname
      @optname
    end

    def data
      @data
    end

    def bool
      @data ? true : false
    end

    def byte
      @data
    end

    def int
      @data
    end

    def linger
      @data
    end

    def ipv4_multicast_loop
      @data
    end

    def ipv4_multicast_ttl
      @data
    end

    def unpack(template)
      [@data]
    end

    def to_s
      @data.to_s
    end

    def inspect
      "#<Socket::Option: #{@data}>"
    end
  end

  class Socket::AncillaryData
    def self.int(family, level, type, integer)
      new(family, level, type, integer)
    end

    def self.ip_pktinfo(addr, ifindex)
      new(Socket::AF_INET, 0, 0, [addr, ifindex])
    end

    def self.ipv6_pktinfo(addr, ifindex)
      new(Socket::AF_INET6, 0, 0, [addr, ifindex])
    end

    def self.unix_rights(*ios)
      new(Socket::AF_UNIX, 0, 0, ios)
    end

    def initialize(family, level, type, data)
      @family = family
      @level = level
      @type = type
      @data = data
    end

    def family
      @family
    end

    def level
      @level
    end

    def type
      @type
    end

    def data
      @data
    end

    def cmsg_is?(family, level, type)
      @family == family && @level == level && @type == type
    end

    def int
      @data
    end

    def ip_pktinfo
      @data
    end

    def ipv6_pktinfo
      @data
    end

    def ipv6_pktinfo_addr
      @data[0]
    end

    def ipv6_pktinfo_ifindex
      @data[1]
    end

    def timestamp
      nil
    end

    def unix_rights
      @data
    end

    def inspect
      "#<Socket::AncillaryData: #{@data}>"
    end
  end

  class Socket::Ifaddr
    def initialize(name, ifindex, flags, addr, netmask, broadaddr, dstaddr)
      @name = name
      @ifindex = ifindex
      @flags = flags
      @addr = addr
      @netmask = netmask
      @broadaddr = broadaddr
      @dstaddr = dstaddr
    end

    def name
      @name
    end

    def ifindex
      @ifindex
    end

    def flags
      @flags
    end

    def addr
      @addr
    end

    def netmask
      @netmask
    end

    def broadaddr
      @broadaddr
    end

    def dstaddr
      @dstaddr
    end

    def inspect
      "#<Socket::Ifaddr: #{@name}>"
    end
  end
end
