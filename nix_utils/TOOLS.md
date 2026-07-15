# nix_utils, common GNU/Linux command-line tools

A reference list of common GNU/Linux command-line tools, most from GNU
coreutils, plus a few ubiquitous companions (grep, sed, awk, find). The
goal of this directory is to reimplement a selection of these in Ruby that
compiles ahead-of-time with Spinel and also runs unmodified under CRuby.

Man pages for the implemented tools are saved under `man/` for reference.

Status legend: [x] implemented here  ,  [ ] not yet.

## Text and file viewing

| Tool | Status | Purpose |
|------|--------|---------|
| cat  | [x] | Concatenate files and print to stdout |
| tac  | [x] | Concatenate and print in reverse (last line first) |
| head | [x] | Output the first part of files |
| tail | [x] | Output the last part of files |
| nl   | [x] | Number lines of files |
| more | [ ] | Page through text one screen at a time |
| less | [ ] | Pager with backward movement (util-linux/less) |
| od   | [x] | Dump files in octal and other formats |
| hexdump | [x] | ASCII, decimal, hex, octal dump |
| strings | [x] | Print printable character sequences in files |

## Counting, sorting, dedup

| Tool | Status | Purpose |
|------|--------|---------|
| wc   | [x] | Print newline, word, character, and byte counts |
| sort | [x] | Sort lines of text files |
| uniq | [x] | Report or omit repeated adjacent lines |
| comm | [x] | Compare two sorted files line by line |
| shuf | [x] | Generate a random permutation of lines |

## Field and stream processing

| Tool | Status | Purpose |
|------|--------|---------|
| cut  | [x] | Remove/select sections from each line |
| paste | [x] | Merge lines of files |
| tr   | [x] | Translate or delete characters |
| join | [x] | Join lines of two files on a common field |
| fold | [x] | Wrap each input line to a given width |
| fmt  | [x] | Simple text formatter |
| expand / unexpand | [x] | Convert tabs to spaces and back |
| grep | [x] | Print lines matching a pattern |
| sed  | [ ] | Stream editor for filtering and transforming |
| awk  | [ ] | Pattern-directed scanning and processing |

## Output and echo

| Tool | Status | Purpose |
|------|--------|---------|
| echo | [x] | Display a line of text |
| printf | [x] | Format and print data |
| yes  | [x] | Repeatedly output a string until killed |
| seq  | [x] | Print a sequence of numbers |
| tee  | [x] | Read stdin, write to stdout and files |

## Filesystem and directories

| Tool | Status | Purpose |
|------|--------|---------|
| ls   | [x] | List directory contents |
| cp   | [x] | Copy files and directories |
| mv   | [x] | Move (rename) files |
| rm   | [x] | Remove files or directories |
| mkdir | [x] | Make directories |
| rmdir | [x] | Remove empty directories |
| ln   | [x] | Make links between files |
| touch | [x] | Change file timestamps / create empty files |
| pwd  | [x] | Print name of current/working directory |
| basename | [x] | Strip directory and suffix from a path |
| dirname | [x] | Strip last component from a path |
| readlink | [x] | Print resolved symbolic links |
| find | [ ] | Search for files in a directory hierarchy |
| stat | [x] | Display file or filesystem status |
| du   | [ ] | Estimate file space usage |
| df   | [ ] | Report filesystem disk space usage |

## Hashing and integrity

| Tool | Status | Purpose |
|------|--------|---------|
| md5sum | [ ] | Compute and check MD5 message digests |
| sha1sum | [ ] | Compute and check SHA1 digests |
| sha256sum | [ ] | Compute and check SHA256 digests |
| cksum | [ ] | Checksum and count the bytes in a file |

## System, users, and environment

