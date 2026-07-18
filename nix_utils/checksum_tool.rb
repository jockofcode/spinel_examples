# checksum_tool.rb — shared implementation for md5sum, sha*sum, and cksum.
#
# Callers must set these constants before require_relative'ing this file:
#   TOOL_NAME   — e.g. "sha256sum"
#   ALGO_LABEL  — e.g. "SHA256"
#   DIGEST_CALL — a lambda: ->(data) { Digest::SHA256.hexdigest(data) }
#
# This file also defines ChecksumOptions and the main entry point run_checksum_tool.

require_relative "nix_helpers"

CHECKSUM_USAGE = "Usage: #{TOOL_NAME} [OPTION]... [FILE]...\n" \
  "Print or check #{ALGO_LABEL} checksums.\n" \
  "  -b, --binary        read in binary mode (cosmetic: marks output with *)\n" \
  "  -c, --check         read checksums from FILEs and check them\n" \
  "      --tag           create a BSD-style checksum\n" \
  "  -t, --text          read in text mode (default)\n" \
  "      --ignore-missing  don't fail or report status for missing files\n" \
  "      --quiet         don't print OK for each successfully verified file\n" \
  "      --status        don't output anything; use exit code to show success\n" \
  "      --strict        exit non-zero for improperly formatted checksum lines\n" \
  "  -w, --warn          warn about improperly formatted checksum lines\n" \
  "  --help     display this help and exit\n" \
  "  --version  output version information and exit\n" \
  "  -z/--zero  unsupported (NUL bytes not possible in this build)"

CHECKSUM_VERSION = "#{TOOL_NAME} (nix_utils) 1.0"

class ChecksumOptions
  attr_accessor :binary_mode, :check_mode, :tag_mode, :ignore_missing
  attr_accessor :quiet_verify, :status_only, :strict_mode, :warn_bad
  def initialize
    @binary_mode    = false
    @check_mode     = false
    @tag_mode       = false
    @ignore_missing = false
    @quiet_verify   = false
    @status_only    = false
    @strict_mode    = false
    @warn_bad       = false
  end
end

def parse_checksum_argv(argv)
  opts  = ChecksumOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = coerce(argv[index])
    if options_done || arg == "-"
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts CHECKSUM_USAGE; exit 0
    elsif arg == "--version"
      puts CHECKSUM_VERSION; exit 0
    elsif arg == "-b" || arg == "--binary"
      opts.binary_mode = true
    elsif arg == "-c" || arg == "--check"
      opts.check_mode = true
    elsif arg == "--tag"
      opts.tag_mode = true
    elsif arg == "-t" || arg == "--text"
      opts.binary_mode = false
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
      die("#{TOOL_NAME}: -z/--zero is unsupported in this build (NUL bytes not possible in Spinel C strings)")
    elsif arg[0] != "-"
      files.push(arg)
    else
      die("#{TOOL_NAME}: invalid option -- '#{arg}'\nTry '#{TOOL_NAME} --help' for more information.")
    end
    index += 1
  end
  [opts, files]
end

def format_checksum_line(hash, filename, opts)
  cf = "" + filename
  if opts.tag_mode
    "#{ALGO_LABEL} (#{cf}) = #{hash}"
  else
    mode_char = opts.binary_mode ? "*" : " "
    "#{hash} #{mode_char}#{cf}"
  end
end

# Parse a checksum line; returns [hash, filename] or nil if unrecognized.
def parse_check_line(line)
  s = "" + line
  # BSD tag form: "ALGO (filename) = hash"
  paren_open  = s.index("(")
  paren_close = s.index(")")
  if !paren_open.nil? && !paren_close.nil? && paren_close > paren_open
    eq_pos = s.index(" = ", paren_close)
    unless eq_pos.nil?
      filename = s[paren_open + 1, paren_close - paren_open - 1]
      hash     = s[eq_pos + 3, s.length - eq_pos - 3]
      return [hash, filename]
    end
  end
  # GNU form: "hash  filename" or "hash *filename"
  space = s.index("  ")
  star  = s.index(" *")
  pos   = nil
  if !space.nil? && (star.nil? || space <= star)
    pos = space
    skip = 2
  elsif !star.nil?
    pos = star
    skip = 2
  end
  return nil if pos.nil?
  hash     = s[0, pos]
  filename = s[pos + skip, s.length - pos - skip]
  [hash, filename]
end

def run_check_mode(check_files, opts)
  bad_format = 0
  mismatch   = 0
  missing    = 0
  total_ok   = 0

  check_files.each do |cf|
    ccf = "" + cf
    content = (ccf == "-") ? STDIN.read : File.read(ccf)
    lines = content.split("\n")
    lines.each do |line|
      cline = "" + line
      next if cline == ""
      parsed = parse_check_line(cline)
      if parsed.nil?
        bad_format += 1
        STDERR.puts "#{TOOL_NAME}: WARNING: #{ccf}: #{cline}: improperly formatted checksum line" if opts.warn_bad
        next
      end
      expected_hash = "" + parsed[0]
      filename      = "" + parsed[1]
      unless File.exist?(filename)
        if opts.ignore_missing
          next
        end
        missing += 1
        unless opts.status_only
          puts "#{filename}: MISSING"
        end
        next
      end
      actual_data   = File.read(filename)
      actual_hash   = DIGEST_CALL.call(actual_data)
      if ("" + actual_hash) == expected_hash
        total_ok += 1
        unless opts.status_only || opts.quiet_verify
          puts "#{filename}: OK"
        end
      else
        mismatch += 1
        puts "#{filename}: FAILED" unless opts.status_only
      end
    end
  end

  if bad_format > 0 && opts.strict_mode
    STDERR.puts "#{TOOL_NAME}: WARNING: #{bad_format} line(s) are improperly formatted"
    return 1
  end
  if mismatch > 0
    STDERR.puts "#{TOOL_NAME}: WARNING: #{mismatch} computed checksum(s) did NOT match" unless opts.status_only
    return 1
  end
  if missing > 0
    return 1
  end
  0
end

def run_hash_mode(hash_files, opts)
  exit_code = 0
  hash_files.each do |f|
    cf = "" + f
    if cf == "-"
      data = STDIN.read
      hash = DIGEST_CALL.call(data)
      puts format_checksum_line(hash, "-", opts)
    elsif !File.exist?(cf)
      STDERR.puts "#{TOOL_NAME}: #{cf}: No such file or directory"
      exit_code = 1
    elsif File.directory?(cf)
      STDERR.puts "#{TOOL_NAME}: #{cf}: Is a directory"
      exit_code = 1
    else
      data = File.read(cf)
      hash = DIGEST_CALL.call(data)
      puts format_checksum_line(hash, cf, opts)
    end
  end
  exit_code
end

def run_checksum_tool(argv)
  opts, files = parse_checksum_argv(argv)
  files = ["-"] if files.empty?
  if opts.check_mode
    exit run_check_mode(files, opts)
  else
    exit run_hash_mode(files, opts)
  end
end
