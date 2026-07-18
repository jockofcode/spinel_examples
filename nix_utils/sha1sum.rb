# sha1sum.rb, compute and check SHA1 message digests (GNU sha1sum, Spinel port).
# Compile: spinel nix_utils/sha1sum.rb -o nix_utils/bin/sha1sum
require "digest"
TOOL_NAME   = "sha1sum"
ALGO_LABEL  = "SHA1"
DIGEST_CALL = ->(data) { Digest::SHA1.hexdigest(data) }
require_relative "checksum_tool"
run_checksum_tool(ARGV)
