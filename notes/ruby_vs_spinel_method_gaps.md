# Ruby vs Spinel Method Gaps

This note compares Ruby 3.4 documentation against the installed Spinel compiler
(asdf `master` channel, source commit `4b927b80`).

> **Re-probed against installed Spinel master (source `4b927b80`).**
> The prior audit covered `9127c7f1`. The sections below reflect what a
> comprehensive probe of the installed binary found. Summary of changes since
> `9127c7f1`:
>
> - **Error messages are now much richer.** Failures that used to say "unsupported
>   CallNode `foo`" now give a full sentence explaining *why* the feature is absent,
>   often with a `docs/limitations.md` reference.
> - **`send`/`public_send` now work** for both built-in and user-defined methods
>   when the method name is a compile-time symbol literal.
> - **`respond_to?` on instances now works** reliably.
> - **`method(:name)` and `obj.method(:name)` now return working `Method` objects**;
>   `.call` and `&method(:name)` both work.
> - **`:sym.to_proc` now works** when the symbol names a real method; the `&:method`
>   shorthand is fully supported.
> - **Lazy enumerators** (`(1..Float::INFINITY).lazy.select {...}.first(n)`) confirmed
>   working.
> - **`optparse` is currently broken** — any call to `parse!` fails at C compile time
>   with a type error, including programs that use only boolean flags. Root cause
>   identified: the compiler's poly-receiver `.call()` dispatch path doesn't handle
>   `TY_POLY` arguments (see the `optparse` section below). The workaround is a manual
>   `ARGV` loop.

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
| Basic strings, arrays, hashes, ranges, numbers, regexp, file reads/writes, math | Broadly available — most of the practical surface works |
| `json`, `base64`, `digest`, `stringio`, `strscan`, `set`, `forwardable`, `io/console` | Available through `require` with `SPINEL_REQUIRE_GATE=1` |
| `optparse` | Currently broken — `parse!` fails at C compile time even with boolean-only flags; use a manual `ARGV` loop |
| `send`, `public_send`, `respond_to?`, `method(:name)`, `&:sym`, `obj.method(:name).call` | Work when method name is a compile-time literal |
| Lazy enumerators | Work: `(1..Float::INFINITY).lazy.select {...}.first(n)` confirmed |
| Socket/network helpers | `require "socket"` natively provides `TCPServer.new` + `accept` + `write`/`gets`/`fileno`/`close`; `TCPServer.open` block form and `recv` are NOT available natively. For HTTP servers use `lib/socket_tcp.rb` (adds `TCPServer.open` + `recv` via `sp_net_*`). For raw `Socket`/UDP/Unix use `lib/socket_shim.rb` |
| Reflection and metaprogramming | Mostly unavailable or only works with compile-time literals |
| Full Ruby stdlib (`date`, `net/*`, `securerandom`, `yaml`, `csv`, `fileutils`, `pp`, `uri`, `cgi`, `socket`) | Not available unless Spinel provides a package |
| Encoding/transcoding/unicode normalization | Unavailable; Spinel assumes UTF-8 / ASCII-8BIT boundaries |
| Rich IO, nonblocking, descriptor flags, `IO.select`, `IO.popen` | Mostly unavailable as Ruby `IO`; use FFI or `sp_net` helpers |
| `Process.uid/gid/euid/egid`, `$:/LOAD_PATH`, `$?.success?` | Not available |

## Fundamental Ruby Methods Not Available in Spinel

These methods exist in Ruby docs but are incompatible with Spinel's current AOT
model or deliberately out of scope. Error messages are now descriptive — Spinel
explains the structural reason and points to `docs/limitations.md`.

| Ruby API | Ruby docs area | Spinel status |
|---|---|---|
| `eval`, `instance_eval("...")`, `class_eval("...")`, `module_eval("...")` | `Kernel`, `Object`, `Module` | "unsupported eval of a runtime string is not supported by AOT compilation" |
| `binding`, `Kernel#caller`, full `Exception#backtrace` | `Kernel`, `Exception` | No reified runtime frames |
| `ObjectSpace.each_object`, `ObjectSpace.count_objects` | `ObjectSpace` | "ObjectSpace is not supported by AOT compilation: there is no class-keyed allocation registry to walk" |
| `TracePoint`, `set_trace_func` | `TracePoint`, `Kernel` | "TracePoint is not supported by AOT compilation: it requires an interpreter loop" |
| `callcc`, `Continuation` | continuation library | "Kernel#callcc is not supported by AOT compilation: multi-shot full-stack capture has no flat-C analogue" |
| `method_missing` dispatch | `BasicObject` / object protocol | Defining it warns; undefined calls do not dispatch through it |
| `Class.new(parent) { ... }` as runtime class creation | `Class` | Unsupported; class graph is compiled |
| Refinements: `refine`, `using`, `Module#refinements` | `Module` | Unsupported/no-op |

Probe examples:

```sh
spinel -E -e 'eval("puts 1")'
# spinel: unsupported eval of a runtime string is not supported by AOT compilation

spinel -E -e 'ObjectSpace.count_objects'
# spinel: ObjectSpace is not supported by AOT compilation: there is no class-keyed allocation registry to walk (see docs/limitations.md)

spinel -E -e 'TracePoint.new(:call) {}'
# spinel: TracePoint is not supported by AOT compilation: it requires an interpreter loop (see docs/limitations.md)
```

## Object and Module Reflection

