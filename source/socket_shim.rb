# socket_shim.rb

if defined?(RUBY_ENGINE)
  require "socket"
end

if defined?(TCPServer)
  # CRuby already loaded the real socket classes.
else
  module SpinelSocketNative
    ffi_func :sp_net_listen, [:int, :int], :int
    ffi_func :sp_net_accept, [:int], :int
    ffi_func :sp_net_close, [:int], :int
    ffi_func :sp_net_write_str, [:int, :str], :int
    ffi_func :sp_net_recv_some, [:int, :int], :binstr
  end

  class TCPServer
    def self.open(host_or_port, port = nil)
      server = new(host_or_port, port)
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
        @port = port
      else
        @port = host_or_port
      end

      @fd = SpinelSocketNative.sp_net_listen(@port, 1)
      if @fd < 0
        raise "Failed to bind to port #{@port}."
      end
    end

    def accept
      client_fd = SpinelSocketNative.sp_net_accept(@fd)
      while client_fd < 0
        client_fd = SpinelSocketNative.sp_net_accept(@fd)
      end
      TCPSocket.__from_fd(client_fd)
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
  end

  class TCPSocket
    def self.__from_fd(fd)
      new(fd)
    end

    def initialize(fd)
      @fd = fd
      @socket_family = "tcp"
    end

    def recv(maxlen)
      SpinelSocketNative.sp_net_recv_some(@fd, maxlen)
    end

    def readpartial(maxlen)
      recv(maxlen)
    end

    def write(data)
      SpinelSocketNative.sp_net_write_str(@fd, data)
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
  end
end
