# sha384sum.rb, compute and check SHA384 message digests (GNU sha384sum, Spinel port).
# Compile: spinel nix_utils/sha384sum.rb -o nix_utils/bin/sha384sum
require "digest"
TOOL_NAME   = "sha384sum"
ALGO_LABEL  = "SHA384"
DIGEST_CALL = ->(data) { Digest::SHA384.hexdigest(data) }
require_relative "checksum_tool"
run_checksum_tool(ARGV)
