# Ruby vs Spinel Method Gaps

This note compares Ruby 3.4 documentation against the local Spinel checkout at
`/Users/branden/Projects/spinel`.

Sources used:

- Ruby 3.4 `String`: https://docs.ruby-lang.org/en/3.4/String.html
- Ruby 3.4 `Array`: https://docs.ruby-lang.org/en/3.4/Array.html
- Ruby 3.4 `Hash`: https://docs.ruby-lang.org/en/3.4/Hash.html
- Ruby 3.4 `IO`: https://docs.ruby-lang.org/en/3.4/IO.html
- Ruby 3.4 `File`: https://docs.ruby-lang.org/en/3.4/File.html
- Ruby 3.4 `Time`: https://docs.ruby-lang.org/en/3.4/Time.html
- Ruby 3.4 `Object`: https://docs.ruby-lang.org/en/3.4/Object.html
- Ruby 3.4 `Module`: https://docs.ruby-lang.org/en/3.4/Module.html
- Ruby 3.4 `Enumerable`: https://docs.ruby-lang.org/en/3.4/Enumerable.html
- Ruby 3.4 `Regexp`: https://docs.ruby-lang.org/en/3.4/Regexp.html
- Ruby 3.4 `MatchData`: https://docs.ruby-lang.org/en/3.4/MatchData.html
- Ruby 3.4 `Integer`: https://docs.ruby-lang.org/en/3.4/Integer.html
- Spinel local docs: `docs/limitations.md`, `docs/require.md`
- Spinel local source: `lib/`, `packages/`, and targeted compiler probes

Spinel is not trying to be all of CRuby. It is a whole-program AOT compiler, so
methods that need a runtime parser, mutable method table, full object registry,
or general reflection are expected gaps.

## High-Level Summary

Use this as the quick decision map for writing examples:

| Ruby area | Spinel status today |
|---|---|
| Basic strings, arrays, hashes, ranges, numbers, regexp, file reads/writes, marshal, pack/unpack | Broadly available |
| `json`, `base64`, `digest`, `stringio`, `strscan`, `set`, `optparse`, `erb` | Available through `require` with `SPINEL_REQUIRE_GATE=1` |
| Socket/network helpers | `source/socket_shim.rb` provides a small `TCPServer` / `TCPSocket` compatibility layer over Spinel's `sp_net` helpers |
| Reflection and metaprogramming | Mostly unavailable or only works with compile-time literals |
| Full Ruby stdlib such as `date`, `net/*`, `securerandom`, `pp`, `English` | Not available unless Spinel provides a package or the project provides one |
| Encoding/transcoding/unicode normalization | Mostly unavailable; Spinel assumes UTF-8 / ASCII-8BIT boundaries |
| Rich IO, console, nonblocking, descriptor flags, popen/select | Mostly unavailable as Ruby `IO`; use FFI or `sp_net` helpers where appropriate |

## Fundamental Ruby Methods Not Available in Spinel

These methods exist in Ruby docs but are incompatible with Spinel's current AOT
model or deliberately out of scope.

| Ruby API | Ruby docs area | Spinel status |
|---|---|---|
| `eval`, `instance_eval("...")`, `class_eval("...")`, `module_eval("...")` | `Kernel`, `Object`, `Module` | Runtime string evaluation is unsupported |
| `binding`, `Kernel#caller`, full `Exception#backtrace` | `Kernel`, `Exception` | No reified runtime frames; backtrace/caller support is empty or absent |
| `ObjectSpace.each_object`, `ObjectSpace.count_objects` | `ObjectSpace` | Unsupported; no class-keyed live object registry |
| `TracePoint`, `set_trace_func` | `TracePoint`, `Kernel` | Unsupported; needs interpreter-level tracing |
| `callcc`, `Continuation` | continuation library | Unsupported |
| `method_missing` dispatch | `BasicObject` / object protocol | Defining it warns; undefined calls do not dispatch through it |
| `Class.new(parent) { ... }` as runtime class creation | `Class` | Unsupported; class graph is compiled |
| Refinements: `refine`, `using`, `Module#refinements`, `Module.used_refinements` | `Module` | Unsupported/no-op/unresolved |

Probe examples:

```sh
./spinel -E -e 'eval("puts 1")'
# unsupported eval of a runtime string is not supported by AOT compilation

./spinel -E -e 'p ObjectSpace.count_objects'
# unsupported p argument: CallNode `count_objects`
```

