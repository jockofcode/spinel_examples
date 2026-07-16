# fmt.rb, simple text formatter (GNU fmt, Spinel port).
#
# Fills and joins lines to produce output lines up to WIDTH characters (default
# 75). Paragraph breaks (blank lines) are preserved. Leading whitespace on
# input lines sets the indent for the output paragraph.
#
# Flags:
#   -w N, --width=N      maximum line width (default 75)
#   -g N, --goal=N       goal line width (default: about 93% of width)
#   -c, --crown-margin   preserve the indent of the first two lines
#   -t, --tagged-paragraph  like -c, but the first line's indent is the tag
#   -s, --split-only     split long lines but do not fill/join short ones
#   -u, --uniform-spacing  one space between words, two after sentence ends
#   -p PREFIX, --prefix=PREFIX  reformat only lines beginning with PREFIX
#   --help               usage
#
# Compile: spinel nix_utils/fmt.rb -o nix_utils/bin/fmt
# Run:
#   ./bin/fmt file.txt
#   ./bin/fmt -w 60 file.txt
#   printf 'hello world foo bar\n' | ./bin/fmt -w 10

USAGE = "Usage: fmt [-w WIDTH] [OPTION]... [FILE]...\n" \
        "Reformat paragraphs from FILE(s) to fit within WIDTH columns (default 75).\n" \
        "  -w N   target line width (default 75)\n" \
        "  -s     split long lines only, do not join\n" \
        "  -u     uniform spacing (one space between words)\n" \
        "  -p PREFIX  only reformat lines starting with PREFIX\n" \
        "  --help"

class FmtOptions
  attr_accessor :width, :split_only, :uniform, :prefix, :goal, :crown, :tagged
  def initialize
    @width      = 75
    @split_only = false
    @uniform    = false
    @prefix     = nil
    @goal       = nil
    @crown      = false
    @tagged     = false
  end
end

def parse_argv(argv)
  opts = FmtOptions.new
  files = []
  options_done = false
  index = 0
  while index < argv.length
    arg = argv[index]
    if options_done || arg == "-" || arg.length < 2 || arg[0] != "-"
      files.push(arg)
    elsif arg == "--"
      options_done = true
    elsif arg == "--help"
      puts USAGE; exit 0
    elsif arg == "-s" || arg == "--split-only"
      opts.split_only = true
    elsif arg == "-u" || arg == "--uniform-spacing"
      opts.uniform = true
    elsif arg == "-c" || arg == "--crown-margin"
      opts.crown = true
    elsif arg == "-t" || arg == "--tagged-paragraph"
      opts.tagged = true
    elsif arg == "-w" || arg == "--width"
      index += 1; opts.width = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-w"
      opts.width = arg[2, arg.length - 2].to_i
    elsif arg.length > 8 && arg[0, 8] == "--width="
      opts.width = arg[8, arg.length - 8].to_i
    elsif arg == "-g" || arg == "--goal"
      index += 1; opts.goal = argv[index].to_i
    elsif arg.length > 2 && arg[0, 2] == "-g"
      opts.goal = arg[2, arg.length - 2].to_i
    elsif arg.length > 7 && arg[0, 7] == "--goal="
      opts.goal = arg[7, arg.length - 7].to_i
    elsif arg == "-p" || arg == "--prefix"
      index += 1; opts.prefix = argv[index]
    elsif arg.length > 2 && arg[0, 2] == "-p"
      opts.prefix = arg[2, arg.length - 2]
    elsif arg.length > 9 && arg[0, 9] == "--prefix="
      opts.prefix = arg[9, arg.length - 9]
    elsif arg.length >= 2 && "0123456789".include?(arg[1])
      # -N shorthand for -w N
      opts.width = arg[1, arg.length - 1].to_i
    else
      STDERR.puts "fmt: invalid option '#{arg}'"
      exit 1
    end
    index += 1
  end
  [opts, files]
