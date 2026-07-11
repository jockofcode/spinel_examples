# simple_server_2.rb
require_relative "socket_shim"

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
