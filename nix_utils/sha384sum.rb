# sha384sum.rb, compute and check SHA384 message digests (GNU sha384sum, Spinel port).
# Compile: spinel nix_utils/sha384sum.rb -o nix_utils/bin/sha384sum
require "digest"
require_relative "digest_ext"
TOOL_NAME  = "sha384sum"
ALGO_LABEL = "SHA384"
def compute_digest(data); Digest::SHA384.hexdigest("" + data); end
require_relative "checksum_tool"
run_checksum_tool(ARGV)