Ruby documents a rich reflective surface on `Object` and `Module`. Spinel only
supports the pieces it can resolve statically.

### Now Working (changed since 9127c7f1)

These were listed as partial or unavailable in the prior audit:

```sh
# send / public_send — work with literal method names
spinel -E -e 'puts 42.send(:to_s)'               # => 42
spinel -E -e 'puts "hi".send(:upcase)'            # => HI
spinel -E -e 'puts [1,2].send(:length)'           # => 2
spinel -E -e 'puts 42.public_send(:to_s)'         # => 42

# respond_to? — works on instances
spinel -E -e 'puts "hi".respond_to?(:upcase)'     # => true
spinel -E -e 'puts "hi".respond_to?(:nonexistent)' # => false
spinel -E -e 'puts 42.respond_to?(:to_s)'         # => true

# method() objects — both top-level and instance-bound
spinel -E -e 'puts method(:puts).class'           # => Method
spinel -E -e 'puts "hi".method(:upcase).class'    # => Method
spinel -E -e 'm = "hello".method(:upcase); puts m.call'  # => HELLO
spinel -E -e 'f = method(:puts); f.call("hello")' # => hello

# Symbol#to_proc and &:sym shorthand
spinel -E -e 'puts :upcase.to_proc.call("hello")' # => HELLO
spinel -E -e 'puts [:a,:b].map(&:to_s).inspect'   # => ["a", "b"]
spinel -E -e 'puts [1,2,3].map(&:to_s).inspect'   # => ["1", "2", "3"]

# &method()
spinel -E -e 'puts [1,2,3].map(&method(:puts))'   # prints 1, 2, 3
```

### Still Not Available

| Ruby method | Notes |
|---|---|
| `Object#methods`, `#public_methods`, `#private_methods` | Method tables are not retained as runtime objects |
| `Object#singleton_method`, `#singleton_methods` | Runtime singleton-method lookup unsupported |
| `Object#define_singleton_method` | "Object#define_singleton_method is not supported by AOT compilation" |
| `Object#singleton_class` | General singleton-class reflection unavailable |
| `Object#instance_variables` | No runtime ivar-name registry |
| `Module.constants`, `Module.nesting` | General constant reflection unsupported |
| `Module#class_variables`, `#class_variable_get/set` | Dynamic class-variable reflection unavailable |
| `Module#const_get`, `#const_set`, `#const_missing` | Dynamic constant APIs unavailable |
| `Module#instance_methods`, `#method_defined?` (with runtime args) | Only compile-time-known literal forms may work |
| `Module#define_method` with runtime names/bodies | Literal cases can work; dynamic ones cannot |
| `Kernel.respond_to?` (class-level) | Fails — only instance-level `respond_to?` works |
| `Process.uid`, `Process.gid`, `Process.euid`, `Process.egid` | "unsupported call: CallNode `uid`" — use `` `id -u`.strip.to_i `` as a workaround |
| `$:` / `$LOAD_PATH` | "undefined identifier 'gv_LOAD_PATH'" in generated C |
| `$?.success?` | `$?` returns an Integer (0 or 256), not a `Process::Status` object; `.success?` raises NoMethodError |
| `:sym.to_proc` when symbol does not name a real method | Works for real method names; calling `.sym` on an object that has no method named `sym` gives NoMethodError (expected) |

Probe examples:

```sh
spinel -E -e 'puts Process.uid'
# unsupported call: CallNode `uid`

spinel -E -e 'system("true"); puts $?.success?'
# NoMethodError: undefined method 'success?' for an instance of Integer

spinel -E -e 'puts $:.class'
# C compilation failed: undefined identifier 'gv_LOAD_PATH'
```

## Require and Standard Library

### Require Works for These Bundled Features

Use `SPINEL_REQUIRE_GATE=1` when running programs that contain `require`:

- `socket` — natively provides:
  - `TCPSocket.new(host, port)` — outbound client connections ✓
  - `TCPServer.new(port)` or `TCPServer.new(host, port)` — binds and listens ✓
  - `server.accept` → returns a `TCPSocket` ✓
  - `socket.write(str)`, `socket.gets`, `socket.fileno`, `socket.close` ✓
  - `TCPServer.open` block form — NOT available (runtime `NameError`)
  - `socket.recv(n)` — NOT available (compile error)
  - `socket.readpartial(n)` — compiles but blocks until peer closes (FIN), not suitable for HTTP servers
  - `Socket` (raw), `UDPSocket`, `UNIXSocket` — NOT available (runtime `NameError`)
  - None of `TCPSocket`/`TCPServer`/`Socket` are accessible as Ruby constants (`defined?` returns nil)
  - For HTTP servers use `lib/socket_tcp.rb` (adds `TCPServer.open` + `recv` via `sp_net_*`, no gate needed)
  - For raw `Socket`/UDP/Unix use `lib/socket_shim.rb`
- `json`
- `base64`
- `digest`
- `stringio`
- `strscan`
- `set`
- `forwardable`
- `io/console` for `IO#winsize`

### `optparse` is currently broken — any use of `parse!` fails

`require "optparse"` and `OptionParser.new` both load fine. But any call to
`parse!` — even with an empty block and no options registered — fails at C
compile time with:

```
error: passing 'sp_RbVal' to parameter of incompatible type 'mrb_int'
```

