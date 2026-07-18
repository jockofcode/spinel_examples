# nix_helpers.rb — shared helpers for nix_utils tools (Spinel-compatible).
#
# require_relative "nix_helpers" at the top of any tool that uses these.
# All methods are module-level (not inside a class) so callers can use them
# directly without namespace qualification.

# ── Spinel sp_RbVal workarounds ────────────────────────────────────────────

# Force a Spinel sp_RbVal to a concrete const char* string.
# Call whenever a string arrives from ARGV, array indexing, or a method
# return value that crosses a function boundary.
def coerce(s)
  "" + s
end

# Coerce every element of an array-typed argument list.
def argv_coerce(arr)
  result = []
  arr.each { |s| result.push("" + s) }
  result
end

# ── I/O helpers ────────────────────────────────────────────────────────────

# Read from a file or stdin. "-" means stdin.
def read_source(name)
  cname = "" + name
  return STDIN.read if cname == "-"
  File.read(cname)
end

# Print msg to STDERR and exit with code.
def die(msg, code = 1)
  STDERR.puts msg
  exit code
end

# Print a "==> NAME <==" file header, with a blank separator before all but
# the first. Returns false so callers can track `first` in a single line.
def print_file_header(name, first)
  puts "" unless first
  label = (("" + name) == "-") ? "standard input" : ("" + name)
  puts "==> #{label} <=="
  false
end

# ── Size suffix parsing ─────────────────────────────────────────────────────

# Parse an integer with optional K/M/G/KiB/MiB/GiB/kB/MB/GB/b suffix.
# Returns the integer byte count. Used by head, tail, split, du, numfmt, etc.
def parse_size_suffix(text)
  t = "" + text
  if t.end_with?("KiB")
    return t[0, t.length - 3].to_i * 1024
  elsif t.end_with?("MiB")
    return t[0, t.length - 3].to_i * 1024 * 1024
  elsif t.end_with?("GiB")
    return t[0, t.length - 3].to_i * 1024 * 1024 * 1024
  elsif t.end_with?("kB") || t.end_with?("KB")
    return t[0, t.length - 2].to_i * 1000
  elsif t.end_with?("MB")
    return t[0, t.length - 2].to_i * 1000 * 1000
  elsif t.end_with?("GB")
    return t[0, t.length - 2].to_i * 1000 * 1000 * 1000
  elsif t.end_with?("K")
    return t[0, t.length - 1].to_i * 1024
  elsif t.end_with?("M")
    return t[0, t.length - 1].to_i * 1024 * 1024
  elsif t.end_with?("G")
    return t[0, t.length - 1].to_i * 1024 * 1024 * 1024
  elsif t.end_with?("b")
    return t[0, t.length - 1].to_i * 512
  else
    return t.to_i
  end
end

# Format a byte count as a human-readable string (e.g. 1.5K, 2.3M).
# si: true uses 1000-based divisors; false (default) uses 1024.
def format_human(bytes, si = false)
  divisor = si ? 1000 : 1024
  suffix_list = si ? ["", "k", "M", "G", "T", "P"] : ["", "K", "M", "G", "T", "P"]
  val = bytes.to_f
  idx = 0
  while val >= divisor && idx < suffix_list.length - 1
    val = val / divisor
    idx += 1
  end
  s = "" + suffix_list[idx]
  if idx == 0
    val.to_i.to_s
  elsif val >= 10.0
    val.to_i.to_s + s
  else
    # one decimal place
    whole = val.to_i
    frac  = ((val - whole) * 10.0).to_i
    whole.to_s + "." + frac.to_s + s
  end
end

# ── Field range parsing (cut/numfmt/column) ─────────────────────────────────

# Parse a cut(1)-style LIST string ("1,3-5,7-") into two values:
#   indices   — Array of 1-based Integer indices; open-ended ranges stored as
#               negative sentinels (-N means "from N to end of line")
#   open_end  — true if any open-ended range was present
def parse_field_ranges(list_str)
  indices = []
  open_end = false
  s = "" + list_str
  s.split(",").each do |part|
    p = "" + part
    dash = p.index("-")
    if dash.nil?
      n = p.to_i
      indices.push(n) if n > 0
    elsif dash == 0
      m = p[1, p.length - 1].to_i
      i = 1
      while i <= m
        indices.push(i)
        i += 1
      end
    else
      from_s = p[0, dash]
      to_s   = p[dash + 1, p.length - dash - 1]
      from   = from_s.to_i
      if to_s == ""
        open_end = true
        indices.push(-from)
      else
        to = to_s.to_i
        i  = from
        while i <= to
          indices.push(i)
          i += 1
        end
      end
    end
  end
  [indices, open_end]
end

# True when 1-based index idx is selected by the parsed field ranges.
def field_selected?(idx, indices, open_end, complement = false)
  result = indices.include?(idx)
  if !result && open_end
    indices.each do |s|
      if s < 0 && idx >= -s
        result = true
        break
      end
    end
  end
  complement ? !result : result
end

# ── SI/IEC unit parsing for numfmt / du ─────────────────────────────────────

# Parse a number with optional SI/IEC suffix into a Float.
# Understands: K/k=1000, Ki=1024, M=1000^2, Mi=1024^2, G, Gi, T, Ti, etc.
def parse_si_value(text)
  t = "" + text
  si_map = {
    "Ki" => 1024, "Mi" => 1024 * 1024, "Gi" => 1024 * 1024 * 1024,
    "Ti" => 1024 * 1024 * 1024 * 1024,
    "K"  => 1000, "k"  => 1000,
    "M"  => 1000 * 1000, "G"  => 1000 * 1000 * 1000,
    "T"  => 1000 * 1000 * 1000 * 1000,
  }
  si_map.each do |suffix, mult|
    if t.end_with?(suffix)
      base = t[0, t.length - suffix.length]
      return base.to_f * mult
    end
  end
  t.to_f
end

# ── Pure-Ruby numeric helpers ───────────────────────────────────────────────

# True if every character of text is an ASCII digit.
def all_digits?(text)
  t = "" + text
  return false if t == ""
  i = 0
  while i < t.length
    return false unless "0123456789".include?(t[i])
    i += 1
  end
  true
end
