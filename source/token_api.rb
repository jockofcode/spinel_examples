# token_api.rb, a tiny JSON REST API with HMAC-signed bearer tokens.
#
# Real backend patterns with no framework, compiled to one binary: a hand-rolled
# accept loop over lib/socket_shim.rb, JSON request/response bodies, and
# authentication tokens signed with HMAC-SHA256. The signing goes through
# Spinel's sp_crypto runtime via a small FFI module; under CRuby the same file
# falls back to OpenSSL so it runs unmodified with `ruby`.
#
# Compile: SPINEL_REQUIRE_GATE=1 spinel source/token_api.rb -o bin/token_api
# Run:
#   ./bin/token_api -p 8124
#   TOKEN=$(curl -s -XPOST localhost:8124/login -d '{"user":"matz"}' | ...)
#   curl -H "Authorization: Bearer $TOKEN" localhost:8124/notes
#
require_relative "lib/socket_shim"
require "json"

# SECRET signs every token. In production this would be injected from the
# environment or a secrets manager, never committed, it is a literal here
# only to keep the example self-contained.
SECRET = "spinel-demo-secret-do-not-ship"

# --- crypto: one interface, two backends --------------------------------
#
# Spinel and CRuby produce byte-identical tokens (verified: HMAC-SHA256 then
# base64url without padding), so a token minted under one runtime validates
# under the other.
if defined?(RUBY_ENGINE)
  # CRuby path: real OpenSSL + Base64.
  require "openssl"
  require "base64"
  require "securerandom"

  module Crypto
    def self.hmac_b64url(key, msg)
      Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", key, msg), padding: false)
    end

    def self.random_b64url(n)
      Base64.urlsafe_encode64(SecureRandom.bytes(n), padding: false)
    end
  end
else
  # Spinel path: FFI into the always-linked sp_crypto runtime.
  module SpinelToken
    ffi_func :sp_crypto_hmac_sha256_b64url, [:str, :str], :str
    ffi_func :sp_crypto_random_b64url, [:int], :str
  end

  module Crypto
    # IMPORTANT: sp_crypto_* return static C buffers that the next crypto call
    # overwrites. We copy each result into a fresh Ruby string (#dup) so a
    # held value survives a later call. Cheap insurance; costs one allocation.
    def self.hmac_b64url(key, msg)
      SpinelToken.sp_crypto_hmac_sha256_b64url(key, msg).dup
    end

    def self.random_b64url(n)
      SpinelToken.sp_crypto_random_b64url(n).dup
    end
  end
end

# A token is "payload.signature": the user name, then its HMAC under SECRET.
# Recomputing the signature and comparing is the whole verification story
# (production would use a constant-time compare to resist timing attacks).
def make_token(user)
  sig = Crypto.hmac_b64url(SECRET, user)
  "#{user}.#{sig}"
end

# Return the verified user name for a token, or nil if it is malformed or the
# signature does not match. We split on "." into exactly two parts; splitting
# (rather than String#index arithmetic) keeps the element types simple for the
# compiler when the token arrives as a freshly built runtime string.
def verify_token(token)
  return nil if token.nil?
  # The token arrives as a poly-typed string sliced out of an HTTP header. In
  # this whole-program inference context Spinel dispatches only single-index
  # String#[] and #length on that value (not #index, #split, or range slices),
  # so we walk it one character at a time: everything before the first "." is
  # the user, everything after is the signature. Building the two parts by
  # char-concatenation keeps us on the operations that dispatch reliably.
  length = token.length
  user = ""
  sig = ""
  seen_dot = false
  char_index = 0
  while char_index < length
    char = token[char_index]
    if !seen_dot && char == "."
      seen_dot = true
    elsif seen_dot
      sig = sig + char
    else
      user = user + char
    end
    char_index += 1
  end
  return nil unless seen_dot
  return nil if user == "" || sig == ""
  expected = Crypto.hmac_b64url(SECRET, user)
  sig == expected ? user : nil
end


# --- in-memory data ------------------------------------------------------

# Notes are a Hash keyed by integer id. Seeded with two entries; a counter
# hands out new ids. This is process-local state, restarting the server
# resets it, which is fine for a demo.
$notes = {
  1 => { "id" => 1, "text" => "matz says: optimize for programmer happiness" },
  2 => { "id" => 2, "text" => "spinel compiles this to a native binary" }
}
$next_id = 3