The root cause is in `src/codegen_call.c` in the `!has_user_call` dispatch path
for calling `.call()` on a poly receiver (`@handlers[j].call(...)`). That path
generates a BoundMethod/Proc ternary but its argument-emission loops only handle
`TY_INT`, `TY_BOOL`, and pointer types — not `TY_POLY` (`sp_RbVal`). When
`argv[i]` or a string slice is passed as an argument, it has type `TY_POLY` and
falls through to a bare `emit_expr`, which dumps an `sp_RbVal` struct into an
`mrb_int` slot.

Two possible fixes:
- **In `optparse.rb`**: coerce poly string args before calling handlers —
  `@handlers[j].call("" + value)` and `@handlers[j].call("" + argv[i])`.
  `TY_STRING` is handled correctly by `proc_slot_is_ptr`.
- **In `codegen_call.c`** (root fix): add a `TY_POLY` case in the two argument
  loops at lines 7112 and 7122, or replace the inline loop with a call to
  `emit_proc_call_args(c, argc, argv, b, 1)` which already handles poly correctly.

Workaround for programs: use a manual `ARGV` loop. It behaves identically under
Spinel and CRuby and has no dependency on the broken dispatch path.

### Require Does Not Work for These Ruby Libraries

Common libraries that Ruby programmers reach for but Spinel does not ship:

- `date`
- `yaml`
- `csv`
- `fileutils`
- `tmpdir`
- `open3`
- `shellwords`
- `pathname`
- `pp`
- `English`
- `observer`
- `singleton`
- `net/http`, `net/protocol`, and other `net/*` libraries
- `socket` — partially works; see "Require Works" section for full breakdown. Raw `Socket`, `UDPSocket`, `UNIXSocket` are not available natively.
- `uri`
- `cgi`
- `erb` (loads but crashes at compile)
- `securerandom`
- `time` (loads, but `Time.parse` / `Time.strptime` do not work)

Probe examples:

```sh
SPINEL_REQUIRE_GATE=1 spinel -E -e 'require "date"; puts 1'
# spinel: cannot load such file -- date

SPINEL_REQUIRE_GATE=1 spinel -E -e 'require "time"; Time.parse("2023-01-01")'
# unsupported call: CallNode `parse`
```

## String Methods

Most practical String methods work. The gaps are in encoding, Unicode, and
shell helpers.

### Not Available

| Ruby method group | Spinel status |
|---|---|
| `String#unicode_normalize`, `#unicode_normalize!`, `#unicode_normalized?` | "Unicode normalization requires shipping the Unicode decomposition/composition tables, which spinel deliberately does not carry (see docs/limitations.md)" |
| `String#grapheme_clusters`, `#each_grapheme_cluster` | Splits by codepoint, not by extended grapheme cluster — do not use for real grapheme work |
| `String#shellescape`, `String#shellsplit` | Unavailable; `shellwords` cannot be loaded |
| `String#encoding` changes via `force_encoding` or `#b` | The methods run without error but the encoding does not actually change — always reports UTF-8 |
| `String.try_convert`, some `to_str` coercion cases | Not reliable example targets |
| NUL as a stream delimiter | Writing NUL bytes to stdout or using `"\0"` as a line separator is impossible — see below |

Probe examples:

```sh
spinel -E -e 'puts "é".unicode_normalize(:nfd)'
# String#unicode_normalize is not supported: Unicode normalization requires
# shipping the Unicode decomposition/composition tables, which spinel
# deliberately does not carry (see docs/limitations.md)

SPINEL_REQUIRE_GATE=1 spinel -E -e 'require "shellwords"; puts "a b".shellescape'
# cannot load such file -- shellwords
```

### Available (confirmed in probes)

All of these work correctly:

```sh
spinel -E -e 'puts "abc".center(7, "-")'          # => --abc--
spinel -E -e 'puts "hello".delete("l")'            # => heo
spinel -E -e 'puts "hello".squeeze'                # => helo
spinel -E -e 'puts "hello\n".chop'                 # => hello
spinel -E -e 'puts "hello".succ'                   # => hellp
spinel -E -e 'puts "%05d" % 42'                    # => 00042
spinel -E -e 'puts "hello".gsub(/[aeiou]/) { |m| m.upcase }'  # => hEllO
spinel -E -e 'puts "hello".tr("aeiou", "*")'       # => h*ll*
spinel -E -e 'puts "hello world".split(" ", 2).inspect'        # => ["hello", "world"]
spinel -E -e 'puts "  hi  ".lstrip'                # => "hi  "
spinel -E -e 'puts "  hi  ".rstrip'                # => "  hi"
spinel -E -e 'puts "hi".ljust(6, ".")'             # => hi....
spinel -E -e 'puts "hi".rjust(6, ".")'             # => ....hi
spinel -E -e 'puts "hello".count("l")'             # => 2
spinel -E -e 'puts "hello".chars.inspect'           # => ["h", "e", "l", "l", "o"]
spinel -E -e 'puts "hello".bytes.inspect'           # => [104, ...]
spinel -E -e 'puts "hello".encoding'               # => UTF-8
```

### NUL Bytes as Stream Delimiters — Fundamentally Unsupported

Spinel compiles Ruby to C. In C, strings are NUL-terminated: the byte `\0`
marks the end of a character array, so it can never appear as content within
one. This has a concrete consequence for any feature that treats NUL as a
record separator rather than a string terminator:

