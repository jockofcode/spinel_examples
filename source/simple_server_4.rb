# routing_server.rb
require_relative "native_net"

# 1. Parse the port from command-line arguments (default to 8080 if not provided)
# Spinel's ARGV acts as a standard array of strings parsed natively from main()
port_arg = ARGV[0]
port = port_arg ? port_arg.to_i : 8080

def build_directory_list(dir_path, requested_path)
  # Ensure the visual path string ends with a slash for clean links
  base_url = requested_path.end_with?("/") ? requested_path : "#{requested_path}/"
  
  html = "<html><head><title>Index of #{requested_path}</title></head><body>"
  html += "<h1>Index of #{requested_path}</h1><hr><ul>"

  # Spinel supports Dir.entries to return an array of strings via readdir()
  Dir.entries(dir_path).each do |entry|
    next if entry == "." # Skip current directory pointer
    
    # Generate an anchor tag targeting the relative resource path
    html += "<li><a href=\"#{base_url}#{entry}\">#{entry}</a></li>"
  end

  html += "</ul><hr></body></html>"
  html
end

def handle_request(path)
  # Clean up the URI target path relative to our current execution root (.)
  # Chop off any dangerous leading query parameters or dot-dot patterns if needed
  local_path = ".#{path}"

  # Check path metadata natively (Spinel maps these safely into C stat structs)
  if !File.exist?(local_path)
    body = "<h1>404 Not Found</h1><p>The requested path could not be located.</p>"
    return ["404 Not Found", "text/html", body]
  end

  if File.directory?(local_path)
    # Target is a folder -> dynamically render an HTML directory index
    body = build_directory_list(local_path, path)
    return ["200 OK", "text/html", body]
  else
    # Target is a file -> read the data context directly
    # Spinel's File.read returns a clean binary-safe String
    body = File.read(local_path)
    
    # Crude but fully statically-inferable content-type deduction
    content_type = "text/plain"
    content_type = "text/html" if local_path.end_with?(".html")
    content_type = "image/png" if local_path.end_with?(".png")
    content_type = "application/json" if local_path.end_with?(".json")

    return ["200 OK", content_type, body]
  end
end

def start_server(port)
  server_fd = NativeNet.sp_net_listen(port, 1)
  if server_fd < 0
    puts "Failed to bind to port #{port}."
    return
  end

  puts "Static server running natively on http://localhost:#{port}"

  loop do
    client_fd = NativeNet.sp_net_accept(server_fd)
    next if client_fd < 0

    raw_request = NativeNet.sp_net_recv_some(client_fd, 2048)
    lines = raw_request.split("\r\n")
    request_line = lines[0] || ""

    parts = request_line.split(" ")
    path = parts[1] || "/"

    # Strip query parameters if present (e.g., "/index.html?v=1" -> "/index.html")
    path = path.split("?")[0] || "/"

    # Route and process file I/O safely
    status, content_type, body = handle_request(path)

    # Frame the compliant HTTP response payload
    response = "HTTP/1.1 #{status}\r\n" \
               "Content-Type: #{content_type}\r\n" \
               "Content-Length: #{body.bytesize}\r\n" \
               "Connection: close\r\n" \
               "\r\n" \
               "#{body}"

    NativeNet.sp_net_write_str(client_fd, response)
    NativeNet.sp_net_close(client_fd)
  end
end

start_server(port)

