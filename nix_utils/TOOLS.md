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
| tsort | [x] | Topological sort |

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
| sed  | [x] | Stream editor for filtering and transforming |
| column | [x] | Columnate lists |
| split | [x] | Split a file into pieces |
| numfmt | [x] | Reformat numbers |
| awk  | [ ] | Pattern-directed scanning and processing |

## Output and echo

| Tool | Status | Purpose |
|------|--------|---------|
| echo | [x] | Display a line of text |
| printf | [x] | Format and print data |
| yes  | [x] | Repeatedly output a string until killed |
| seq  | [x] | Print a sequence of numbers |
| tee  | [x] | Read stdin, write to stdout and files |
| factor | [x] | Print prime factors |

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
| realpath | [x] | Print resolved absolute file names |
| find | [x] | Search for files in a directory hierarchy |
| stat | [x] | Display file or filesystem status |
| du   | [x] | Estimate file space usage |
| mktemp | [x] | Create a temporary file or directory |
| df   | [ ] | Report filesystem disk space usage |

## Hashing and integrity

| Tool | Status | Purpose |
|------|--------|---------|
| md5sum | [x] | Compute and check MD5 message digests |
| sha1sum | [x] | Compute and check SHA1 digests |
| sha224sum | [x] | Compute and check SHA-224 digests |
| sha256sum | [x] | Compute and check SHA-256 digests |
| sha384sum | [x] | Compute and check SHA-384 digests |
| sha512sum | [x] | Compute and check SHA-512 digests |
| cksum | [x] | Checksum and count the bytes in a file |
| base64 | [x] | Base64 encode/decode |

## System, users, and environment