- **`STDOUT.write("\0")`** — the NUL byte is swallowed; nothing is written.
- **`content.split("\0")`** — splits only on the first NUL and discards
  everything after it, because the underlying C string already ends there.
- **`content.lines` with NUL-delimited data** — returns the entire input as a
  single "line" up to the first NUL.

The `-z` / `--zero-terminated` flag found in GNU coreutils (`head -z`,
`tail -z`, `grep -z`, `sort -z`, etc.) uses NUL as the line delimiter so that
filenames or records containing newlines can be processed safely. **This flag
cannot be implemented in a Spinel-compiled binary.** It is not a missing
feature that could be added later with more effort — the limitation is
structural: the C runtime itself prevents NUL from appearing in any string
value or being written to standard output.

### Poly-string method dispatch (whole-program inference gap)

When a string value is inferred as *polymorphic* (`sp_RbVal`) rather than a
concrete `String` — which happens when it is sliced out of another value and
then crosses method-return boundaries in a larger program — Spinel dispatches
only a subset of `String` methods on it at runtime, even though `#class`
reports `String`. Observed while building `source/token_api.rb`: a token pulled
out of an HTTP `Authorization` header (`line.split(" ")[2]`, returned from a
helper, then passed to another helper) raised `undefined method 'index'` /
`'split'` at runtime.

Confirmed on such a poly string:

- Works: `#length`, single-index `#[]` (e.g. `token[char_index]`), `==`,
  `#start_with?`, string concatenation (`user + char`). `#dup` compiles and
  runs but returns another `sp_RbVal` — it does not restore the missing methods
  (see coercion section below).
- Fails at runtime: `#index`, `#split`, and range/`begin...end` slicing
  (`token[0...n]`, `token[char_index..-1]` returned a single character instead
  of a substring).

The failure is context-dependent: the same helper compiles and runs correctly
in a small standalone probe but fails inside the full program, because
whole-program inference degrades the variable's static type.

If a function only needs `#length`, `#[]`, `==`, and concatenation, no
coercion is required — use the poly string directly. `.dup` is unnecessary
in that case and can be removed safely.

Workaround: parse the poly string with a manual character loop that relies only
on `#length`, single-index `#[]`, `==`, and concatenation — e.g. to split
`"user.signature"` on the first `.`, walk the characters with `char_index` and
build `user` / `sig` by appending one `char` at a time. Prefer this pattern
over `#split` / `#index` / range slices whenever a string is derived from
parsed network or `recv` input and then handed across methods.

### sp_RbVal propagation through multi-call-site functions

A subtler form of the same problem: if a function is called from multiple call
sites with different argument types — one site passes a typed `String`, another
passes an `sp_RbVal` (e.g. `lines[n]`, an ARGV element, or a return from
another polymorphic helper) — Spinel infers the **parameter** type as
`sp_RbVal` for the whole function. This propagates to all nested calls:

```
make_sort_value(body, opts)        # body is sp_RbVal: inferred from lines[n] call site
  → extract_key_text(body, opts)   # body is sp_RbVal
    → split_fields(body, opts.sep) # line is sp_RbVal
      → line.split(" ")            # runtime dispatch fails — split not in dispatch table
```

The runtime error is `undefined method 'split' for an instance of String
(NoMethodError)` — confusing because `class` reports `String`, but the method
was compiled as a direct typed call, not registered in the runtime dispatch table.

**Fix: coerce at function entry.** Add `cbody = "" + body` at the start of
every function that may receive sp_RbVal but needs to call String methods:

```ruby
def make_sort_value(body, opts)
  cbody = "" + body  # coerce immediately; body may be sp_RbVal from lines[n]
  ...
end
```

Similarly for `split_fields`:
```ruby
def split_fields(line, sep)
  typed_line = "" + line
  sep.nil? ? typed_line.split(" ") : typed_line.split("" + sep)
end
```

**Alternative:** remove the sp_RbVal call site by coercing there:
```ruby
a = make_sort_value("" + lines[n], opts)
```
Either approach works; function-entry coercion is more defensive.

### `Array#reverse!` and other mutating Array methods

`Array#reverse!` (in-place reverse) is not available in Spinel. Use the
non-mutating form and reassign:

```ruby
# Fails at runtime or compile time:
sorted.reverse! if opts.sort_reverse

# Correct:
sorted = sorted.reverse if opts.sort_reverse
```

Other mutating methods to watch for: `sort!`, `uniq!`, `flatten!`, `compact!`,
`map!`. Prefer the non-mutating equivalents with reassignment.

### Multi-return parse_argv and typed object degradation

Returning `[opts, files]` from a `parse_argv` function and unpacking with
multi-assign (`opts, files = parse_argv(ARGV)`) makes **both** variables
sp_RbVal, even when the function creates typed objects internally. Even the
explicit-indexing workaround (`r = parse_argv(ARGV); opts = r[0]`) yields
sp_RbVal — **array element access always degrades to sp_RbVal**.

**Canonical pattern:** pre-declare the typed object before the call and pass it
by reference. Return only the remaining untyped values (or use globals for
scalar extras):

```ruby
# Before (breaks in Spinel):
opts, files = parse_argv(ARGV)   # opts is sp_RbVal — opts.field fails

# After:
opts = SortOptions.new           # typed at the point of declaration
files = parse_argv(ARGV, opts)   # parse_argv modifies opts in place; returns only files

# In parse_argv:
def parse_argv(argv, opts)       # no local "opts = SortOptions.new"
  files = []
  # set opts.field = ... directly
  files                          # return only files (StrArray, properly typed)
end
```

