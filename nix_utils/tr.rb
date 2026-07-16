# tr.rb, translate or delete characters (GNU tr, Spinel port).
#
# Translate, squeeze, and/or delete characters in standard input, writing to
# standard output. Unlike most utilities, tr never reads files; it only reads
# from standard input.
#
# Synopsis:
#   tr [OPTION]... SET1 [SET2]
#
# Flags:
#   -d, --delete        delete characters in SET1 (no SET2 required)
#   -s, --squeeze-repeats  replace each input sequence of a repeated character
#                           that is listed in the last specified SET with a
#                           single occurrence of that character
#   -c, -C, --complement  use the complement of SET1
#   -t, --truncate-set1   first truncate SET1 to the length of SET2
#   --help              usage
#
# SET syntax:
#   Ranges:    a-z   A-Z   0-9
#   Escapes:   \\  \a  \b  \f  \n  \r  \t  \v  \NNN (octal)  \xHH (hex)
#
# Compile: spinel nix_utils/tr.rb -o nix_utils/bin/tr
# Run:
#   printf 'Hello World\n' | ./bin/tr 'a-z' 'A-Z'
#   printf 'aabbcc\n' | ./bin/tr -s 'a-z'
#   printf 'Hello\n' | ./bin/tr -d aeiou
#
# Core Ruby only (STDIN, STDOUT, String, Array); no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/tr.rb ...`).

USAGE = "Usage: tr [OPTION]... SET1 [SET2]\n" \
        "Translate, squeeze, or delete characters from standard input.\n" \
        "  -d  delete chars in SET1   -s  squeeze repeated chars\n" \
        "  -c/-C  complement SET1     -t  truncate SET1   --help"

class TrOptions
  attr_accessor :delete, :squeeze, :complement, :truncate
  def initialize
    @delete     = false
    @squeeze    = false
    @complement = false
    @truncate   = false
  end
end

def parse_argv(argv)
  opts  = TrOptions.new
  sets  = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done
      sets.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-d" || arg == "--delete"
      opts.delete = true
    elsif arg == "-s" || arg == "--squeeze-repeats"
      opts.squeeze = true
    elsif arg == "-c" || arg == "-C" || arg == "--complement"
      opts.complement = true
    elsif arg == "-t" || arg == "--truncate-set1"
      opts.truncate = true
    elsif arg.length > 1 && arg[0] == "-"
      # Combined short flags: -ds, -dc, etc.
      i = 1
      valid = true
      while i < arg.length
        c = arg[i]
        if c == "d";         opts.delete     = true
        elsif c == "s";      opts.squeeze    = true
        elsif c == "c" || c == "C"; opts.complement = true
        elsif c == "t";      opts.truncate   = true
        else valid = false; break
        end
        i += 1
      end
      unless valid
        STDERR.puts "tr: invalid option -- '#{arg}'"
        STDERR.puts "Try 'tr --help' for more information."
        exit 1
      end
    else
      sets.push(arg)
    end
    index += 1
  end
  [opts, sets]
end

# Decode a tr escape sequence starting at position i in str. Returns [char, new_i].
def decode_escape(str, i)
  nxt = str[i + 1]
  if nxt == "a";  return ["\a", i + 2]
  elsif nxt == "b"; return ["\b", i + 2]
  elsif nxt == "f"; return ["\f", i + 2]
  elsif nxt == "n"; return ["\n", i + 2]
  elsif nxt == "r"; return ["\r", i + 2]
  elsif nxt == "t"; return ["\t", i + 2]
  elsif nxt == "v"; return ["\v", i + 2]
  elsif nxt == "\\"; return ["\\", i + 2]
  elsif nxt == "x"
    # \xHH: up to 2 hex digits.
    digits = ""
    scan = i + 2
    while scan < str.length && digits.length < 2 && "0123456789abcdefABCDEF".include?(str[scan])
      digits = digits + str[scan]
      scan += 1
    end
    ch = digits == "" ? "x" : digits.to_i(16).chr
    return [ch, scan]
  elsif "01234567".include?(nxt)
    # \NNN: up to 3 octal digits.
    digits = ""
    scan = i + 1
    while scan < str.length && digits.length < 3 && "01234567".include?(str[scan])
      digits = digits + str[scan]
      scan += 1
    end
    return [digits.to_i(8).chr, scan]
  else
    return [nxt, i + 2]
  end