| Tool | Status | Purpose |
|------|--------|---------|
| env  | [x] | Run a program in a modified environment |
| date | [ ] | Print or set the system date and time |
| whoami | [x] | Print effective user name |
| id   | [x] | Print real and effective user/group IDs |
| uname | [x] | Print system information |
| hostname | [x] | Show or set the system host name |
| sleep | [x] | Delay for a specified amount of time |
| true / false | [x] | Do nothing, successfully / unsuccessfully |
| test / [ | [ ] | Evaluate a conditional expression |
| xargs | [ ] | Build and execute commands from stdin |

## Implemented in this directory

The tools below are fully implemented as Spinel-compatible Ruby that also
runs under CRuby. Each reads files or standard input, supports the common
GNU flags noted, and exits with GNU-compatible status codes.

### Text and file viewing

- `cat.rb`     , flags: `-n`, `-b`, `-s`, `-E`, `-T`, `-v`, `-A`, `-e`, `-t`, `--help`
- `tac.rb`     , flags: `-b`, `-s SEP`, `--help`
- `head.rb`    , flags: `-n [-]NUM`, `-c [-]NUM`, `-q`, `-v`, `-z`, NUM suffixes, `--help`
- `tail.rb`    , flags: `-n [+]NUM`, `-c [+]NUM`, `-q`, `-v`, `-z`, `-f`/`-F`, `--help`
- `nl.rb`      , flags: `-b STYLE`, `-n FORMAT`, `-w N`, `-v N`, `-i N`, `-s SEP`, `--help`
- `fold.rb`    , flags: `-w N`, `-b`, `-s`, `--help`
- `od.rb`      , flags: `-A RADIX`, `-j SKIP`, `-N COUNT`, `-t TYPE`, `-v`, `-w N`, `-b/-c/-d/-o/-x/-s/-i`, `--help`
- `hexdump.rb` , flags: `-C`, `-b/-c/-d/-o/-x`, `-n COUNT`, `-s SKIP`, `-v`, `--help`
- `strings.rb` , flags: `-n MIN`, `-t RADIX`, `-o`, `--help`

### Counting, sorting, dedup

- `wc.rb`      , flags: `-l`, `-w`, `-c`, `-m`, `-L`, `--files0-from=F`, `--total=WHEN`, `--help`
- `sort.rb`    , flags: `-r`, `-n`, `-g`, `-f`, `-b`, `-u`, `-t SEP`, `-k KEYDEF`, `--help`
- `uniq.rb`    , flags: `-c`, `-d`, `-D`, `-u`, `-i`, `-f N`, `-s N`, `-w N`, `--help`
- `comm.rb`    , flags: `-1`, `-2`, `-3`, `-i`, `-z`, `--output-delimiter=STR`, `--help`
- `shuf.rb`    , flags: `-n NUM`, `-r`, `-z`, `-e`, `-i LO-HI`, `-o FILE`, `--help`

### Field and stream processing

- `cut.rb`     , flags: `-b LIST`, `-c LIST`, `-f LIST`, `-d DELIM`, `--complement`, `-s`, `--help`
- `paste.rb`   , flags: `-d LIST`, `-s`, `-z`, `--help`
- `tr.rb`      , flags: `-d`, `-s`, `-c/-C`, ranges (`a-z`), escapes (`\n \t \xHH \NNN`), `--help`
- `join.rb`    , flags: `-1/-2 FIELD`, `-j FIELD`, `-t CHAR`, `-a/-v N`, `-e STR`, `-o LIST`, `-i`, `-z`, `--help`
- `expand.rb`  , flags: `-t N/LIST`, `-i`, `--help`
- `unexpand.rb`, flags: `-a`, `-t N/LIST`, `--first-only`, `--help`
- `fmt.rb`     , flags: `-w N`, `-s`, `-u`, `-p PREFIX`, `--help`
- `grep.rb`    , flags: `-e/-f PATTERN`, `-i/-v/-n/-c/-l/-L/-q/-o/-F/-w/-x`, `-m N`, `-A/-B/-C N`, `-H/-h/-s/-r/-E`, `--color`, `--help`

### Output and echo

- `echo.rb`    , flags: `-n`, `-e`, `-E`, plus `-e` escape sequences
- `printf.rb`  , conversion specifiers: `%d %i %o %x %X %f %e %E %g %G %s %c %b %%`, width/precision/flags
- `seq.rb`     , flags: `-s SEP`, `-w`, `--help`; synopsis: `seq [FIRST [INC]] LAST`
- `yes.rb`     , repeats string (default "y") forever
- `tee.rb`     , flags: `-a`, `--help`

### Filesystem and directories

- `ls.rb`      , flags: `-l/-a/-A/-h/-R/-r/-t/-S/-s/-i/-d/-F/-p/-1/-m/-n`, `--color`, `--help`
- `cp.rb`      , flags: `-r/-f/-i/-n/-p/-v/-l/-s/-a/-u/-t DIR`, `--help`
- `mv.rb`      , flags: `-f/-i/-n/-v/-u/-t DIR`, `--help`
- `rm.rb`      , flags: `-r/-f/-i/-I/-v/-d`, `--help`
- `mkdir.rb`   , flags: `-p`, `-m MODE`, `-v`, `--help`
- `rmdir.rb`   , flags: `-p`, `-v`, `--help`
- `ln.rb`      , flags: `-s/-f/-v/-r/-n/-b/-t DIR`, `--help`
- `touch.rb`   , flags: `-a/-m/-c/-r FILE/-t STAMP/-d STRING`, `--help`
- `basename.rb`, flags: `-a`, `-s SUFFIX`, `-z`, `--help`
- `dirname.rb` , flags: `-z`, `--help`
- `pwd.rb`     , flags: `-L`, `-P`, `--help`
- `readlink.rb`, flags: `-f/-e/-m/-n/-q/-z`, `--help`
- `stat.rb`    , flags: `-f/-c FORMAT/-t/-L`, format directives: `%n %s %f %F %u %U %g %G %i %h %a %A %x %y %z`, `--help`

### System and environment

- `env.rb`      , flags: `-i/-u NAME/-0`, NAME=VALUE pairs before command, `--help`
- `whoami.rb`   , prints effective user name
- `id.rb`       , flags: `-u/-g/-G/-n/-r/-z`, `--help`
- `uname.rb`    , flags: `-a/-s/-n/-r/-v/-m/-p/-i/-o`, `--help`
- `hostname.rb` , flags: `-s/-f/-i/-d`, `--help`
- `sleep.rb`    , synopsis: `sleep NUM[smhd]...`; fractional seconds supported
- `true.rb`     , always exits 0
- `false.rb`    , always exits 1

### Compile (Spinel)

```sh
cd nix_utils
spinel cat.rb      -o bin/cat
spinel tac.rb      -o bin/tac
spinel wc.rb       -o bin/wc
spinel head.rb     -o bin/head
spinel tail.rb     -o bin/tail
spinel nl.rb       -o bin/nl
spinel fold.rb     -o bin/fold
spinel od.rb       -o bin/od
spinel hexdump.rb  -o bin/hexdump
spinel strings.rb  -o bin/strings
spinel sort.rb     -o bin/sort
spinel uniq.rb     -o bin/uniq
spinel comm.rb     -o bin/comm
spinel shuf.rb     -o bin/shuf
spinel cut.rb      -o bin/cut
spinel paste.rb    -o bin/paste
spinel tr.rb       -o bin/tr
spinel join.rb     -o bin/join
spinel expand.rb   -o bin/expand
spinel unexpand.rb -o bin/unexpand
spinel fmt.rb      -o bin/fmt
spinel grep.rb     -o bin/grep
spinel echo.rb     -o bin/echo
spinel printf.rb   -o bin/printf
spinel seq.rb      -o bin/seq
spinel yes.rb      -o bin/yes
spinel tee.rb      -o bin/tee
spinel ls.rb       -o bin/ls
spinel cp.rb       -o bin/cp
spinel mv.rb       -o bin/mv
spinel rm.rb       -o bin/rm
spinel mkdir.rb    -o bin/mkdir
spinel rmdir.rb    -o bin/rmdir
spinel ln.rb       -o bin/ln
spinel touch.rb    -o bin/touch
spinel basename.rb -o bin/basename
spinel dirname.rb  -o bin/dirname
spinel pwd.rb      -o bin/pwd
spinel readlink.rb -o bin/readlink
spinel stat.rb     -o bin/stat
spinel env.rb      -o bin/env
spinel whoami.rb   -o bin/whoami
spinel id.rb       -o bin/id
spinel uname.rb    -o bin/uname
spinel hostname.rb -o bin/hostname
spinel sleep.rb    -o bin/sleep
spinel true.rb     -o bin/true
spinel false.rb    -o bin/false
```

`grep.rb` and `od.rb` use regex literals and require Spinel's regex support
(same as `source/log_report.rb`). All other tools use only core Ruby builtins
(File, STDIN/STDOUT, String, Array, Dir, ENV, Regexp), so none need
`SPINEL_REQUIRE_GATE`.

### Run (either runtime)

```sh
./bin/wc -l README.md
printf 'a\nb\n' | ./bin/cat -n
./bin/head -n 3 TOOLS.md
./bin/echo -e 'a\tb'
printf 'c\nb\na\n' | ./bin/sort
printf 'hello world\n' | ./bin/tr 'a-z' 'A-Z'
./bin/seq -s, 1 10
./bin/cut -d: -f1 /etc/passwd
```

### Tests

```sh
ruby tests/nix_utils_test.rb
```