For extra scalar return values (`files0_from`, `total_when`), use module-level
globals:
```ruby
$wc_files0_from = nil
$wc_total_when  = "auto"

def parse_argv(argv, selection)
  ...
  $wc_files0_from = arg[14, ...]
  $wc_total_when  = tw
  files
end

selection = WcSelection.new
files = parse_argv(ARGV, selection)
files0_from = $wc_files0_from  # sp_RbVal but coercible: "" + files0_from
total_when  = "" + $wc_total_when.to_s
```

**Corollary — avoid arrays of typed objects.** Indexing `opts.sort_keys[0]`
yields sp_RbVal even if `sort_keys` is a typed SortKey array. Instead, inline
the fields directly on the options object: `opts.sk_field`, `opts.sk_numeric`,
`opts.sk_fold_case`, etc.

### AOT compile-time type coercion: `"" + s` or `"#{s}"`, not `s.dup`

When a string crosses a function boundary (e.g. ARGV elements, array index
access like `files[0]`, or range slices like `s[2, s.length - 2]`), Spinel
types the value as `sp_RbVal`. Passing it to `File.read`, `File.exist?`,
`Dir.mkdir`, or most other C-backed calls then fails with:

```
error: passing 'sp_RbVal' to parameter of incompatible type 'const char *'
```

**Correct coercion idioms:**

`"" + s` — typed receiver forces the result to `const char *`:
```ruby
cname = "" + name   # sp_RbVal → const char*
File.exist?(cname)  # now OK
```

`"#{s}"` — string interpolation also coerces; confirmed in `source/parallel_digest.rb`
where `queue.pop` returns `sp_RbVal` and `File.read` needs `const char *`:
```ruby
path = "#{item}"      # sp_RbVal → const char*
File.read(path)       # now OK
```

Both idioms work. `"" + s` is explicit about intent; `"#{s}"` is natural when
building a string anyway (e.g. `"#{dir}/#{name}"`).

**Why `s.dup` does NOT coerce:** when `s` is `sp_RbVal`, `s.dup` returns
`sp_RbVal` (dynamic dispatch keeps the poly type). Confirmed by removing
`.dup` from loops in `parallel_digest.rb` and `token_api.rb` — the binaries
compiled and produced identical output, because those loops only call `#length`,
`#[]`, `==`, and concatenation, which dispatch correctly on poly strings.
Only use `.dup` when `s` is already a typed `const char *` and you need a copy.

**Other coercion patterns:**
- `"" + s[n, len]` — range slices also produce `sp_RbVal`; wrap in `"" + `
- For `+=` with a poly right-hand side: use `str = str + poly` not `str += poly`
- For empty arrays that get wrongly typed as `Array<mrb_int>`: use a push-pop
  hint in `initialize` — `@arr = []; @arr.push(Element.new); @arr.pop`
- Lambda closures degrade closed-over variable types to `sp_RbVal`. Extract
  the lambda body into a standalone method with explicit parameters instead.

### User-defined `class TCPServer` must inherit from another user class

Spinel has a built-in C struct type `sp_TCPServer`. If you define `class TCPServer`
in Ruby with no parent, Spinel maps your class to that native struct. In `ensure`
blocks, Spinel defensively initializes a null variable before the guarded code runs:

```c
sp_TCPServer lv__server = NULL;  // error: struct can't be NULL-initialized
```

This fails because `sp_TCPServer` is a value struct, not a pointer. The fix is to
give your TCPServer class a user-defined parent so Spinel treats it as a regular Ruby
object (pointer) instead of the native struct:

```ruby
class TCPSocket
  def initialize(fd); @fd = fd; end
  # ...
end

class TCPServer < TCPSocket  # inheritance breaks the sp_TCPServer mapping
  def initialize(host_or_port, port = nil)
    fd = SpinelTCP.sp_net_listen(port || host_or_port, 1)
    super(fd)
  end
  # ...
end
```

See `source/lib/socket_tcp.rb` for the full pattern.

The same struct-collision concern applies to any user class named to match a
Spinel built-in type (e.g. `TCPSocket`, `File`, `Array`). In practice TCPServer is
the one that bites because it's the only one that appears in `ensure` blocks as a
freshly-bound local variable.

## Array and Enumerable

Spinel's array and enumerable coverage is very broad. Most of the practical
surface works.

### Confirmed Working (comprehensive probe)

