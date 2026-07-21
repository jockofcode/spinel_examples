# md5sum.rb, compute and check MD5 message digests (GNU md5sum, Spinel port).
# Compile: spinel nix_utils/md5sum.rb -o nix_utils/bin/md5sum
require "digest"
require_relative "digest_ext"
TOOL_NAME  = "md5sum"
ALGO_LABEL = "MD5"
def compute_digest(data); Digest::MD5.hexdigest("" + data); end
require_relative "checksum_tool"
run_checksum_tool(ARGV)