## Object and Module Reflection Gaps

Ruby documents a rich reflective surface on `Object` and `Module`. Spinel only
supports the pieces it can resolve statically.

### Usually Not Available

| Ruby method | Notes |
|---|---|
| `Object#methods`, `#public_methods`, `#private_methods`, `#protected_methods` | Method tables are not retained as runtime objects |
| `Object#method`, `#public_method`, `#singleton_method`, `#singleton_methods` | General Method object lookup is not available |
| `Object#define_singleton_method` | Runtime singleton method creation is not available |
| `Object#singleton_class` | General singleton-class reflection is not a stable example target |
| `Object#instance_variables` | No runtime ivar-name registry |
| `Object#remove_instance_variable` | Runtime ivar-table mutation is not available |
| `Module.constants`, `Module.nesting` | General constant reflection is unsupported |
| `Module#class_variables`, `#class_variable_get`, `#class_variable_set`, `#remove_class_variable` | Dynamic class-variable reflection is not available |
| `Module#const_get`, `#const_set`, `#const_missing`, `#remove_const`, `#autoload`, `#autoload?`, `#const_source_location` | General dynamic constant APIs are not available |
| `Module#instance_methods`, `#private_instance_methods`, `#protected_instance_methods`, `#public_instance_methods` | Runtime method-list reflection is not available |
| `Module#method_defined?`, `#public_method_defined?`, `#private_method_defined?`, `#protected_method_defined?` | Only compile-time-known/literal forms may work |
| `Module#define_method` with runtime-computed names/bodies | Literal cases can work; dynamic ones cannot |
| `Module#included`, `#extended`, `#inherited` hooks | Defined but not fired according to Spinel docs |

### Partially Available

| Ruby method | Spinel rule |
|---|---|
| `send`, `public_send`, `__send__` | Literal names work; runtime names only dispatch over method-name literals already present in the compiled program |
| `instance_variable_get`, `instance_variable_set` | Literal ivar names can resolve to fixed C struct offsets; non-literal names are unsupported |
| `respond_to?` | Useful only where Spinel can reason about the target statically |

Probe examples:

```sh
./spinel -E -e 'p Object.new.methods'
# unsupported p argument: CallNode `methods`

./spinel -E -e 'p Module.constants'
# unsupported p argument: CallNode `constants`
```

## Require and Standard Library Gaps

Ruby's documented standard library is far larger than Spinel's current bundled
feature set.

### Require Works for These Bundled Features

Use `SPINEL_REQUIRE_GATE=1` when testing examples:

- `json`
- `base64`
- `digest`
- `stringio`
- `strscan`
- `set`
- `forwardable`
- `optparse`
- `erb`
- `monitor`
- `io/console` for `IO#winsize`
- `time` for `Time#iso8601`

### `optparse` captures boolean flags only, not option VALUES

`require "optparse"` compiles and runs, but the bundled subset only fires the
handler for boolean flags. For a *value-taking* option the handler block is
never called with the value, so the captured variable keeps its default.
Observed while building `source/todo_cli.rb` with a `-f FILE` option:

- `-fVALUE`, `-f VALUE`, and `--file=VALUE` all left the target variable at its
  default under Spinel, while CRuby captured the value in every form.
- Worse, `-f VALUE` left the bare `VALUE` token behind in `ARGV` after
  `parse!`, so it was then mis-read as the subcommand -- a silent, runtime-only
  dual-runtime divergence (no compile error).

Workaround (used in `todo_cli.rb`): parse value-taking flags with a small
manual `ARGV` loop -- the same dependency-free style as the server examples --
and let `optparse` handle only boolean flags, or drop it entirely. A manual
loop behaves identically under Spinel and CRuby. See
`tmp/example_apps_plan/notes_deviations.md` for the full probe log.

### Require Does Not Work for These Ruby Libraries Today

This list is not exhaustive; it captures common examples that Ruby programmers
will reach for:

- `date`
- `net/http`, `net/protocol`, `net/ftp`, and other `net/*` libraries
- `socket`
- `securerandom`
- `pp`
- `English`
- `json/pure`
- broader `time` parsing extensions such as `Time.parse` and `Time.strptime`

Probe examples:

```sh
SPINEL_REQUIRE_GATE=1 ./spinel -E -e 'require "date"; puts 1'
# spinel: cannot load such file -- date (require "date")

SPINEL_REQUIRE_GATE=1 ./spinel -E -e 'require "securerandom"; puts SecureRandom.hex(4)'
# spinel: cannot load such file -- securerandom (require "securerandom")
```

