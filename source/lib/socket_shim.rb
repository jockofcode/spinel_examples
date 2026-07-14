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

    ffi_func :sx_set_nonblock, [:int], :int
    ffi_func :sx_shutdown, [:int, :int], :int
    ffi_func :sx_ipv6only, [:int], :int
    ffi_func :sx_getsockname, [:int], :str
    ffi_func :sx_getpeername, [:int], :str
    ffi_func :sx_getsockopt_int, [:int, :int, :int], :int
    ffi_func :sx_getsockopt_int_str, [:int, :str, :str], :int
    ffi_func :sx_setsockopt_int, [:int, :int, :int, :int], :int
    ffi_func :sx_setsockopt_int_str, [:int, :str, :str, :str], :int
    ffi_func :sx_getpeereid_uid, [:int], :int
    ffi_func :sx_getpeereid_gid, [:int], :int
    ffi_func :sx_recv_flags, [:int, :int, :int], :binstr
    ffi_func :sx_recv_nonblock, [:int, :int, :int], :binstr
    ffi_func :sx_send_flags, [:int, :str, :int], :int
    ffi_func :sx_send_nonblock, [:int, :str, :int], :int
    ffi_func :sx_udp_socket, [:int], :int
    ffi_func :sx_udp_bind, [:int, :str, :int], :int
    ffi_func :sx_udp_connect, [:int, :str, :int], :int
    ffi_func :sx_udp_sendto, [:int, :str, :int, :str, :int], :int
    ffi_func :sx_udp_recvfrom, [:int, :int, :int], :binstr
    ffi_func :sx_last_recvfrom_addr, [], :str
    ffi_func :sx_socket_create, [:int, :int, :int], :int
    ffi_func :sx_socket_create_tcp, [], :int
    ffi_func :sx_socket_create_tcp6, [], :int
    ffi_func :sx_last_errno, [], :int
    ffi_func :sx_socket_bind, [:int, :str], :int
    ffi_func :sx_socket_connect, [:int, :str], :int
    ffi_func :sx_socket_listen, [:int, :int], :int
    ffi_func :sx_socket_listen_str, [:int, :str], :int
    ffi_func :sx_socket_accept, [:int], :int
    ffi_func :sx_unix_socket, [], :int
    ffi_func :sx_unix_connect, [:str], :int
    ffi_func :sx_unix_server, [:str], :int
    ffi_func :sx_unix_socketpair, [], :int
    ffi_func :sx_unix_socketpair_first, [], :int
    ffi_func :sx_unix_socketpair_second, [], :int
    ffi_func :sx_send_fd, [:int, :int], :int
    ffi_func :sx_recv_fd, [:int], :int
    ffi_func :sx_sendmsg_fd, [:int, :str, :int], :int
    ffi_func :sx_recvmsg_with_fd, [:int, :int, :int], :binstr
    ffi_func :sx_last_recv_fd, [], :int
    ffi_func :sx_gethostname, [], :str
    ffi_func :sx_getaddrinfo_one, [:str, :int, :int, :int, :int, :int], :str
    ffi_func :sx_getnameinfo, [:str, :int], :str
    ffi_func :sx_getservbyname_port, [:str, :str], :int
    ffi_func :sx_getservbyport_name, [:int, :str], :str
    ffi_func :sx_getservbyport_name_str, [:str, :str], :str
    ffi_func :sx_pack_sockaddr_in, [:int, :str], :str
    ffi_func :sx_unpack_sockaddr_in_port, [:str], :int
    ffi_func :sx_unpack_sockaddr_in_host, [:str], :str
    ffi_func :sx_pack_sockaddr_un, [:str], :str
    ffi_func :sx_unpack_sockaddr_un, [:str], :str
    ffi_func :sx_const_af_inet, [], :int
    ffi_func :sx_const_af_inet6, [], :int
    ffi_func :sx_const_af_unix, [], :int
    ffi_func :sx_const_af_unspec, [], :int
    ffi_func :sx_const_sock_stream, [], :int
    ffi_func :sx_const_sock_dgram, [], :int
    ffi_func :sx_const_sol_socket, [], :int
    ffi_func :sx_const_so_reuseaddr, [], :int
    ffi_func :sx_const_so_reuseport, [], :int
    ffi_func :sx_const_tcp_nodelay, [], :int
    ffi_func :sx_const_shut_rd, [], :int
    ffi_func :sx_const_shut_wr, [], :int
    ffi_func :sx_const_shut_rdwr, [], :int
    ffi_func :sx_ifaddr_count, [], :int
    ffi_func :sx_ifaddr_name, [:int], :str
    ffi_func :sx_ifaddr_ifindex, [:int], :int
    ffi_func :sx_ifaddr_flags, [:int], :int
    ffi_func :sx_ifaddr_family, [:int], :int
    ffi_func :sx_ifaddr_addr, [:int], :str
    ffi_func :sx_ifaddr_netmask, [:int], :str
    ffi_func :sx_ifaddr_broadaddr, [:int], :str
    ffi_func :sx_ifaddr_dstaddr, [:int], :str
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
      if flags == 0
        SpinelSocketNative.sp_net_recv_some(@fd, maxlen)
      else
        SpinelSocketNative.sx_recv_flags(@fd, maxlen, flags)
      end
    end

    def recv_nonblock(maxlen, flags = 0)
      SpinelSocketNative.sx_recv_nonblock(@fd, maxlen, flags)
    end

    def recvmsg(maxlen = 2048, flags = 0)
      data = SpinelSocketNative.sx_recvmsg_with_fd(@fd, maxlen, flags)
      received_fd = SpinelSocketNative.sx_last_recv_fd
      if received_fd >= 0
        io = UNIXSocket.__from_fd(received_fd)
        ancillary = Socket::AncillaryData.unix_rights(io)
        [data, nil, 0, ancillary]
      else
        [data, nil, 0]
      end
    end

    def recvmsg_nonblock(maxlen = 2048, flags = 0)
      SpinelSocketNative.sx_set_nonblock(@fd)
      recvmsg(maxlen, flags)
    end

    def send(data, flags = 0, dest_sockaddr = nil, port = nil)
      if dest_sockaddr || port
        SpinelSocketShim.unsupported("BasicSocket#send destination")
      end
      if flags == 0
        SpinelSocketNative.sp_net_write_str(@fd, data.to_s)
      else
        SpinelSocketNative.sx_send_flags(@fd, data.to_s, flags)
      end
    end

    def sendmsg(data, flags = 0, dest_sockaddr = nil, controls = nil)
      if dest_sockaddr
        SpinelSocketShim.unsupported("BasicSocket#sendmsg destination")
      end
      if controls
        rights = controls.unix_rights
        if rights && rights.length > 0
          return SpinelSocketNative.sx_sendmsg_fd(@fd, data.to_s, rights[0].fileno)
        end
        SpinelSocketShim.unsupported("BasicSocket#sendmsg controls")
      end
      send(data, flags, dest_sockaddr, nil)
    end

    def sendmsg_nonblock(data, flags = 0, dest_sockaddr = nil, controls = nil)
      if dest_sockaddr
        SpinelSocketShim.unsupported("BasicSocket#sendmsg_nonblock destination")
      end
      SpinelSocketNative.sx_set_nonblock(@fd)
      sendmsg(data, flags, dest_sockaddr, controls)
    end

    def write(data)
      SpinelSocketNative.sp_net_write_str(@fd, data.to_s)
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

    def fileno
      @fd
    end

    def to_i
      @fd
    end

    def close_read
      shutdown(Socket::SHUT_RD)
    end

    def close_write
      shutdown(Socket::SHUT_WR)
    end

    def shutdown(how = Socket::SHUT_RDWR)
      SpinelSocketNative.sx_shutdown(@fd, how)
    end

    def getsockname
      packed = SpinelSocketNative.sx_getsockname(@fd)
      return packed if packed && packed != ""
      return Socket.pack_sockaddr_in(@local_port, @local_host) if @local_host && @local_port
      ""
    end

    def getpeername
      packed = SpinelSocketNative.sx_getpeername(@fd)
      return packed if packed && packed != ""
      return Socket.pack_sockaddr_in(@remote_port, @remote_host) if @remote_host && @remote_port
      ""
    end

    def getsockopt(level, optname)
      Socket::Option.int(Socket::AF_UNSPEC, level, optname, SpinelSocketNative.sx_getsockopt_int_str(@fd, level.to_s, optname.to_s))
    end

    def setsockopt(level, optname, optval)
      SpinelSocketNative.sx_setsockopt_int_str(@fd, level.to_s, optname.to_s, optval.to_s)
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
      uid = SpinelSocketNative.sx_getpeereid_uid(@fd)
      gid = SpinelSocketNative.sx_getpeereid_gid(@fd)
      if uid < 0 || gid < 0
        raise "Failed to get peer credentials."
      end
      [uid, gid]
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
      fd = SpinelSocketNative.sx_udp_socket(domain)
      if fd < 0
        raise "Failed to create UDP socket."
      end
      super(fd)
      @socket_family = "udp"
    end

    def bind(host, port)
      rc = SpinelSocketNative.sx_udp_bind(@fd, host.to_s, port)
      if rc < 0
        raise "Failed to bind UDP socket to #{host}:#{port}."
      end
      @local_host = host
      @local_port = port
      0
    end

    def connect(host, port)
      rc = SpinelSocketNative.sx_udp_connect(@fd, host.to_s, port)
      if rc < 0
        raise "Failed to connect UDP socket to #{host}:#{port}."
      end
      @remote_host = host
      @remote_port = port
      0
    end

    def send(data, flags = 0, host = nil, port = nil)
      if host && port
        SpinelSocketNative.sx_udp_sendto(@fd, data.to_s, flags, host.to_s, port)
      else
        SpinelSocketNative.sx_send_flags(@fd, data.to_s, flags)
      end
    end

    def recvfrom_nonblock(maxlen, flags = 0)
      SpinelSocketNative.sx_set_nonblock(@fd)
      data = SpinelSocketNative.sx_udp_recvfrom(@fd, maxlen, flags)
      addr = SpinelSocketNative.sx_last_recvfrom_addr
      [data, addr]
    end
  end

  class UNIXSocket < BasicSocket
    def self.__from_fd(fd, path = nil)
      socket = new(fd)
      socket.__set_path(path || "")
      socket
    end

    def self.pair(type = Socket::SOCK_STREAM, protocol = 0)
      socketpair(type, protocol)
    end

    def self.socketpair(type = Socket::SOCK_STREAM, protocol = 0)
      if type != Socket::SOCK_STREAM || protocol != 0
        SpinelSocketShim.unsupported("UNIXSocket.socketpair type/protocol")
      end
      if SpinelSocketNative.sx_unix_socketpair < 0
        raise "Failed to create UNIX socketpair."
      end
      [__from_fd(SpinelSocketNative.sx_unix_socketpair_first), __from_fd(SpinelSocketNative.sx_unix_socketpair_second)]
    end

    def initialize(path_or_fd)
      if path_or_fd.is_a?(Integer)
        super(path_or_fd)
        @socket_family = "unix"
        @path = ""
      else
        fd = SpinelSocketNative.sx_unix_connect(path_or_fd.to_s)
        if fd < 0
          raise "Failed to connect UNIX socket #{path_or_fd}."
        end
        super(fd)
        @socket_family = "unix"
        @path = path_or_fd
      end
    end

    def __set_path(path)
      @path = path
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
      fd = SpinelSocketNative.sx_recv_fd(@fd)
      if fd < 0
        raise "Failed to receive file descriptor."
      end
      UNIXSocket.__from_fd(fd)
    end

    def send_io(io)
      fd = io.fileno
      rc = SpinelSocketNative.sx_send_fd(@fd, fd)
      if rc < 0
        raise "Failed to send file descriptor."
      end
      0
    end
  end

  class UNIXServer < UNIXSocket
    def initialize(path)
      fd = SpinelSocketNative.sx_unix_server(path.to_s)
      if fd < 0
        raise "Failed to listen on UNIX socket #{path}."
      end
      super(fd)
      @socket_family = "unix_server"
      @path = path
    end

    def accept
      client_fd = SpinelSocketNative.sx_socket_accept(@fd)
      if client_fd < 0
        raise "No pending connection."
      end
      UNIXSocket.__from_fd(client_fd, @path)
    end

    def accept_nonblock
      SpinelSocketNative.sx_set_nonblock(@fd)
      accept
    end

    def listen(backlog)
      SpinelSocketNative.sx_socket_listen_str(@fd, backlog.to_s)
    end

    def sysaccept
      SpinelSocketNative.sx_socket_accept(@fd)
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

    def self.for_fd(fd)
      BasicSocket.for_fd(fd)
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
      socket = UDPSocket.new
      socket.bind(host, port)
      [socket]
    end

    def self.udp_server_loop(host, port)
      udp_server_loop_on(udp_server_sockets(host, port))
    end

    def self.udp_server_loop_on(sockets)
      loop do
        data, sender = udp_server_recv(sockets)
        yield data, sender
      end
    end

    def self.udp_server_recv(sockets)
      sockets[0].recvfrom_nonblock(65535)
    end

    def self.unix(path)
      socket = UNIXSocket.new(path)
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

    def self.unix_server_socket(path)
      UNIXServer.new(path)
    end

    def self.unix_server_loop(path)
      server = UNIXServer.new(path)
      begin
        loop do
          yield server.accept
        end
      ensure
        server.close
      end
    end

    def self.pair(domain = AF_UNIX, socket_type = SOCK_STREAM, protocol = 0)
      socketpair(domain, socket_type, protocol)
    end

    def self.socketpair(domain = AF_UNIX, socket_type = SOCK_STREAM, protocol = 0)
      if domain != AF_UNIX
        SpinelSocketShim.unsupported("Socket.socketpair non-UNIX domain")
      end
      UNIXSocket.socketpair(socket_type, protocol)
    end

    def self.getaddrinfo(host, service, family = nil, socktype = nil, protocol = nil, flags = nil)
      service_value = service || 0
      family_value = family || AF_UNSPEC
      socktype_value = socktype || SOCK_STREAM
      protocol_value = protocol || 0
      flags_value = flags || 0
      info = SpinelSocketNative.sx_getaddrinfo_one(host.to_s, service_value, family_value, socktype_value, protocol_value, flags_value)
      parts = info.split("|")
      sockaddr = parts[0] || Socket.pack_sockaddr_in(service_value, host)
      afamily = (parts[1] || family_value.to_s).to_i
      stype = (parts[2] || socktype_value.to_s).to_i
      proto = (parts[3] || protocol_value.to_s).to_i
      unpacked = unpack_sockaddr_in(sockaddr)
      [["AF_INET", unpacked[0], unpacked[1], sockaddr, afamily, stype, proto]]
    end

    def self.getnameinfo(sockaddr, flags = 0)
      result = SpinelSocketNative.sx_getnameinfo(sockaddr.to_s, flags)
      parts = result.split("|")
      [parts[0] || "", parts[1] || ""]
    end

    def self.gethostbyname(host)
      TCPSocket.gethostbyname(host)
    end

    def self.gethostbyaddr(address, family = AF_INET)
      [address, [], family, address]
    end

    def self.gethostname
      SpinelSocketNative.sx_gethostname
    end

    def self.getifaddrs
      count = SpinelSocketNative.sx_ifaddr_count
      (0...count).map do |index|
        family = SpinelSocketNative.sx_ifaddr_family(index)
        addr = __addrinfo_for_native_ip(family, SpinelSocketNative.sx_ifaddr_addr(index))
        netmask = __addrinfo_for_native_ip(family, SpinelSocketNative.sx_ifaddr_netmask(index))
        broadaddr = __addrinfo_for_native_ip(family, SpinelSocketNative.sx_ifaddr_broadaddr(index))
        dstaddr = __addrinfo_for_native_ip(family, SpinelSocketNative.sx_ifaddr_dstaddr(index))
        Socket::Ifaddr.new(
          SpinelSocketNative.sx_ifaddr_name(index),
          SpinelSocketNative.sx_ifaddr_ifindex(index),
          SpinelSocketNative.sx_ifaddr_flags(index),
          addr,
          netmask,
          broadaddr,
          dstaddr
        )
      end
    end

    def self.ip_address_list
      getifaddrs.map { |ifaddr| ifaddr.addr }.compact
    end

    def self.__addrinfo_for_native_ip(family, address)
      return nil if !address || address == ""
      Addrinfo.new(family, 0, 0, address, 0, nil)
    end

    def self.getservbyname(service, protocol = "tcp")
      SpinelSocketNative.sx_getservbyname_port(service.to_s, protocol.to_s)
    end

    def self.getservbyport(port, protocol = "tcp")
      SpinelSocketNative.sx_getservbyport_name_str(port.to_s, protocol.to_s)
    end

    def self.pack_sockaddr_in(port, host)
      "#{host}:#{port}"
    end

    def self.sockaddr_in(port, host)
      pack_sockaddr_in(port, host)
    end

    def self.unpack_sockaddr_in(sockaddr)
      text = sockaddr.to_s
      parts = text.split(":")
      host = parts[0] || "0.0.0.0"
      port_text = parts[1] || "0"
      [port_text.to_i, host]
    end

    def self.pack_sockaddr_un(path)
      path.to_s
    end

    def self.sockaddr_un(path)
      pack_sockaddr_un(path)
    end

    def self.unpack_sockaddr_un(sockaddr)
      sockaddr.to_s
    end

    def self.native_constants
      [
        SpinelSocketNative.sx_const_af_unspec,
        SpinelSocketNative.sx_const_af_unix,
        SpinelSocketNative.sx_const_af_inet,
        SpinelSocketNative.sx_const_af_inet6,
        SpinelSocketNative.sx_const_sock_stream,
        SpinelSocketNative.sx_const_sock_dgram,
        SpinelSocketNative.sx_const_sol_socket,
        SpinelSocketNative.sx_const_so_reuseaddr,
        SpinelSocketNative.sx_const_so_reuseport,
        SpinelSocketNative.sx_const_tcp_nodelay,
        SpinelSocketNative.sx_const_shut_rd,
        SpinelSocketNative.sx_const_shut_wr,
        SpinelSocketNative.sx_const_shut_rdwr
      ]
    end

    def initialize(domain = AF_INET, socket_type = SOCK_STREAM, protocol = 0)
      if domain == AF_INET && socket_type == SOCK_STREAM && protocol == 0
        fd = SpinelSocketNative.sx_socket_create_tcp
      elsif domain == SpinelSocketNative.sx_const_af_inet6 && socket_type == SOCK_STREAM && protocol == 0
        fd = SpinelSocketNative.sx_socket_create_tcp6
      else
        fd = SpinelSocketNative.sx_socket_create(domain, socket_type, protocol)
      end
      if fd < 0
        raise "Failed to create socket errno=#{SpinelSocketNative.sx_last_errno}."
      end
      super(fd)
      @socket_family = "socket"
      @socket_domain = domain
      @socket_type = socket_type
      @socket_protocol = protocol
    end

    def accept
      client_fd = SpinelSocketNative.sx_socket_accept(@fd)
      if client_fd < 0
        raise "No pending connection."
      end
      [BasicSocket.for_fd(client_fd), SpinelSocketNative.sx_getpeername(client_fd)]
    end

    def accept_nonblock
      SpinelSocketNative.sx_set_nonblock(@fd)
      accept
    end

    def bind(sockaddr)
      rc = SpinelSocketNative.sx_socket_bind(@fd, sockaddr.to_s)
      if rc < 0
        raise "Failed to bind socket."
      end
      0
    end

    def connect(sockaddr)
      rc = SpinelSocketNative.sx_socket_connect(@fd, sockaddr.to_s)
      if rc < 0
        raise "Failed to connect socket."
      end
      0
    end

    def connect_nonblock(sockaddr)
      SpinelSocketNative.sx_set_nonblock(@fd)
      connect(sockaddr)
    end

    def listen(backlog)
      SpinelSocketNative.sx_socket_listen_str(@fd, backlog.to_s)
    end

    def recvfrom(maxlen, flags = 0)
      [recv(maxlen, flags), getpeername]
    end

    def recvfrom_nonblock(maxlen, flags = 0)
      [recv_nonblock(maxlen, flags), getpeername]
    end

    def sysaccept
      SpinelSocketNative.sx_socket_accept(@fd)
    end

    def ipv6only!
      SpinelSocketNative.sx_ipv6only(@fd)
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
    private :connect_internal

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
      nil
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

    def cmsg_is?(level, type, family = nil)
      if family
        @family == family && @level == level && @type == type
      else
        @level == level && @type == type
      end
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