| Tool | Status | Purpose |
|------|--------|---------|
| env  | [x] | Run a program in a modified environment |
| date | [x] | Print or set the system date and time |
| whoami | [x] | Print effective user name |
| id   | [x] | Print real and effective user/group IDs |
| uname | [x] | Print system information |
| hostname | [x] | Show or set the system host name |
| logname | [x] | Print current login name |
| printenv | [x] | Print environment variables |
| nproc | [x] | Print number of available processors |
| sleep | [x] | Delay for a specified amount of time |
| true / false | [x] | Do nothing, successfully / unsuccessfully |
| test / [ | [ ] | Evaluate a conditional expression |
| xargs | [x] | Build and execute commands from stdin |

## Implemented in this directory

The tools below are fully implemented as Spinel-compatible Ruby that also
runs under CRuby. Each reads files or standard input, supports the common
GNU flags noted, and exits with GNU-compatible status codes.

### Text and file viewing

- `cat.rb`     , flags: `-n`, `-b`, `-s`, `-E`, `-T`, `-v`, `-A`, `-e`, `-t`, `--help`
- `tac.rb`     , flags: `-b`, `-s SEP`, `--help`
- `head.rb`    , flags: `-n [-]NUM`, `-c [-]NUM`, `-q`, `-v`, NUM suffixes, `--help`
- `tail.rb`    , flags: `-n [+]NUM`, `-c [+]NUM`, `-q`, `-v`, `-f`/`-F`, `-s N`, `--pid=PID`, `--retry`, `--help`
- `nl.rb`      , flags: `-b STYLE`, `-n FORMAT`, `-w N`, `-v N`, `-i N`, `-s SEP`, `--help`
- `fold.rb`    , flags: `-w N`, `-b`, `-s`, `--help`
- `od.rb`      , flags: `-A RADIX`, `-j SKIP`, `-N COUNT`, `-t TYPE`, `-v`, `-w N`, `-b/-c/-d/-o/-x/-s/-i`, `--help`
- `hexdump.rb` , flags: `-C`, `-b/-c/-d/-o/-x`, `-n COUNT`, `-s SKIP`, `-v`, `--help`
- `strings.rb` , flags: `-n MIN`, `-t RADIX`, `-o`, `--help`

### Counting, sorting, dedup

- `wc.rb`      , flags: `-l`, `-w`, `-c`, `-m`, `-L`, `--files0-from=F`, `--total=WHEN`, `--help`
- `sort.rb`    , flags: `-r`, `-n`, `-g`, `-h`, `-M`, `-V`, `-R`, `-d`, `-i`, `-f`, `-b`, `-u`, `-c/-C`, `-t SEP`, `-k KEYDEF`, `-o FILE`, `-z`, `--sort=WORD`, `--help`
- `uniq.rb`    , flags: `-c`, `-d`, `-D`, `-u`, `-i`, `-f N`, `-s N`, `-w N`, `--help`
- `comm.rb`    , flags: `-1`, `-2`, `-3`, `-i`, `-z`, `--output-delimiter=STR`, `--help`
- `shuf.rb`    , flags: `-n NUM`, `-r`, `-z`, `-e`, `-i LO-HI`, `-o FILE`, `--help`
- `tsort.rb`   , flags: `--help`, `--version`

### Field and stream processing

- `cut.rb`     , flags: `-b LIST`, `-c LIST`, `-f LIST`, `-d DELIM`, `--complement`, `-s`, `--help`
- `paste.rb`   , flags: `-d LIST`, `-s`, `-z`, `--help`
- `tr.rb`      , flags: `-d`, `-s`, `-c/-C`, ranges (`a-z`), escapes (`\n \t \xHH \NNN`), `--help`
- `join.rb`    , flags: `-1/-2 FIELD`, `-j FIELD`, `-t CHAR`, `-a/-v N`, `-e STR`, `-o LIST`, `-i`, `-z`, `--help`
- `expand.rb`  , flags: `-t N/LIST`, `-i`, `--help`
- `unexpand.rb`, flags: `-a`, `-t N/LIST`, `--first-only`, `--help`
- `fmt.rb`     , flags: `-w N`, `-s`, `-u`, `-p PREFIX`, `--help`
- `grep.rb`    , flags: `-e/-f PATTERN`, `-i/-v/-n/-c/-l/-L/-q/-o/-F/-w/-x`, `-m N`, `-A/-B/-C N`, `-H/-h/-s/-r/-E`, `--color`, `--help`
- `sed.rb`     , flags: `-n`, `-e SCRIPT`, `-f FILE`, `-i[SUFFIX]`, `-E/-r`, `-s`, `-u`, `--help`
- `column.rb`  , flags: `-t`, `-s SEP`, `-o STR`, `-c N`, `-x`, `-N NAMES`, `-d`, `--help`
- `split.rb`   , flags: `-a N`, `--additional-suffix=SUFFIX`, `-b SIZE`, `-C SIZE`, `-d`, `-x`, `-e`, `-l N`, `-n CHUNKS`, `--help`
- `numfmt.rb`  , flags: `--from=UNIT`, `--to=UNIT`, `--from-unit=N`, `--to-unit=N`, `--suffix=SUFFIX`, `--round=METHOD`, `--padding=N`, `--format=FMT`, `--field=FIELDS`, `--header[=N]`, `--invalid=MODE`, `--grouping`, `--help`

### Output and echo

- `echo.rb`    , flags: `-n`, `-e`, `-E`, plus `-e` escape sequences
- `printf.rb`  , conversion specifiers: `%d %i %o %x %X %f %e %E %g %G %s %c %b %%`, width/precision/flags
- `seq.rb`     , flags: `-s SEP`, `-w`, `--help`; synopsis: `seq [FIRST [INC]] LAST`
- `yes.rb`     , repeats string (default "y") forever
- `tee.rb`     , flags: `-a`, `--help`
- `factor.rb`  , flags: `-h/--exponents`, `--help`, `--version`; numbers from ARGV or stdin

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
- `realpath.rb`, flags: `-e`, `-m`, `--help`
- `find.rb`    , tests: `-name/-iname/-path/-ipath/-type/-size/-empty/-maxdepth/-mindepth/-newer/-mtime/-atime/-ctime/-mmin/-amin/-perm/-user/-group/-readable/-writable/-executable/-regex/-iregex/-samefile/-links/-inum/-depth/-mount/-prune`; actions: `-print/-ls/-exec/-execdir/-ok/-delete/-quit/-printf`; operators: `-and/-or/!`
- `stat.rb`    , flags: `-f/-c FORMAT/-t/-L`, format directives: `%n %s %f %F %u %U %g %G %i %h %a %A %x %y %z`, `--help`
- `du.rb`      , flags: `-a/-A/-b/-B SIZE/-c/-d N/-h/-k/-m/-s/--si/-L/-P/-D/-S/-x/-t SIZE/--time/--time-style/--exclude/--inodes/-l`, `--help`
- `mktemp.rb`  , flags: `-d`, `-u`, `-q`, `--suffix=SUFF`, `-p DIR`, `-t`, `TEMPLATE`, `--help`

### Hashing and integrity

- `md5sum.rb`   , flags: `-c/--check`, `--tag`, `-b`, `--quiet`, `--status`, `-w/--warn`, `--ignore-missing`, `--strict`, `--help`
- `sha1sum.rb`  , flags: same as md5sum
- `sha224sum.rb`, flags: same as md5sum
- `sha256sum.rb`, flags: same as md5sum
- `sha384sum.rb`, flags: same as md5sum
- `sha512sum.rb`, flags: same as md5sum
- `cksum.rb`    , flags: `-a/--algorithm=TYPE` (sysv, bsd, crc, crc32b, md5, sha1, sha2), `--base64`, `-c/--check`, `--tag`, `--untagged`, `--ignore-missing`, `--quiet`, `--status`, `--strict`, `-w/--warn`, `--help`
- `base64.rb`   , flags: `-d/--decode`, `-i/--ignore-garbage`, `-w COLS/--wrap=COLS`, `--help`

### System and environment

- `env.rb`      , flags: `-i/-u NAME/-0`, NAME=VALUE pairs before command, `--help`
- `date.rb`     , flags: `+FORMAT`, `-d STRING`, `-u/--utc`, `-r FILE`, `-I[FMT]/--iso-8601[=FMT]`, `-R/--rfc-email`, `--rfc-3339=FMT`, `--help`
- `whoami.rb`   , prints effective user name
- `id.rb`       , flags: `-u/-g/-G/-n/-r/-z`, `--help`
- `uname.rb`    , flags: `-a/-s/-n/-r/-v/-m/-p/-i/-o`, `--help`
- `hostname.rb` , flags: `-s/-f/-i/-d`, `--help`
- `logname.rb`  , prints current login name; `--help`, `--version`
- `printenv.rb` , flags: VARIABLE names; `-0/--null`, `--help`
- `nproc.rb`    , flags: `--all`, `--ignore=N`, `--help`
- `sleep.rb`    , synopsis: `sleep NUM[smhd]...`; fractional seconds supported
- `true.rb`     , always exits 0
- `false.rb`    , always exits 1
- `xargs.rb`    , flags: `-a FILE`, `-d DELIM`, `-I REPLACE`, `-L N`, `-n N`, `-r`, `-t`, `-P N`, `-s SIZE`, `--help`

### Helper libraries (not standalone tools)

- `digest_ext.rb`  — pure-Ruby MD5, SHA-224, SHA-384, SHA-512 for Spinel (Spinel's `digest` package only provides SHA-1 and SHA-256)
- `checksum_tool.rb` — shared logic for the `*sum` tools
- `nix_helpers.rb`  — `coerce()`, `die()`, `parse_field_ranges()`, `field_selected?()` shared by multiple tools
- `file_ext.rb` + `sp_file_ext.c` — FFI native extension providing `FileExt.readlink`, `.symlink`, `.link`, `.chmod`, `.stat_str`, `.lstat_str`, `.utime_c`

### Compile (Spinel)

```sh
cd nix_utils

# Build the native C extension (needed by ls, cp, ln, readlink, stat, touch, mv)
SPINEL_INC="$HOME/.asdf/installs/spinel/master/lib/spinel/lib"
cc -c sp_file_ext.c -I"$SPINEL_INC" -o sp_file_ext.o

# Tools that do NOT need the C extension
spinel cat.rb        -o bin/cat
spinel tac.rb        -o bin/tac
spinel wc.rb         -o bin/wc
spinel head.rb       -o bin/head
spinel tail.rb       -o bin/tail
spinel nl.rb         -o bin/nl
spinel fold.rb       -o bin/fold
spinel od.rb         -o bin/od
spinel hexdump.rb    -o bin/hexdump
spinel strings.rb    -o bin/strings
spinel sort.rb       -o bin/sort
spinel uniq.rb       -o bin/uniq
spinel comm.rb       -o bin/comm
spinel shuf.rb       -o bin/shuf
spinel cut.rb        -o bin/cut
spinel paste.rb      -o bin/paste
spinel tr.rb         -o bin/tr
spinel join.rb       -o bin/join
spinel expand.rb     -o bin/expand
spinel unexpand.rb   -o bin/unexpand
spinel fmt.rb        -o bin/fmt
spinel grep.rb       -o bin/grep
spinel sed.rb        -o bin/sed
spinel column.rb     -o bin/column
spinel split.rb      -o bin/split
spinel numfmt.rb     -o bin/numfmt
spinel tsort.rb      -o bin/tsort
spinel factor.rb     -o bin/factor
spinel echo.rb       -o bin/echo
spinel printf.rb     -o bin/printf
spinel seq.rb        -o bin/seq
spinel yes.rb        -o bin/yes
spinel tee.rb        -o bin/tee
spinel du.rb         -o bin/du
spinel date.rb       -o bin/date
spinel find.rb       -o bin/find
spinel mktemp.rb     -o bin/mktemp
spinel md5sum.rb     -o bin/md5sum
spinel sha1sum.rb    -o bin/sha1sum
spinel sha224sum.rb  -o bin/sha224sum
spinel sha256sum.rb  -o bin/sha256sum
spinel sha384sum.rb  -o bin/sha384sum
spinel sha512sum.rb  -o bin/sha512sum
spinel cksum.rb      -o bin/cksum
spinel base64.rb     -o bin/base64
spinel env.rb        -o bin/env
spinel whoami.rb     -o bin/whoami
spinel id.rb         -o bin/id
spinel uname.rb      -o bin/uname
spinel hostname.rb   -o bin/hostname
spinel logname.rb    -o bin/logname
spinel printenv.rb   -o bin/printenv
spinel nproc.rb      -o bin/nproc
spinel sleep.rb      -o bin/sleep
spinel true.rb       -o bin/true
spinel false.rb      -o bin/false
spinel xargs.rb      -o bin/xargs
spinel realpath.rb   -o bin/realpath

# Tools that DO need the C extension (--link must come before -o)
spinel --link sp_file_ext.o ls.rb       -o bin/ls
spinel --link sp_file_ext.o cp.rb       -o bin/cp
spinel --link sp_file_ext.o mv.rb       -o bin/mv
spinel --link sp_file_ext.o rm.rb       -o bin/rm
spinel --link sp_file_ext.o mkdir.rb    -o bin/mkdir
spinel --link sp_file_ext.o rmdir.rb    -o bin/rmdir
spinel --link sp_file_ext.o ln.rb       -o bin/ln
spinel --link sp_file_ext.o touch.rb    -o bin/touch
spinel --link sp_file_ext.o basename.rb -o bin/basename
spinel --link sp_file_ext.o dirname.rb  -o bin/dirname
spinel --link sp_file_ext.o pwd.rb      -o bin/pwd
spinel --link sp_file_ext.o readlink.rb -o bin/readlink
spinel --link sp_file_ext.o stat.rb     -o bin/stat
```

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
printf 'user:1000\nroot:0\n' | ./bin/sort -t: -k2n
printf 'hello\n' | ./bin/sed 's/l/L/g'
./bin/find . -name '*.rb' -maxdepth 1
printf '100\n1000\n' | ./bin/numfmt --to=si
```

### Tests

```sh
bash tests/nix_utils_test.sh
# or, to run under CRuby instead of Spinel:
RUBY=ruby bash tests/nix_utils_test.sh
```
