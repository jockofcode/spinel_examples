# echo.rb, display a line of text (GNU coreutils echo, Spinel port).
#
# A faithful subset of GNU echo: joins its arguments with single spaces and
# prints them followed by a newline. Flags -n, -e, and -E behave as GNU does,
# including the -e backslash escape sequences (\n \t \\ \xHH \0NNN \c ...).
#
# Compile: spinel nix_utils/echo.rb -o nix_utils/bin/echo
# Run:
#   ./bin/echo hello world          # -> "hello world"
#   ./bin/echo -n no-newline        # no trailing newline
#   ./bin/echo -e 'a\tb\nc'         # interpret escapes
#
# Uses only core Ruby (String, Array, STDOUT), so no require gate is needed.
# The same file runs unmodified under CRuby (`ruby nix_utils/echo.rb ...`).

# Interpret GNU echo -e backslash escapes in one argument. Returns a two
# element array: the decoded string and a boolean that is true when a \c
# escape was seen (which tells the caller to stop all further output).
def interpret_escapes(text)
  out = ""
  index = 0
  length = text.length
  while index < length
    char = text[index]
    if char != "\\" || index + 1 >= length
      out = out + char
      index += 1
      next
    end

    # We have a backslash with at least one character after it.
    nxt = text[index + 1]
    if nxt == "\\"
      out += "\\"; index += 2
    elsif nxt == "a"
      out += "\a"; index += 2
    elsif nxt == "b"
      out += "\b"; index += 2
    elsif nxt == "c"
      # \c: produce no further output, signal the caller to stop.
      return [out, true]
    elsif nxt == "e"
      out += "\e"; index += 2
    elsif nxt == "f"
      out += "\f"; index += 2
    elsif nxt == "n"
      out += "\n"; index += 2
    elsif nxt == "r"
      out += "\r"; index += 2
    elsif nxt == "t"
      out += "\t"; index += 2
    elsif nxt == "v"
      out += "\v"; index += 2
    elsif nxt == "x"
      # \xHH: 1 or 2 hex digits after the x.
      digits = ""
      scan = index + 2
      while scan < length && digits.length < 2 && hex_digit?(text[scan])
        digits = digits + text[scan]
        scan += 1
      end
      if digits == ""
        out += "\\x"                 # no digits: keep literally, like GNU
      else
        out += digits.to_i(16).chr
      end
      index = scan
    elsif nxt == "0"
      # \0NNN: up to 3 octal digits after the 0.
      digits = ""
      scan = index + 2
      while scan < length && digits.length < 3 && octal_digit?(text[scan])
        digits = digits + text[scan]
        scan += 1
      end
      out += (digits == "" ? 0 : digits.to_i(8)).chr
      index = scan
    else
      # Unknown escape: keep the backslash and the character literally.
      out += "\\" + nxt
      index += 2
    end
  end
  [out, false]
end

def hex_digit?(char)
  "0123456789abcdefABCDEF".include?(char)
end

def octal_digit?(char)
  "01234567".include?(char)
end

# Parse leading option flags. GNU echo only treats a token as a flag if it is
# exactly -n, -e, or -E (or a run of those letters like -neE). The first token
# that is not such a flag ends option parsing; it and everything after are
# operands. Returns [trailing_newline, interpret_escapes, operands].
def parse_args(argv)
  trailing_newline = true
  do_escapes = false
  index = 0
  while index < argv.length
    arg = argv[index]
    break unless flag_token?(arg)
    # Apply each letter in the combined flag (e.g. -neE).
    letters = arg[1, arg.length - 1]
    letter_index = 0
    while letter_index < letters.length
      letter = letters[letter_index]
      if letter == "n"
        trailing_newline = false
      elsif letter == "e"
        do_escapes = true
      elsif letter == "E"
        do_escapes = false
      end
      letter_index += 1
    end
    index += 1
  end
  [trailing_newline, do_escapes, argv[index, argv.length - index]]
end

# True when arg is a valid echo flag token: a dash followed by one or more of
# the letters n, e, E and nothing else.
def flag_token?(arg)
  return false if arg.length < 2 || arg[0] != "-"
  body = arg[1, arg.length - 1]
  body_index = 0
  while body_index < body.length
    letter = body[body_index]
    return false unless letter == "n" || letter == "e" || letter == "E"
    body_index += 1
  end
  true
end

trailing_newline, do_escapes, operands = parse_args(ARGV)

output = operands.join(" ")
stop = false
if do_escapes
  output, stop = interpret_escapes(output)
end

STDOUT.write(output)
# A \c escape suppresses the trailing newline too; otherwise honor -n.
STDOUT.write("\n") if trailing_newline && !stop
