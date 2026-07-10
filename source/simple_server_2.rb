# simple_server_2.rb

module NativeNet
  # OMIT ffi_lib entirely. Spinel automatically resolves internal runtime 
  # symbols from libspinel_rt.a.

  # Define internal C functions directly using Spinel's FFI mapping layout
  ffi_func :sp_net_listen, [:int, :int], :int
  ffi_func :sp_net_accept, [:int], :int
  ffi_func :sp_net_write_str, [:int, :str], :int
  ffi_func :sp_net_close, [:int], :int
end

def start_server(port)
  # Invoke functions strictly under the verified module namespace
  server_fd = NativeNet.sp_net_listen(port, 1)
  
  if server_fd < 0
    puts "Failed to bind to port #{port}."
    return
  end

  puts "Server listening natively on http://localhost:#{port}"

  loop do
    client_fd = NativeNet.sp_net_accept(server_fd)
    next if client_fd < 0

    body = "<html><body><h1>Hello World from real Spinel!</h1></body></html>"
    response = "HTTP/1.1 200 OK\r\n" \
               "Content-Type: text/html\r\n" \
               "Content-Length: #{body.bytesize}\r\n" \
               "Connection: close\r\n" \
               "\r\n" \
               "#{body}"

    NativeNet.sp_net_write_str(client_fd, response)
    NativeNet.sp_net_close(client_fd)
  end
end

start_server(8080)