## String Method Gaps

Ruby 3.4 documents a very large `String` surface. Spinel covers many practical
methods, but not all.

### Not Available or Not Suitable for Examples

| Ruby method group | Examples |
|---|---|
| Encoding/transcoding | `encode`, `encode!`, `encoding`, `force_encoding`, non-UTF-8 conversion tables |
| Unicode normalization | `unicode_normalize`, `unicode_normalize!`, `unicode_normalized?` |
| Grapheme clusters | `each_grapheme_cluster`, `grapheme_clusters` |
| Shellwords helpers | `shellescape`, `shellsplit` |
| Ruby conversion hooks | `String.try_convert`, some `to_str` coercion cases |
| Binary-safe text transforms | Embedded-NUL strings are byte-exact for core storage, but many transforms/searches still stop at the C NUL |

Probe examples:

```sh
./spinel -E -e 'puts "é".unicode_normalize(:nfd)'
# unsupported puts argument: CallNode `unicode_normalize`

./spinel -E -e 'puts "a b".shellescape'
# unsupported puts argument: CallNode `shellescape`
```

### Available With Caveats

- `String#encode("UTF-16")` currently behaves like a no-op in a simple probe; do
  not use it to demonstrate real transcoding.
- Many bang methods do work (`upcase!` was probed), but examples should still
  verify the exact bang method they use.
- Embedded NUL bytes are fine for byte containers, file round-trips,
  pack/unpack, StringIO, and Marshal. Avoid text transforms on embedded-NUL
  strings unless the example is specifically about that limitation.

### Poly-string method dispatch (whole-program inference gap)

When a string value is inferred as *polymorphic* (`sp_RbVal`) rather than a
concrete `String` -- which happens when it is sliced out of another value and
then crosses method-return boundaries in a larger program -- Spinel dispatches
only a subset of `String` methods on it at runtime, even though `#class`
reports `String`. Observed while building `source/token_api.rb`: a token pulled
out of an HTTP `Authorization` header (`line.split(" ")[2]`, returned from a
helper, then passed to another helper) raised `undefined method 'index'` /
`'split'` at runtime.

Confirmed on such a poly string:

- Works: `#length`, single-index `#[]` (e.g. `token[char_index]`), `==`,
  `#start_with?`, string concatenation (`user + char`), and `#dup`.
- Fails at runtime: `#index`, `#split`, and range/`begin...end` slicing
  (`token[0...n]`, `token[char_index..-1]` returned a single character instead
  of a substring).

The failure is context-dependent: the same helper compiles and runs correctly
in a small standalone probe but fails inside the full program, because
whole-program inference degrades the variable's static type. `value.dup`
materializes a runtime `String` but does **not** restore the missing methods.

Workaround used in `token_api.rb`: parse the poly string with a manual
character loop that relies only on `#length`, single-index `#[]`, `==`, and
concatenation -- e.g. to split `"user.signature"` on the first `.`, walk the
characters with `char_index` and build `user` / `sig` by appending one `char`
at a time. Prefer this pattern over `#split` / `#index` / range slices whenever
a string is derived from parsed network or `recv` input and then handed across
methods.

## Array and Enumerable Gaps

Ruby's `Array` docs include many methods inherited from or related to
`Enumerable`. Spinel supports a healthy subset, but gaps remain around some
enumerator-returning combinatorics and general Enumerable behavior.

### Not Available or Limited

| Ruby method group | Examples |
|---|---|
| Enumerator-returning combinatorics | `repeated_permutation(...).to_a` is currently unsupported in a probe |
| Some matrix/shape helpers | `transpose` is currently unsupported |
| General external Enumerator from arbitrary user methods | Mostly limited to known cases such as `Array#each`, `Range#each`, and `Enumerator.new` |
| Full Enumerable set | `chunk`, `chunk_while`, `slice_when`, `grep_v`, `tally`, `to_set`, broad `lazy` chains may be missing or partial |
| Hashability of arrays | `Array#hash` and arrays as hash keys are documented as unsupported in Spinel limitations |

Probe examples:

```sh
./spinel -E -e 'p [1,2,3].transpose'
# unsupported call: CallNode `transpose`

./spinel -E -e 'p [1,2,3].repeated_permutation(2).to_a'
# unsupported p argument: CallNode `to_a` on the returned value
```

### Confirmed Available in Probes

