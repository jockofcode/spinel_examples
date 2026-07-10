# native_net.rb

module NativeNet
  # Map core socket lifecycle functions
  ffi_func :sp_net_listen, [:int, :int], :int
  ffi_func :sp_net_accept, [:int], :int
  ffi_func :sp_net_close, [:int], :int
  ffi_func :sp_net_write_str, [:int, :str], :int

  # CRITICAL: Maps sp_net_recv_some using the :binstr token.
  # arguments: [int fd, int maxlen], returns: binary-safe String
  ffi_func :sp_net_recv_some, [:int, :int], :binstr
end
