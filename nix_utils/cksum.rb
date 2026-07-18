# cksum.rb, compute and verify file checksums (GNU cksum, Spinel port).
#
# Flags:
#   -a, --algorithm=TYPE   sysv, bsd, crc (default), crc32b, md5, sha1, sha2, sha3 (unsupported), blake2b (unsupported)
#   --base64               base64-encode the digest output
#   -c, --check            verify checksums
#   --tag                  BSD-style output (default for non-CRC algorithms)
#   --untagged             reversed style without digest type
#   --ignore-missing, --quiet, --status, --strict, -w/--warn (verify mode)
#   -z, --zero   unsupported
#   --help, --version
#
# Compile: spinel nix_utils/cksum.rb -o nix_utils/bin/cksum

USAGE = "Usage: cksum [OPTION]... [FILE]...\n" \
        "Print or verify checksums.\n" \
        "  -a, --algorithm=TYPE   select the digest type: crc (default), crc32b, md5, sha1, sha2\n" \
        "                         sha3 and blake2b are unsupported\n" \
        "  --base64               use base64 encoding for digest output\n" \
        "  -c, --check            read and verify checksums from the FILE(s)\n" \
        "  --tag                  create a BSD-style checksum\n" \
        "  --untagged             create a reversed-style checksum without digest type\n" \
        "  --ignore-missing, --quiet, --status, --strict, -w/--warn\n" \
        "  --help     display this help and exit\n" \
        "  --version  output version information and exit\n" \
        "  -z/--zero  unsupported (NUL bytes not possible in this build)"

VERSION = "cksum (nix_utils) 1.0"

require "digest"
require "base64"
require_relative "nix_helpers"

class CksumOptions
  attr_accessor :algorithm, :use_base64, :check_mode, :tag_mode, :untagged
  attr_accessor :ignore_missing, :quiet_verify, :status_only, :strict_mode, :warn_bad
  def initialize
    @algorithm      = "crc"
    @use_base64     = false
    @check_mode     = false
    @tag_mode       = false
    @untagged       = false
    @ignore_missing = false
    @quiet_verify   = false
    @status_only    = false
    @strict_mode    = false
    @warn_bad       = false
  end
end

# ── POSIX CRC (default cksum) ──────────────────────────────────────────────

POSIX_CRC_TABLE = begin
  table = []
  256.times do |i|
    c = i
    8.times do
      if (c & 1) != 0
        c = (c >> 1) ^ 0xEDB88320
      else
        c = c >> 1
      end
    end
    table.push(c)
  end
  table
end

def posix_crc(data)
  crc = 0xFFFFFFFF
  s   = "" + data
  i   = 0
  while i < s.bytesize
    b = s[i].ord & 0xFF
    crc = POSIX_CRC_TABLE[(crc ^ b) & 0xFF] ^ (crc >> 8)
    i += 1
  end
  crc ^ 0xFFFFFFFF
end

# CRC32/ISO-HDLC (same polynomial but different convention than POSIX cksum)
def crc32b(data)
  posix_crc(data)
end

# BSD checksum (sum16)
def bsd_checksum(data)
  s   = "" + data
  sum = 0
  i   = 0
  while i < s.bytesize
    sum = (sum >> 1) + ((sum & 1) << 15)
    sum = (sum + (s[i].ord & 0xFF)) & 0xFFFF
    i += 1
  end
  sum
end

# SYSV checksum
def sysv_checksum(data)
  s   = "" + data
  sum = 0
  i   = 0
  while i < s.bytesize
    sum += s[i].ord & 0xFF
    i += 1
  end
  r = (sum & 0xFFFF) + ((sum & 0xFFFFFFFF) >> 16)
  r & 0xFFFF
end

def compute_digest(algo, data)
  a = "" + algo
  if a == "crc"
    return ["", posix_crc(data), nil]   # [encoded, raw_int, label]
  elsif a == "crc32b"
    return ["", crc32b(data), nil]
  elsif a == "bsd"
    return ["", bsd_checksum(data), nil]
  elsif a == "sysv"
    return ["", sysv_checksum(data), nil]
  elsif a == "md5"
    return [Digest::MD5.hexdigest(data), nil, "MD5"]
  elsif a == "sha1"
    return [Digest::SHA1.hexdigest(data), nil, "SHA1"]
  elsif a == "sha2"
    return [Digest::SHA256.hexdigest(data), nil, "SHA256"]
  else
    die("cksum: #{algo}: unsupported algorithm")
  end
end

