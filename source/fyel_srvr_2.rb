# fyel_srvr_2.rb, a minimal HTTP "Hello World" over the socket shim.
#
# Step 2 of the FyelSrvr progression: the same idea as fyel_srvr_1.rb but
# using the Ruby-shaped TCPServer from lib/socket_shim.rb instead of raw sockets.
# It writes one fixed HTTP response to every connection, then closes it.
#
# Compile: spinel source/fyel_srvr_2.rb -o bin/fyel_srvr_2
# Run:     ./bin/fyel_srvr_2   (listens on 8080; open http://localhost:8080/)
require_relative "lib/socket_shim"

# Write a single hard-coded HTML response and close the connection. The ensure
# guarantees the socket is closed even if the write raises.
def respond_to_client(client)
  begin
    body = "<html><body><h1>Hello World from real Spinel!</h1></body></html>"
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

# Bind the port and serve every accepted connection with the fixed response.
def start_server(port)
  begin
    TCPServer.open("0.0.0.0", port) do |server|
      puts "Server listening natively."

      loop do
        respond_to_client(server.accept)
      end
    end
  rescue
    puts "Failed to bind to port #{port}."
    return
  end
end

start_server(8080)
