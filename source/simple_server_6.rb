# simple_server_6.rb
require_relative "native_net"

port = 8080
if ARGV.length > 0
  arg_str = ARGV[0].to_s
  if arg_str != ""
    port = arg_str.to_i
  end
end

def sanitize_path(raw_path)
  clean = raw_path.gsub("\\", "/")
  segments = clean.split("/")
  safe_segments = []
  
  segments.each do |segment|
    next if segment == "" || segment == "."
    if segment == ".."
      safe_segments.pop
    else
      safe_segments.push(segment)
    end
  end
  "/" + safe_segments.join("/")
end

def format_file_size(bytes)
  if bytes < 1024
    return "#{bytes} B"
  elsif bytes < 1048576
    kb = bytes / 1024
    remainder = (bytes % 1024) * 10 / 1024
    return "#{kb}.#{remainder} KB"
  else
    mb = bytes / 1048576
    remainder = (bytes % 1048576) * 10 / 1048576
    return "#{mb}.#{remainder} MB"
  end
end

def build_directory_list(dir_path, requested_path)
  base_url = requested_path.end_with?("/") ? requested_path : "#{requested_path}/"
  
  folder_svg = '<svg xmlns="http://w3.org" viewBox="0 0 24 24" width="18" height="18" fill="#e2a741" style="vertical-align: middle; margin-right: 8px;"><path d="M10 4H4c-1.11 0-1.99.89-1.99 2L2 18c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2h-8l-2-2z"/></svg>'
  file_svg   = '<svg xmlns="http://w3.org" viewBox="0 0 24 24" width="18" height="18" fill="#718096" style="vertical-align: middle; margin-right: 8px;"><path d="M14 2H6c-1.1 0-1.99.89-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.89 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z"/></svg>'
  up_dir_svg = '<svg xmlns="http://w3.org" viewBox="0 0 24 24" width="18" height="18" fill="#4a5568" style="vertical-align: middle; margin-right: 8px;"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>'

  html = "<html><head><title>Index of #{requested_path}</title>"
  html += "<style>body{font-family:sans-serif;padding:20px;background:#f7fafc;color:#2d3748;} ul{list-style:none;padding:0;} li{padding:8px;display:flex;align-items:center;border-bottom:1px solid #e2e8f0;} .meta{margin-left:auto;color:#718096;font-size:14px;} a{color:#2b6cb0;text-decoration:none;} a:hover{text-decoration:underline;}</style>"
  html += "</head><body>"
  html += "<h1>Index of #{requested_path}</h1><hr><ul>"

  # CONDITION 1: Inject a parent directory link if we are not at the application root folder
  if requested_path != "/" && requested_path != ""
    # Compute parent path relative to current requested URL path
    path_parts = requested_path.split("/")
    path_parts.pop # Remove current trailing folder segment
    parent_path = path_parts.join("/")
    parent_path = "/" if parent_path == ""
    
    html += "<li>#{up_dir_svg}<a href=\"#{parent_path}\"><strong>.. (Parent Directory)</strong></a><span class=\"meta\">[UP]</span></li>"
  end

  Dir.entries(dir_path).each do |entry|
    next if entry == "." || entry == ".."
    
    full_entry_path = "#{dir_path}/#{entry}"
    
    if File.directory?(full_entry_path)
      icon = folder_svg
      size_label = "[DIR]"
    else
      icon = file_svg
      byte_count = File.size(full_entry_path)
      size_label = format_file_size(byte_count)
    end
    
    html += "<li>#{icon}<a href=\"#{base_url}#{entry}\">#{entry}</a><span class=\"meta\">#{size_label}</span></li>"
  end

  html += "</ul><hr></body></html>"
  html
end

def serve_file_payload(local_path)
  body = File.read(local_path)
  
  content_type = "application/octet-stream"
  is_web_file = false

  if local_path.end_with?(".html") || local_path.end_with?(".htm")
    content_type = "text/html"
    is_web_file = true
  elsif local_path.end_with?(".css")
    content_type = "text/css"
    is_web_file = true
  elsif local_path.end_with?(".js")
    content_type = "application/javascript"
    is_web_file = true
  elsif local_path.end_with?(".png")
    content_type = "image/png"
    is_web_file = true
  elsif local_path.end_with?(".jpg") || local_path.end_with?(".jpeg")
    content_type = "image/jpeg"
    is_web_file = true
  elsif local_path.end_with?(".svg")
    content_type = "image/svg+xml"
    is_web_file = true
  elsif local_path.end_with?(".json")
    content_type = "application/json"
    is_web_file = true
  elsif local_path.end_with?(".txt")
    content_type = "text/plain"
    is_web_file = true
  end

  if is_web_file
    disposition = "inline"
  else
    file_name = local_path.split("/")[-1] || "download"
    disposition = "attachment; filename=\"#{file_name}\""
  end

  ["200 OK", content_type, disposition, body]
end

def handle_request(path)
  safe_url_path = sanitize_path(path)
  local_path = ".#{safe_url_path}"

  if !File.exist?(local_path)
    body = "<h1>404 Not Found</h1><p>The requested path could not be located safely.</p>"
    return ["404 Not Found", "text/html", "inline", body]
  end

  if File.directory?(local_path)
    # CONDITION 2: Check for automatic index.html interception
    # We strip any duplicated slashes to ensure paths map cleanly to disk
    separator = local_path.end_with?("/") ? "" : "/"
    index_html_path = "#{local_path}#{separator}index.html"
    
    if File.exist?(index_html_path) && !File.directory?(index_html_path)
      # Silently route to the index.html payload instead of displaying a directory listing
      return serve_file_payload(index_html_path)
    else
      body = build_directory_list(local_path, safe_url_path)
      return ["200 OK", "text/html", "inline", body]
    end
  else
    return serve_file_payload(local_path)
  end
end

def start_server(port)
  server_fd = NativeNet.sp_net_listen(port, 1)
  if server_fd < 0
    puts "Failed to bind to port #{port}."
    return
  end

  puts "Static file server running natively on http://localhost:#{port}"

  loop do
    client_fd = NativeNet.sp_net_accept(server_fd)
    next if client_fd < 0

    raw_request = NativeNet.sp_net_recv_some(client_fd, 2048)
    lines = raw_request.split("\r\n")
    request_line = lines[0] || ""

    parts = request_line.split(" ")
    path = parts[1] || "/"
    path = path.split("?")[0] || "/"

    status, content_type, disposition, body = handle_request(path)

    response = "HTTP/1.1 #{status}\r\n" \
               "Content-Type: #{content_type}\r\n" \
               "Content-Disposition: #{disposition}\r\n" \
               "Content-Length: #{body.bytesize}\r\n" \
               "Connection: close\r\n" \
               "\r\n" \
               "#{body}"

    NativeNet.sp_net_write_str(client_fd, response)
    NativeNet.sp_net_close(client_fd)
  end
end

start_server(port)