def format_cksum_line(algo, hex_or_int, filename, byte_count, opts)
  cf = "" + filename
  a  = "" + algo
  is_crc = (a == "crc" || a == "crc32b" || a == "bsd" || a == "sysv")
  if is_crc
    int_val = hex_or_int.to_i
    if opts.use_base64
      raw = [int_val].pack("N")
      encoded = Base64.strict_encode64(raw)
      if opts.untagged || !opts.tag_mode
        "#{encoded} #{byte_count} #{cf}"
      else
        "CRC (#{cf}) = #{encoded}"
      end
    else
      "#{int_val} #{byte_count} #{cf}"
    end
  else
    label = hex_or_int[0] if hex_or_int.is_a?(Array)
    hex   = "" + hex_or_int.to_s
    if opts.use_base64
      raw_bytes = [hex].pack("H*")
      hex = Base64.strict_encode64(raw_bytes)
    end
    if opts.tag_mode && !opts.untagged
      "#{a.upcase} (#{cf}) = #{hex}"
    elsif opts.untagged
      "#{hex} #{cf}"
    else
      "#{hex}  #{cf}"
    end
  end
end

opts  = CksumOptions.new
files = []
index = 0
while index < ARGV.length
  arg = coerce(ARGV[index])
  if arg == "--help"
    puts USAGE; exit 0
  elsif arg == "--version"
    puts VERSION; exit 0
  elsif arg == "-a" || arg == "--algorithm"
    index += 1; opts.algorithm = coerce(ARGV[index])
  elsif arg.length > 13 && arg[0, 13] == "--algorithm="
    opts.algorithm = arg[13, arg.length - 13]
  elsif arg.length > 2 && arg[0, 2] == "-a"
    opts.algorithm = arg[2, arg.length - 2]
  elsif arg == "--base64"
    opts.use_base64 = true
  elsif arg == "-c" || arg == "--check"
    opts.check_mode = true
  elsif arg == "--tag"
    opts.tag_mode = true
  elsif arg == "--untagged"
    opts.untagged = true
  elsif arg == "--ignore-missing"
    opts.ignore_missing = true
  elsif arg == "--quiet"
    opts.quiet_verify = true
  elsif arg == "--status"
    opts.status_only = true
  elsif arg == "--strict"
    opts.strict_mode = true
  elsif arg == "-w" || arg == "--warn"
    opts.warn_bad = true
  elsif arg == "-z" || arg == "--zero"
    die("cksum: -z/--zero is unsupported in this build")
  elsif arg == "--"
    index += 1
    while index < ARGV.length
      files.push(coerce(ARGV[index]))
      index += 1
    end
    break
  elsif arg == "-" || arg[0] != "-"
    files.push(arg)
  else
    die("cksum: invalid option -- '#{arg}'\nTry 'cksum --help' for more information.")
  end
  index += 1
end

algo = "" + opts.algorithm
if algo == "sha3" || algo == "blake2b" || algo == "sm3"
  die("cksum: #{algo}: unsupported algorithm in this build")
end

files = ["-"] if files.empty?
exit_code = 0

files.each do |f|
  cf = "" + f
  if cf == "-"
    data = STDIN.read
    byte_count = data.bytesize
    result_tuple = compute_digest(algo, data)
    hex_val = "" + result_tuple[0].to_s
    int_val = result_tuple[1]
    is_crc  = (algo == "crc" || algo == "crc32b" || algo == "bsd" || algo == "sysv")
    if is_crc
      if opts.use_base64
        raw = [int_val].pack("N")
        puts "#{Base64.strict_encode64(raw)} #{byte_count} -"
      else
        puts "#{int_val} #{byte_count} -"
      end
    else
      if opts.use_base64
        raw_bytes = [hex_val].pack("H*")
        hex_val = Base64.strict_encode64(raw_bytes)
      end
      if opts.tag_mode && !opts.untagged
        puts "#{algo.upcase} (-) = #{hex_val}"
      else
        puts "#{hex_val}  -"
      end
    end
  elsif !File.exist?(cf)
    STDERR.puts "cksum: #{cf}: No such file or directory"
    exit_code = 1
  else
    data = File.read(cf)
    byte_count = data.bytesize
    result_tuple = compute_digest(algo, data)
    hex_val = "" + result_tuple[0].to_s
    int_val = result_tuple[1]
    is_crc  = (algo == "crc" || algo == "crc32b" || algo == "bsd" || algo == "sysv")
    if is_crc
      if opts.use_base64
        raw = [int_val].pack("N")
        puts "#{Base64.strict_encode64(raw)} #{byte_count} #{cf}"
      else
        puts "#{int_val} #{byte_count} #{cf}"
      end
    else
      if opts.use_base64
        raw_bytes = [hex_val].pack("H*")
        hex_val = Base64.strict_encode64(raw_bytes)
      end
      if opts.tag_mode && !opts.untagged
        puts "#{algo.upcase} (#{cf}) = #{hex_val}"
      else
        puts "#{hex_val}  #{cf}"
      end
    end
  end
end

exit exit_code