```sh
# Core iteration and transformation
spinel -E -e 'puts [1,2,3].map { |x| x*2 }.inspect'       # [2, 4, 6]
spinel -E -e 'puts [1,2,3].select { |x| x>1 }.inspect'    # [2, 3]
spinel -E -e 'puts [1,2,3].reject { |x| x>1 }.inspect'    # [1]
spinel -E -e 'puts [1,2,3].reduce(0) { |s,x| s+x }'       # 6
spinel -E -e 'puts [[1,2],[3,4]].flat_map { |a| a }.inspect' # [1, 2, 3, 4]
spinel -E -e 'puts [1,2,3].filter_map { |x| x*2 if x>1 }.inspect' # [4, 6]
spinel -E -e 'puts [1,2,3].each_with_index.map { |x,i| [i,x] }.inspect'

# Ordering and shape
spinel -E -e 'puts [3,1,2].sort.inspect'                    # [1, 2, 3]
spinel -E -e 'puts [3,1,2].sort_by { |x| -x }.inspect'     # [3, 2, 1]
spinel -E -e 'puts [1,[2,[3]]].flatten.inspect'             # [1, 2, 3]
spinel -E -e 'puts [1,2,2,3].uniq.inspect'                  # [1, 2, 3]
spinel -E -e 'puts [1,2,3].zip([4,5,6]).inspect'            # [[1,4],[2,5],[3,6]]
spinel -E -e 'puts [1,2,3].reverse.inspect'
spinel -E -e 'puts [1,2,3].rotate(1).inspect'               # [2, 3, 1]

# Take/drop
spinel -E -e 'puts [1,2,3].take(2).inspect'                 # [1, 2]
spinel -E -e 'puts [1,2,3].drop(2).inspect'                 # [3]
spinel -E -e 'puts [1,2,3].first(2).inspect'
spinel -E -e 'puts [1,2,3].last(2).inspect'

# Predicates
spinel -E -e 'puts [1,2,3].any? { |x| x>2 }'
spinel -E -e 'puts [1,2,3].all? { |x| x>0 }'
spinel -E -e 'puts [1,2,3].none? { |x| x>3 }'

# Counting/finding
spinel -E -e 'puts [1,2,3].count { |x| x>1 }'
spinel -E -e 'puts [1,2,3].min; puts [1,2,3].max; puts [1,2,3].sum'
spinel -E -e 'puts [1,2,3].include?(2); puts [1,2,3].index(2)'
spinel -E -e 'puts [1,2,3].tally.inspect'                   # {1=>1, 2=>1, 3=>1}

# Chunk/slice/windows
spinel -E -e 'puts [1,2,3].each_slice(2).to_a.inspect'      # [[1,2],[3]]
spinel -E -e 'puts [1,2,3].each_cons(2).to_a.inspect'       # [[1,2],[2,3]]
spinel -E -e 'puts [1,1,2,3,3].chunk_while { |a,b| a==b }.to_a.inspect'

# Combinations
spinel -E -e 'puts [1,2,3].combination(2).to_a.inspect'
spinel -E -e 'puts [1,2,3].permutation(2).to_a.inspect'
spinel -E -e 'puts [1,2].repeated_permutation(2).to_a.inspect'
spinel -E -e 'puts [[1,2],[3,4]].transpose.inspect'         # [[1,3],[2,4]]

# Lazy infinite sequences
spinel -E -e 'puts (1..Float::INFINITY).lazy.select { |x| x.odd? }.first(3).inspect'  # [1, 3, 5]

# Arrays as hash keys
spinel -E -e 'h=Hash.new(0); h[[1,2]]+=1; h[[1,2]]+=1; puts h[[1,2]]'  # 2
```

### Not Available or Limited

| Ruby method group | Examples |
|---|---|
| General external Enumerator from arbitrary user methods | Mostly limited to known cases such as `Array#each`, `Range#each` |

## Hash Methods

Spinel's hash coverage is very broad for the practical surface.

### Confirmed Working

```sh
spinel -E -e 'h={a:1,b:2}; puts h.transform_values { |v| v*10 }.inspect'  # {a:10,b:20}
spinel -E -e 'h={a:1,b:2}; puts h.transform_keys { |k| k.to_s }.inspect'  # {"a"=>1,"b"=>2}
spinel -E -e 'h={a:1,b:2}; puts h.select { |k,v| v>1 }.inspect'
spinel -E -e 'h={a:1,b:2}; puts h.reject { |k,v| v>1 }.inspect'
spinel -E -e 'h={a:1,b:2}; puts h.merge({c:3}).inspect'
spinel -E -e 'h={a:1,b:2}; puts h.min_by { |k,v| v }.inspect'
spinel -E -e 'h={a:1,b:2}; puts h.sort_by { |k,v| v }.inspect'
spinel -E -e 'h={a:1,b:2}; puts h.count { |k,v| v>1 }'
spinel -E -e 'h={a:1,b:2}; puts h.sum { |k,v| v }'
spinel -E -e 'h={a:1,b:2}; puts h.flat_map { |k,v| [k,v] }.inspect'
spinel -E -e 'h={a:1,b:2}; puts h.filter_map { |k,v| v if v>1 }.inspect'
spinel -E -e 'h={a:1}; h.delete(:a); puts h.inspect'
spinel -E -e 'h={}; h["x"]=1; puts h.inspect'
```

### Not Available or Limited

| Ruby method group | Notes |
|---|---|
| Default proc APIs | `default_proc`, `default_proc=` are unsupported |
| Identity-keyed hashing | `compare_by_identity`, `compare_by_identity?` are unsupported |
| User-defined key hashing/equality | User-defined `#hash` / `#eql?` for hash keys is not dispatched |
| Dynamic conversion hooks | `Hash.try_convert`, `to_hash` are not reliable |

## IO and File

### File Methods — Broad Coverage Confirmed

Most `File` class and path methods work:

