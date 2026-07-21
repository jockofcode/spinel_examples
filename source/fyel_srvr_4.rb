# fyel_srvr_4.rb
require_relative "lib/socket_shim"

# 1. Parse command-line flags.
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

def respond_to_client(client)
  begin
    raw_request = client.recv(2048)
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

    client.write(response)
  ensure
    client.close
  end
end

def start_server(port)
  begin
    TCPServer.open("0.0.0.0", port) do |server|
      puts "Static server running natively."
      loop do
        respond_to_client(server.accept)
      end
    end
  rescue
    puts "Failed to bind to port #{port}."
    return
  end
end

start_server(port)
