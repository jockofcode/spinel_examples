# simple_server_3.rb

require_relative "socket_shim"

def respond_to_client(client)
  begin
    # Read up to 2048 bytes cleanly.
    # Because of :binstr, this returns a robust Ruby String containing the full payload.
    raw_request = client.recv(2048)

    # 1. Parse the HTTP Request Line (e.g., "GET /about HTTP/1.1\r\n")
    # We split by carriage return/line feed to isolate the first line.
    lines = raw_request.split("\r\n")
    request_line = lines[0] || ""

    # 2. Extract the path segment via String splitting
    # Splitting "GET /about HTTP/1.1" by space gives ["GET", "/about", "HTTP/1.1"]
    parts = request_line.split(" ")
    method = parts[0] || "GET"
    path   = parts[1] || "/"

    # 3. Micro Routing Logic Engine
    # Statically analyzable if/elsif routing mapping block
    if path == "/"
      body = "<h1>Welcome to the Homepage</h1><p>Served natively by Spinel.</p>"
      status = "200 OK"
    elsif path == "/about"
      body = "<h1>About Us</h1><p>This is a binary compiled entirely without an external VM.</p>"
      status = "200 OK"
    elsif path == "/api/status"
      body = '{"status":"green","compiler":"spinel"}'
      status = "200 OK"
    else
      body = "<h1>404 Not Found</h1><p>The page #{path} does not exist.</p>"
      status = "404 Not Found"
    end

    # Determine Content-Type format dynamically based on path prefix
    content_type = path.start_with?("/api") ? "application/json" : "text/html"

    # Assemble raw compliant HTTP frame
    response = "HTTP/1.1 #{status}\r\n" \
               "Content-Type: #{content_type}\r\n" \
               "Content-Length: #{body.bytesize}\r\n" \
               "Connection: close\r\n" \
               "\r\n" \
               "#{body}"

    # Return response payload and terminate the socket context
    client.write(response)
  ensure
    client.close
  end
end

def start_server(port)
  begin
    TCPServer.open("0.0.0.0", port) do |server|
      puts "Advanced routing server live."

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
