# workaround_openssl_shim_test.rb
#
# Probes whether Spinel supports require "openssl" with OpenSSL::HMAC,
# Base64.urlsafe_encode64, and SecureRandom.bytes — which would make the
# sp_crypto FFI shim in source/token_api.rb unnecessary.
#
# The shim exists because Spinel only provides SHA1 and SHA256 hashing via its
# sp_crypto runtime; it does not expose an OpenSSL-compatible API.
#
# If this prints WORKAROUND RESOLVED:
#   Remove the `if defined?(RUBY_ENGINE) ... else ... end` Crypto block in
#   source/token_api.rb and use the OpenSSL path unconditionally.

ok = false
begin
  require "openssl"
  require "base64"
  require "securerandom"
  ok = defined?(OpenSSL::HMAC) == "constant" &&
       Base64.respond_to?(:urlsafe_encode64) &&
       SecureRandom.respond_to?(:bytes)
rescue
  ok = false
end

if ok
  puts "WORKAROUND RESOLVED: openssl_crypto_shim"
  puts "  Spinel now supports require 'openssl'."
  puts "  In source/token_api.rb, remove the if/else Crypto shim and keep"
  puts "  only the OpenSSL::HMAC-based Crypto module for both runtimes."
else
  puts "openssl_crypto_shim:still_needed"
end