- `[1,2,3].combination(2).to_a`
- `Array#pack`
- `Array#product`
- `Array#slice_before` / `slice_after` are backed by runtime helpers
- Common `map`, `select`, `reject`, `filter_map`, `each_with_object`, `sum`,
  `min`, `max`, `sort`, `uniq`, `shuffle`, `sample`, `union`, `difference`,
  and `intersection` forms are supported enough for examples, but verify the
  exact receiver and block shape.

## Hash Method Gaps

Ruby's `Hash` docs include default procs, identity comparison, deep transform
helpers, and conversion hooks. Spinel supports common hash use, but not the full
surface.

### Not Available or Limited

| Ruby method group | Examples |
|---|---|
| Default proc APIs | `default_proc`, `default_proc=` are unsupported in a probe |
| Identity-keyed hashing | `compare_by_identity`, `compare_by_identity?` are documented as unsupported |
| User-defined key hashing/equality | User-defined `#hash` / `#eql?` for hash keys is not dispatched |
| Dynamic conversion hooks | `Hash.try_convert`, `to_hash`, and broad coercion behavior are not reliable example targets |
| Ruby keyword helpers | `ruby2_keywords_hash`, `ruby2_keywords_hash?` are not Spinel example targets |

Probe example:

```sh
./spinel -E -e 'h = Hash.new { |hh,k| k }; p h.default_proc'
# unsupported p argument: CallNode `default_proc`
```

### Confirmed Available in Probes

- `Hash#transform_values { ... }`
- Common `#[]`, `#[]=`, `#fetch`, `#keys`, `#values`, `#each`, `#merge`,
  `#select`, `#reject`, `#compact`, `#invert`, `#slice`, `#value?`, and
  `#key?` style examples are reasonable, with exact-shape verification.

## IO and File Gaps

Ruby's `IO` and `File` docs are much wider than Spinel's core file support.
Spinel is good for simple file examples; use FFI or `sp_net` for lower-level
systems work.

### IO Methods Generally Missing

| Ruby method group | Examples |
|---|---|
| Multiplexing/process IO | `IO.select`, `IO.popen`, `IO.copy_stream` |
| Nonblocking IO | `read_nonblock`, `write_nonblock`, `wait_readable`, `wait_writable`, `nonblock`, `nonblock?` |
| Descriptor flags/control | `fcntl`, `ioctl`, `close_on_exec?`, `close_on_exec=`, `autoclose?`, `autoclose=` |
| Encoding | `external_encoding`, `internal_encoding`, `set_encoding`, `set_encoding_by_bom` |
| Rich line/char APIs | `readline`, `readlines`, `readpartial`, `getc`, `getbyte`, `ungetc`, `ungetbyte` may be missing or partial on real `IO` |
| Console controls | Most `io/console` APIs besides `winsize` are not example-safe |

Probe example:

```sh
./spinel -E -e 'p IO.select([STDIN], nil, nil, 0)'
# unsupported p argument: CallNode `select`
```

### File Methods Generally Missing

Ruby's `File` class documents many filesystem metadata and mutation methods.
Spinel examples should not assume these exist unless probed:

- `File.absolute_path`, `absolute_path?`, `basename`, `dirname`, `expand_path`,
  `extname`, `split`, `realpath`, `realdirpath`
- `File.atime`, `birthtime`, `ctime`, `lstat`, `stat`, `ftype`
- Permission/ownership predicates: `owned?`, `grpowned?`, `world_readable?`,
  `world_writable?`, `readable?`, `writable?`, `executable?`
- Special file predicates: `blockdev?`, `chardev?`, `pipe?`, `socket?`,
  `symlink?`, `setuid?`, `setgid?`, `sticky?`
- Mutators: `chmod`, `chown`, `lchmod`, `lchown`, `link`, `symlink`, `rename`,
  `truncate`, `utime`, `lutime`, `mkfifo`, `umask`

### File Methods Known to Be Useful

- `File.open`
- `File.write`
- `File.read`
- `File.exist?`
- `File.file?`
- `File.directory?`
- `File.delete`
- `File.size`
- `File.mtime` has a local test
- `File.join` has local tests

## Time Gaps

Spinel has core `Time` construction, arithmetic, comparison, accessors, and
formatting. Ruby's docs include more parsing and conversion methods.

### Missing or Partial

