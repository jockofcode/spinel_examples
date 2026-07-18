# sha224sum.rb, compute and check SHA224 message digests (GNU sha224sum, Spinel port).
# Compile: spinel nix_utils/sha224sum.rb -o nix_utils/bin/sha224sum
require "digest"
TOOL_NAME   = "sha224sum"
ALGO_LABEL  = "SHA224"
DIGEST_CALL = ->(data) { Digest::SHA2.new(224).hexdigest(data) }
require_relative "checksum_tool"
run_checksum_tool(ARGV)