```sh
# Predicates
spinel -E -e 'puts File.exist?("/etc/hosts")'
spinel -E -e 'puts File.directory?("/tmp")'
spinel -E -e 'puts File.file?("/etc/hosts")'
spinel -E -e 'puts File.readable?("/etc/hosts")'
spinel -E -e 'puts File.writable?("/tmp")'
spinel -E -e 'puts File.symlink?("/etc/hosts")'
spinel -E -e 'puts File.executable?("/bin/sh")'
spinel -E -e 'puts File.zero?("/dev/null")'
spinel -E -e 'puts File.size("/etc/hosts") > 0'

# Path helpers
spinel -E -e 'puts File.basename("/tmp/foo.txt")'          # foo.txt
spinel -E -e 'puts File.basename("/tmp/foo.txt", ".txt")'  # foo
spinel -E -e 'puts File.dirname("/tmp/foo.txt")'            # /tmp
spinel -E -e 'puts File.extname("/tmp/foo.txt")'            # .txt
spinel -E -e 'puts File.join("a", "b", "c")'               # a/b/c
spinel -E -e 'puts File.expand_path("~")'
spinel -E -e 'puts File.absolute_path(".")'
spinel -E -e 'puts File.split("/tmp/foo.txt").inspect'      # ["/tmp", "foo.txt"]
spinel -E -e 'puts File.fnmatch("*.txt", "foo.txt")'        # true

# Read/write
spinel -E -e 'puts File.read("/etc/hosts").length > 0'
spinel -E -e 'puts File.readlines("/etc/hosts").length > 0'
spinel -E -e 'f = File.open("/tmp/t.txt","w"); f.write("hi\n"); f.close'
spinel -E -e 'puts IO.read("/etc/hosts").length > 0'
spinel -E -e 'puts open("/etc/hosts").class'                # File
```

**FFI workaround for syscall-level File ops:** For syscalls not exposed by Spinel's Ruby surface (e.g. `readlink`, `symlink`, `link`, `chmod`, `stat` details), write a small C extension with `native_func` in a user-defined module. See `notes/ffi_and_require_reference.md` for the pattern and constraints.

### IO Methods Missing

| Ruby method group | Examples |
|---|---|
| Multiplexing/process IO | `IO.select`, `IO.popen`, `IO.copy_stream` |
| Nonblocking IO | `read_nonblock`, `write_nonblock`, `wait_readable`, `wait_writable` |
| Descriptor flags/control | `fcntl`, `ioctl`, `close_on_exec?`, `autoclose?` |
| Rich line/char APIs | `readline`, `readpartial`, `getc`, `getbyte`, `ungetc` may be missing or partial |

## Time

Spinel has core `Time` construction, arithmetic, comparison, accessors, and
formatting. Parsing is unavailable.

### Confirmed Working

```sh
spinel -E -e 'puts Time.now.class'                           # Time
spinel -E -e 'puts Time.now.year'
spinel -E -e 'puts Time.now.strftime("%Y-%m-%d").length'     # 10
spinel -E -e 'puts Time.at(0).utc.year'                      # 1970
spinel -E -e 'puts Time.now.to_i > 0'
spinel -E -e 'puts (Time.now - Time.at(0)) > 0'
spinel -E -e 'puts Time.now.utc.class'                       # Time
```

### Missing or Partial

| Ruby method | Spinel status |
|---|---|
| `Time.parse` | "unsupported call: CallNode `parse`" even after `require "time"` |
| `Time.strptime` | Unsupported |
| `Time.httpdate`, `Time.rfc2822`, `Time.xmlschema`, `Time.iso8601` as class parsers | Not safe example targets |
| `Time#to_date`, `Time#to_datetime` | Depends on `date`; unavailable |
| Subsecond exactness methods | `subsec`, `nsec`, `tv_nsec`, `usec` may be missing |

## Regexp and MatchData

Spinel's regexp support is practical and broad.

### Confirmed Working

```sh
spinel -E -e 'puts "hello" =~ /ell/'                         # 1
spinel -E -e 'puts /ell/.match("hello") != nil'              # true
spinel -E -e 'puts /ell/.match?("hello")'                    # true
spinel -E -e 'm = /(\w+)\s(\w+)/.match("hello world"); puts m[1]'  # hello
spinel -E -e 'm = /(?<a>\w+)\s(?<b>\w+)/.match("hello world"); puts m[:a]'  # hello
spinel -E -e 'puts Regexp.new("hell").match("hello") != nil' # true
spinel -E -e 'puts /hell/i.match("HELLO") != nil'            # true
spinel -E -e 'puts "hello".scan(/[aeiou]/).inspect'          # ["e", "o"]
spinel -E -e '"hello" =~ /(?<x>[el]+)/; puts $~[:x]'        # ell
```

### Gaps

| Ruby method/feature | Spinel status |
|---|---|
| `Regexp.timeout`, `Regexp.timeout=` | Not a safe example target |
| `Regexp.linear_time?` | Not a safe example target |
| `Regexp.union` with flagged or runtime operands | Documented as unsupported |
| Full Onigmo syntax | Atomic groups, subexpression calls, advanced Unicode properties may be missing |
| `MatchData#regexp`, `#string`, `#deconstruct`, `#deconstruct_keys`, `#match_length` | Not confirmed available |

## Integer, Numeric, and Math

Spinel covers the numeric tower well.

### Confirmed Working

```sh
spinel -E -e 'puts 3.14.floor; puts 3.14.ceil; puts 3.14.round'
spinel -E -e 'puts 10.divmod(3).inspect'      # [3, 1]
spinel -E -e 'puts 2 ** 10'                   # 1024
spinel -E -e 'puts 2 ** -1'                   # (1/2)  — Rational
spinel -E -e 'puts 42.clamp(0, 50)'
spinel -E -e 'puts 42.to_r'                   # 42/1
spinel -E -e 'puts 5.times.to_a.inspect'      # [0,1,2,3,4]
spinel -E -e 'puts 1.upto(5).to_a.inspect'
spinel -E -e 'puts (1..5).sum'
spinel -E -e 'puts Math::PI'
spinel -E -e 'puts Math.sqrt(4.0)'
spinel -E -e 'puts Math.log(Math::E)'
```