# --- HTTP helpers --------------------------------------------------------

# Build a complete HTTP response from a status line and a Ruby object, which is
# always serialized as JSON. Content-Length uses bytesize so multibyte bodies
# are framed correctly.
def json_response(status, obj)
  body = JSON.generate(obj)
  "HTTP/1.1 #{status}\r\n" \
    "Content-Type: application/json\r\n" \
    "Content-Length: #{body.bytesize}\r\n" \
    "Connection: close\r\n" \
    "\r\n" \
    "#{body}"
end

# Pull the bearer token out of an Authorization header, or nil if absent.
# We tokenize the header line by spaces, the same split-based parsing the
# other servers use on the request line, so a line like
# "Authorization: Bearer <token>" yields ["Authorization:", "Bearer", token].
# The field-name match is case-insensitive.
def bearer_token(headers)
  headers.each do |line|
    words = line.split(" ")
    name = (words[0] || "").downcase
    if name == "authorization:" && words[1] == "Bearer"
      return words[2]
    end
  end
  nil
end

# Route one request to a response. method/path come from the request line;
# headers is the array of header lines; body is the raw request body (the
# substring after the blank line), parsed as JSON where a route needs it.
def route(method, path, headers, body)
  if method == "POST" && path == "/login"
    data = JSON.parse(body == "" ? "{}" : body)
    user = data["user"]
    return json_response("400 Bad Request", { "error" => "user required" }) if user.nil? || user == ""
    return json_response("200 OK", { "token" => make_token(user) })
  end

  if path == "/notes"
    user = verify_token(bearer_token(headers))
    return json_response("401 Unauthorized", { "error" => "unauthorized" }) if user.nil?

    if method == "GET"
      list = []
      $notes.keys.sort.each { |id| list.push($notes[id]) }
      return json_response("200 OK", { "notes" => list })
    end

    if method == "POST"
      data = JSON.parse(body == "" ? "{}" : body)
      text = data["text"]
      return json_response("400 Bad Request", { "error" => "text required" }) if text.nil? || text == ""
      note = { "id" => $next_id, "text" => text }
      $notes[$next_id] = note
      $next_id += 1
      return json_response("201 Created", note)
    end
  end

  json_response("404 Not Found", { "error" => "not found" })
end


# --- connection handling + accept loop -----------------------------------

# Handle one client: read the request, split headers from body at the blank
# line, parse the request line, route it, and write the JSON response. The
# socket is always closed via ensure.
def handle_client(client)
  begin
    raw = client.recv(4096)
    raw = "" if raw.nil?

    # Headers and body are separated by a blank line (CRLFCRLF).
    split_at = raw.index("\r\n\r\n")
    if split_at.nil?
      head = raw
      body = ""
    else
      head = raw[0...split_at]
      body = raw[(split_at + 4)..-1] || ""
    end

    lines = head.split("\r\n")
    request_line = lines[0] || ""
    # Header lines are every line after the request line. Build the list with
    # an explicit loop so it is unambiguously a String array (a `|| []`
    # fallback would introduce an empty Integer array and a type mismatch).
    headers = []
    header_index = 1
    while header_index < lines.length
      headers.push(lines[header_index])
      header_index += 1
    end

    parts = request_line.split(" ")
    method = parts[0] || "GET"
    path = parts[1] || "/"
    path = path.split("?")[0] || "/"

    client.write(route(method, path, headers, body))
  ensure
    client.close
  end
end

# Parse -p PORT with a manual ARGV loop, matching fyel_srvr_6.rb's
# dependency-free style. port stays an Integer throughout (we assign the
# parsed value via .to_i) so codegen keeps a stable numeric type.
port = 8080
arg_index = 0
while arg_index < ARGV.length
  if ARGV[arg_index] == "-p"
    port_value = ARGV[arg_index + 1]
    if port_value
      port = "#{port_value}".to_i
      arg_index += 1
    end
  end
  arg_index += 1
end
port_str = "#{port}"

# Single-threaded accept loop: one request per connection, then close.
begin
  TCPServer.open("0.0.0.0", port) do |server|
    puts "token_api listening on http://0.0.0.0:#{port_str}"
    loop do
      client = server.accept
      handle_client(client)
    end
  end
rescue => e
  STDERR.puts "server error: #{e.message}"
  exit 1
end
