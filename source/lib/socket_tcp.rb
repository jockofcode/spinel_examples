# socket_tcp.rb — minimal TCPServer + TCPSocket for Spinel HTTP servers.
#
# Under CRuby, the first `if` loads real stdlib socket and the second `if`
# skips our FFI definitions, so the file is a no-op shim under CRuby.
#
# Under Spinel, RUBY_ENGINE is not defined so the require is skipped, TCPServer
# is not yet defined, and the second `if` provides our classes backed by the
# five sp_net_* functions built into the Spinel runtime — no external C
# extension and no SPINEL_REQUIRE_GATE needed.

if defined?(RUBY_ENGINE)
  require "socket"
end

if defined?(TCPServer)
  # CRuby: real socket already loaded — nothing to do.
else
  module SpinelTCP
    ffi_func :sp_net_listen,    [:int, :int], :int
    ffi_func :sp_net_accept,    [:int],       :int
    ffi_func :sp_net_recv_some, [:int, :int], :binstr
    ffi_func :sp_net_write_str, [:int, :str], :int
    ffi_func :sp_net_close,     [:int],       :int
  end

  class TCPSocket
    def initialize(fd)
      @fd = fd
    end

    def self.__from_fd(fd)
      new(fd)
    end

    def recv(maxlen)
      SpinelTCP.sp_net_recv_some(@fd, maxlen)
    end

    def write(data)
      SpinelTCP.sp_net_write_str(@fd, data.to_s)
    end

    def close
      SpinelTCP.sp_net_close(@fd)
    end
  end

  # TCPServer inherits from TCPSocket so Spinel treats it as a user-defined
  # Ruby object rather than mapping it to the built-in sp_TCPServer C struct.
  # Without the inheritance, Spinel generates invalid NULL-struct initialization
  # in ensure blocks.
  class TCPServer < TCPSocket
    def initialize(host_or_port, port = nil)
      local_port = port ? port : host_or_port
      fd = SpinelTCP.sp_net_listen(local_port, 1)
      raise "Failed to bind port #{local_port}." if fd < 0
      super(fd)
    end

    def accept
      fd = SpinelTCP.sp_net_accept(@fd)
      fd = SpinelTCP.sp_net_accept(@fd) while fd < 0
      TCPSocket.__from_fd(fd)
    end

    def self.open(host, port)
      server = new(host, port)
      begin
        yield server
      ensure
        server.close
      end
    end
  end
end