end

def leading_whitespace(line)
  i = 0
  while i < line.length && (line[i] == " " || line[i] == "\t")
    i += 1
  end
  line[0, i]
end

def split_words(line)
  words = []
  word = ""
  i = 0
  while i < line.length
    ch = line[i]
    if ch == " " || ch == "\t"
      words.push(word) if word != ""
      word = ""
    else
      word += ch
    end
    i += 1
  end
  words.push(word) if word != ""
  words
end

def ends_sentence?(word)
  return false if word.length == 0
  last = word[-1]
  last == "." || last == "!" || last == "?" || last == ":"
end

def format_paragraph(lines, opts)
  return lines if lines.empty?

  # Crown margin (-c) and tagged paragraphs (-t) keep the first line's indent
  # for the first output line and the second line's indent for the rest.
  if opts.crown || opts.tagged
    first_indent = leading_whitespace(lines[0])
    rest_indent  = lines.length > 1 ? leading_whitespace(lines[1]) : first_indent
  else
    first_indent = leading_whitespace(lines[0])
    rest_indent  = first_indent
  end
  indent = first_indent
  # Fill toward the goal width when given, but never exceed the max width.
  width = opts.goal.nil? ? opts.width : (opts.goal < opts.width ? opts.goal : opts.width)

  if opts.split_only
    # Just split long lines at word boundaries
    result = []
    lines.each do |line|
      ind = leading_whitespace(line)
      words = split_words(line.strip)
      current = ind
      words.each do |word|
        if current == ind
          current += word
        elsif current.length + 1 + word.length <= width
          current += " " + word
        else
          result.push(current)
          current = ind + word
        end
      end
      result.push(current) unless current == ind
    end
    return result
  end

  # Collect all words
  all_words = []
  lines.each do |line|
    split_words(line.strip).each { |w| all_words.push(w) }
  end

  result = []
  line = first_indent
  line_has_word = false
  i = 0
  while i < all_words.length
    word = all_words[i]
    if !line_has_word
      line += word
      line_has_word = true
    else
      sep = if opts.uniform
        " "
      elsif ends_sentence?(all_words[i - 1])
        "  "
      else
        " "
      end
      if line.length + sep.length + word.length <= width
        line += sep + word
      else
        result.push(line)
        line = rest_indent + word
      end
    end
    i += 1
  end
  result.push(line) if line_has_word
  result
end

def flush_para(para, opts)
  unless para.empty?
    format_paragraph(para, opts).each { |l| puts l }
  end
  empty = []
  empty
end

def process(content, opts)
  lines = content.lines
  para = []
  in_para = false

  lines.each do |raw|
    line = raw.end_with?("\n") ? raw[0, raw.length - 1] : raw
    is_blank = line.strip == ""

    if opts.prefix
      if line.start_with?(opts.prefix)
        body = line[opts.prefix.length, line.length - opts.prefix.length]
        para.push(body)
      else
        para = flush_para(para, opts)
        puts line
      end
      next
    end

    if is_blank
      para = flush_para(para, opts)
      in_para = false
      puts ""
    else
      ind = leading_whitespace(line)
      # With crown/tagged margins a differing indent is expected within a
      # paragraph, so only an indent change splits paragraphs otherwise.
      if in_para && !opts.crown && !opts.tagged && ind != leading_whitespace(para[0] || "")
        para = flush_para(para, opts)
        in_para = false
      end
      para.push(line)
      in_para = true
    end
  end
  flush_para(para, opts)
end

opts, files = parse_argv(ARGV)
files = ["-"] if files.empty?

exit_code = 0
files.each do |name|
  cname = "" + name
  if cname != "-" && !File.exist?(cname)
    STDERR.puts "fmt: #{cname}: No such file or directory"
    exit_code = 1; next
  end
  content = (cname == "-") ? STDIN.read : File.read(cname)
  process(content, opts)
end
exit exit_code