end

# Expand a tr SET string into an array of characters.
def expand_set(str)
  chars = []
  i = 0
  while i < str.length
    c = str[i]
    if c == "\\" && i + 1 < str.length
      ch, i = decode_escape(str, i)
      chars.push(ch)
    elsif i + 2 < str.length && str[i + 1] == "-" && str[i + 2] != "\\"
      # Range a-z.
      from_ord = c.ord
      to_ord   = str[i + 2].ord
      if from_ord <= to_ord
        from_ord.upto(to_ord) { |o| chars.push(o.chr) }
      else
        to_ord.upto(from_ord) { |o| chars.push(o.chr) }
      end
      i += 3
    else
      chars.push(c)
      i += 1
    end
  end
  chars
end

# Complement a character set (all 256 byte values not in the set, in order).
def complement_set(chars)
  set = {}
  chars.each { |c| set[c] = true }
  result = []
  i = 0
  while i < 256
    ch = i.chr
    result.push(ch) unless set[ch]
    i += 1
  end
  result
end

# Build a translation table (hash: src_char -> dst_char) from set1 and set2
# arrays. If set2 is shorter, its last element is repeated.
def build_table(set1, set2)
  table = {}
  last_dst = set2.length > 0 ? set2.last : nil
  i = 0
  while i < set1.length
    dst = i < set2.length ? set2[i] : last_dst
    table[set1[i]] = dst
    i += 1
  end
  table
end

opts, sets = parse_argv(ARGV)

if sets.empty?
  STDERR.puts "tr: missing operand"
  exit 1
end
# Translate-only mode requires SET2.  Squeeze-only (-s, no -d, no SET2) is valid.
if !opts.delete && !opts.squeeze && sets.length < 2
  STDERR.puts "tr: missing operand after '#{sets[0]}'"
  exit 1
end
# When -d and -s are combined, SET2 specifies the squeeze set and is required.
if opts.delete && opts.squeeze && sets.length < 2
  STDERR.puts "tr: missing operand after '#{sets[0]}'"
  exit 1
end

set1_raw = expand_set(sets[0])
set2_raw = sets.length > 1 ? expand_set(sets[1]) : []

set1 = opts.complement ? complement_set(set1_raw) : set1_raw

content = STDIN.read

if opts.delete
  # Build a set of chars to delete.
  del_set = {}
  set1.each { |c| del_set[c] = true }

  # Squeeze set for after-delete squeezing uses set2 when both -d and -s are active.
  sq_set = {}
  if opts.squeeze && set2_raw.length > 0
    set2_raw.each { |c| sq_set[c] = true }
  end

  result = ""
  prev = nil
  i = 0
  while i < content.length
    c = content[i]
    unless del_set[c]
      if opts.squeeze && set2_raw.length > 0 && sq_set[c] && c == prev
        # skip squeeze duplicate
      else
        result += c
        prev = c
      end
    end
    i += 1
  end
  STDOUT.write(result)

elsif opts.squeeze && set2_raw.empty?
  # Squeeze only: no translation.
  sq_set = {}
  set1.each { |c| sq_set[c] = true }
  result = ""
  prev = nil
  i = 0
  while i < content.length
    c = content[i]
    if sq_set[c] && c == prev
      # skip
    else
      result += c
      prev = c
    end
    i += 1
  end
  STDOUT.write(result)

else
  # Translate (and optionally squeeze the result). With -t, SET1 is truncated to
  # the length of SET2 so any extra SET1 characters are left unchanged.
  set1_for_table = opts.truncate ? set1[0, set2_raw.length] : set1
  table = build_table(set1_for_table, set2_raw)

  sq_set = {}
  if opts.squeeze
    set2_raw.each { |c| sq_set[c] = true }
  end

  result = ""
  prev = nil
  i = 0
  while i < content.length
    c = content[i]
    out_c = table.key?(c) ? table[c] : c
    if opts.squeeze && sq_set[out_c] && out_c == prev
      # skip squeeze duplicate
    else
      result = result + out_c
      prev = out_c
    end
    i += 1
  end
  STDOUT.write(result)
end

exit 0
