# sha512sum.rb, compute and check SHA512 message digests (GNU sha512sum, Spinel port).
# Compile: spinel nix_utils/sha512sum.rb -o nix_utils/bin/sha512sum
require "digest"
TOOL_NAME   = "sha512sum"
ALGO_LABEL  = "SHA512"
DIGEST_CALL = ->(data) { Digest::SHA512.hexdigest(data) }
require_relative "checksum_tool"
run_checksum_tool(ARGV)
