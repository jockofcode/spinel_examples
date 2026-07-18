# sha256sum.rb, compute and check SHA256 message digests (GNU sha256sum, Spinel port).
# Compile: spinel nix_utils/sha256sum.rb -o nix_utils/bin/sha256sum
require "digest"
TOOL_NAME   = "sha256sum"
ALGO_LABEL  = "SHA256"
DIGEST_CALL = ->(data) { Digest::SHA256.hexdigest(data) }
require_relative "checksum_tool"
run_checksum_tool(ARGV)