### Gaps

| Ruby method/behavior | Spinel status |
|---|---|
| `Integer#**` with negative exponent | **Supported**: `2 ** -1 # => (1/2)`. `0 ** -1` still raises `ZeroDivisionError`. |
| Bigint-backed `Rational` precision | Spinel `Rational` uses fixed integer numerator/denominator and can overflow |
| Exact `Complex` component preservation | Spinel stores complex components as floats |
| `Integer#chr` with runtime/non-ASCII encoding | Documented as unsupported |

## Process and System

### Confirmed Working

```sh
spinel -E -e 'puts Process.pid > 0'
spinel -E -e 'puts Process.ppid > 0'
spinel -E -e 'puts Dir.pwd.class'
spinel -E -e 'puts Dir.home.class'
spinel -E -e 'Dir.chdir("/tmp") { puts Dir.pwd }'
spinel -E -e 'puts Dir.glob("/etc/h*").length > 0'
spinel -E -e 'puts Dir["*.rb"].class'
spinel -E -e 'puts Dir.exist?("/tmp")'
spinel -E -e 'puts `echo hello`.strip'          # hello  — backtick works
spinel -E -e 'puts system("true")'              # true (or nil)
```

### Not Available

| API | Status |
|---|---|
| `Process.uid`, `Process.gid`, `Process.euid`, `Process.egid` | Fail with "unsupported call"; use `` `id -u`.strip.to_i `` |
| `$?` as `Process::Status` | `$?` is an `Integer` (0 on success, 256 on failure), not a `Process::Status` object; `.success?` raises `NoMethodError` |
| `$:` / `$LOAD_PATH` | Generate undefined identifier 'gv_LOAD_PATH' in C compilation |
| `IO.select`, `IO.popen` | Unsupported |

## Exception Handling

Exception handling is fully supported:

```sh
spinel -E -e 'begin; raise "oops"; rescue => e; puts e.message; end'
spinel -E -e 'begin; raise RuntimeError, "oops"; rescue RuntimeError => e; puts e.class; end'
spinel -E -e 'begin; 1/0; rescue ZeroDivisionError; puts "zero"; end'
spinel -E -e 'begin; Integer("x"); rescue ArgumentError; puts "bad int"; end'
```

## Struct

`Struct.new` with accessor methods and custom methods works:

```sh
spinel -E -e 'Foo = Struct.new(:x, :y); f = Foo.new(1,2); puts f.x'       # 1
spinel -E -e 'Foo = Struct.new(:x, :y); f = Foo.new(1,2); puts f.to_a.inspect'  # [1, 2]
spinel -E -e 'Foo = Struct.new(:x, :y) { def sum; x+y; end }; puts Foo.new(1,2).sum'  # 3
```

## Libraries and Methods to Prefer

Prefer these because they are supported and already fit Spinel's design:

- CLI parsing: manual `ARGV` loop for any flag that takes a value; `require "optparse"` only for boolean flags
- JSON: `require "json"`
- Base64: `require "base64"`
- Digests: `require "digest"` for SHA1/SHA256 hexdigest; Spinel's built-in `digest` package only ships SHA-1 and SHA-256 — MD5, SHA-224, SHA-384, SHA-512 are not available without a custom C extension
- In-memory IO: `require "stringio"`
- Tokenizing/parsing: `require "strscan"`
- Sets: `require "set"`
- Static file work: `File.read`, `File.write`, `File.exist?`, `File.directory?`, `File.file?`, `File.size`, `File.join`, `File.basename`, `File.dirname`, `File.expand_path`
- Networking (HTTP servers): use `require_relative "lib/socket_tcp"` — wraps five `sp_net_*` built-in functions, works under both CRuby and Spinel, no C extension or `SPINEL_REQUIRE_GATE` needed; provides `TCPServer.open`, `server.accept`, `client.recv`, `client.write`, `client.close`
- Networking (outbound client): `require "socket"` then `TCPSocket.new(host, port)`; `fileno` works, `recv` needs FFI via `fileno`
- Networking (raw Socket / UDP / Unix): use `require_relative "lib/socket_shim.rb"` (full FFI-backed shim)
- Reflection: use `send(:method_name)` with literal symbol names; `obj.method(:name).call`; `obj.respond_to?(:name)`; `&:method_name`
- Process info: `` `id -u`.strip.to_i `` instead of `Process.uid`

## Method Probe Checklist for New Examples

Before using a Ruby method not already covered by examples, run a tiny probe:

```sh
SPINEL_REQUIRE_GATE=1 spinel -E -e 'require "feature"; puts something'
```

If the probe fails with `unsupported ... CallNode`, `undefined method`,
`cannot load such file`, or a C compile error, either:

- use a smaller supported Ruby surface,
- add a Spinel package,
- expose a native helper through FFI (`sp_file_ext.c` pattern),
- or document the example as demonstrating an intentional limitation.

Error messages now include the structural reason for the gap. Read them — they
explain exactly what would need to change in Spinel's design to support the
feature.
