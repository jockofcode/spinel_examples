# simple_server.rb

# 1. Declare pure C prototypes at top-level. 
# Spinel uses 'ffi_func' or naked top-level 'extern' for native bindings.
extern "int socket(int domain, int type, int protocol);"
extern "int setsockopt(int sockfd, int level, int optname, void *optval, int optlen);"
extern "int htons(int hostshort);"
extern "int bind(int sockfd, void *addr, int addrlen);"
extern "int listen(int sockfd, int backlog);"
extern "int accept(int sockfd, void *addr, int *addrlen);"
extern "long write(int fd, char *buf, long count);"
extern "int close(int fd);"

# 2. Main Logic — Calling functions globally as native C variants
def start_server(port)
  # POSIX parameters: AF_INET = 2, SOCK_STREAM = 1
  server_fd = socket(2, 1, 0)
  if server_fd < 0
    puts "Failed to create socket."
    return
  end

  # Prevent "Address already in use" errors by setting SO_REUSEADDR (1)
  # We use Spinel's implicit integer pointer mechanics
  opt = 1
  setsockopt(server_fd, 1, 2, opt, 4)

  # Construct a packed sockaddr_in memory buffer: [family(2B), port(2B), IP(4B), zero(8B)]
  network_port = htons(port)
  any_address = 0 # 0.0.0.0
  addr_buffer = [2, network_port, any_address].pack("s>S>L>") + "\x00" * 8

  # Bind the server
  if bind(server_fd, addr_buffer, addr_buffer.bytesize) < 0
    puts "Failed to bind to port #{port}."
    close(server_fd)
    return
  end

  # Listen for incoming requests
  listen(server_fd, 10)
  puts "Server listening natively on http://localhost:#{port}"

  loop do
    # Pass 0/nil equivalents for client metadata to keep types clean
    client_fd = accept(server_fd, nil, nil)
    next if client_fd < 0

    # Build response payload
    body = "<html><body><h1>Hello World from Pure Spinel!</h1></body></html>"
    response = "HTTP/1.1 200 OK\r\n" \
               "Content-Type: text/html\r\n" \
               "Content-Length: #{body.bytesize}\r\n" \
               "Connection: close\r\n" \
               "\r\n" \
               "#{body}"

    # Write payload straight down the file descriptor 
    write(client_fd, response, response.bytesize)
    close(client_fd)
  end
end

# 3. Execution Node
start_server(8080)

