# simple_server_1.rb
#
# Raw Socket example. This one uses the project-local native socket extension
# when compiled with Spinel:
#
#   spinel --link native/socket_ext/socket_ext.c source/simple_server_1.rb -o simple_server_1

require_relative "socket_shim"

port = 8080
arg_index = 0
while arg_index < ARGV.length
  arg = ARGV[arg_index]
  if arg == "-p"
    port_arg = ARGV[arg_index + 1]
    if port_arg
      port = port_arg.to_i
      arg_index = arg_index + 1
    end
  end
  arg_index = arg_index + 1
end

def respond_to_client(client)
  begin
    body = "<html><body><h1>Hello World from raw Socket!</h1></body></html>"
    response = "HTTP/1.1 200 OK\r\n" \
               "Content-Type: text/html\r\n" \
               "Content-Length: #{body.bytesize}\r\n" \
               "Connection: close\r\n" \
               "\r\n" \
               "#{body}"

    client.write(response)
  ensure
    client.close
  end
end

def start_server(port)
  server = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM, 0)
  begin
    server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
    server.bind(Socket.sockaddr_in(port, "0.0.0.0"))
    server.listen(10)
    puts "Raw Socket server listening natively."

    loop do
      accepted = server.accept
      client = accepted[0]
      respond_to_client(client)
    end
  rescue
    puts "Failed to bind to port #{port}."
  ensure
    server.close
  end
end

start_server(port)
