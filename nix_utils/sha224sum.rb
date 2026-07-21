# sha224sum.rb, compute and check SHA224 message digests (GNU sha224sum, Spinel port).
# Compile: spinel nix_utils/sha224sum.rb -o nix_utils/bin/sha224sum
require "digest"
require_relative "digest_ext"
TOOL_NAME  = "sha224sum"
ALGO_LABEL = "SHA224"
def compute_digest(data); Digest::SHA224.hexdigest("" + data); end
require_relative "checksum_tool"
run_checksum_tool(ARGV)