| Ruby method | Spinel status |
|---|---|
| `Time.parse` | Unsupported, even after `require "time"` |
| `Time.strptime` | Unsupported according to Spinel docs |
| `Time.httpdate`, `Time.rfc2822`, `Time.rfc822`, `Time.xmlschema`, `Time.iso8601` as class parsers | Not safe example targets |
| `Time.zone_offset` | Not safe example target |
| `Time#to_date`, `Time#to_datetime` | Depends on `date`; unavailable |
| `Time#as_json`, `Time#to_json`, `Time.json_create` | Not safe unless an example verifies JSON integration explicitly |
| Subsecond exactness methods | `subsec`, `nsec`, `tv_nsec`, `usec`, `tv_usec`, `to_r`, rounding methods may be missing or partial |

Probe example:

```sh
SPINEL_REQUIRE_GATE=1 ./spinel -E -e 'require "time"; p Time.parse("2020-01-01")'
# unsupported p argument: CallNode `parse`
```

## Regexp and MatchData Gaps

Spinel's regexp support is useful and much broader than a placeholder, but it
does not cover every Ruby regexp feature.

### Regexp Gaps

| Ruby method/feature | Spinel status |
|---|---|
| `Regexp.timeout`, `Regexp.timeout=` and per-regexp timeout behavior | Not a safe example target |
| `Regexp.linear_time?` | Not a safe example target |
| `Regexp.try_convert` | Not a safe example target |
| `Regexp.union` with flagged regexp operands or runtime/non-string operands | Documented as unsupported in compiler source |
| Full Onigmo syntax | Atomic groups, subexpression calls, conditionals, absence operator, advanced Unicode property handling may be missing |
| Encoding-sensitive regexp behavior | Limited by Spinel's UTF-8 / ASCII-8BIT model |

### MatchData Gaps

Ruby documents `MatchData#regexp`, `#string`, `#match`, `#match_length`,
`#deconstruct`, `#deconstruct_keys`, `#values_at`, and hash/equality behavior.
Spinel supports common capture access, names, offsets, `to_a`, `captures`,
`pre_match`, and `post_match`, but not the full method set.

Probe example:

```sh
./spinel -E -e 'm = /(?<x>a)/.match("a"); p m.regexp'
# unsupported p argument: CallNode `regexp`
```

Confirmed available in probes:

- `Regexp#source`
- `Regexp#options`
- `MatchData#named_captures`

## Integer and Numeric Gaps

Spinel supports normal integer arithmetic well, including bigint promotion modes
when configured, but Ruby's exact numeric tower is richer.

| Ruby method/behavior | Spinel status |
|---|---|
| `Integer#**` with negative exponent | Raises `RangeError`; CRuby returns a `Rational` |
| Bigint-backed `Rational` precision | Spinel `Rational` uses fixed integer numerator/denominator and can overflow |
| Exact `Complex` component preservation | Spinel stores complex components as floats |
| `Integer#chr` with runtime/non-constant or unsupported encoding | Documented as unsupported in compiler source |
| GMP introspection such as `Integer::GMP_VERSION` | Not an example target |

## Libraries and Methods to Prefer in Future Examples

Prefer these because they are supported and already fit Spinel's design:

- CLI parsing: `require "optparse"` for boolean-only flags, or manual `ARGV`
  parsing for any flag that takes a value (the optparse subset does not capture
  option values -- see the optparse note above)
- JSON: `require "json"`
- Base64: `require "base64"`
- Digests: `require "digest"` for SHA1/SHA256 hexdigest
- In-memory IO: `require "stringio"`
- Tokenizing/parsing: `require "strscan"`
- Sets: `require "set"`
- Static file work: `File.read`, `File.write`, `File.exist?`,
  `File.directory?`, `File.file?`, `File.size`, `File.join`
- Networking: use the local `socket_shim.rb` compatibility layer for
  `TCPServer` / accepted socket methods; expand it or promote it into Spinel
  when examples need more of Ruby's `socket` API
- Crypto helpers beyond `Digest`: FFI through a small `SpinelCrypto` wrapper

## Method Probe Checklist for New Examples

Before using a Ruby method not already covered by examples, run a tiny probe:

```sh
SPINEL_REQUIRE_GATE=1 /Users/branden/Projects/spinel/spinel -E -e 'require "feature"; ...'
```

If the probe fails with `unsupported ... CallNode`, `undefined method`, or
`cannot load such file`, either:

- use a smaller supported Ruby surface,
- add a Spinel package,
- expose a native helper through FFI,
- or document the example as demonstrating an intentional limitation.
