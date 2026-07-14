# Spinel Runtime Library Reference for Examples

This note is the decision guide for future examples in this repository. It is
based on the local Spinel source tree at `/Users/branden/Projects/spinel`,
especially `lib/`, `packages/`, and `docs/require.md`.

The short version:

- Use normal Ruby methods when Spinel already exposes a Ruby surface.
- Use `require "name"` for bundled packages and require-gated stdlib.
- Use `require_relative` for project-local Ruby files.
- Use FFI only for native symbols that are not already exposed through Ruby or a
  Spinel package.

Most functions in Spinel's `lib/` directory are runtime implementation details.
They exist so generated C can implement Ruby methods. They are not meant to be
wrapped by every application.

## The Decision Tree

1. If the feature is in a bundled package, write `require "name"` and use the
   Ruby API.
2. If it is a Ruby core feature Spinel supports, call it directly.
3. If it is local project code, write `require_relative`.
4. If the function is a POSIX/system/native helper with no Ruby package surface,
   make a small FFI module.
5. If the function is a GC, scheduler, typed-array, string, regexp, marshal, or
   numeric helper, do not FFI it from app code. Use the Ruby method it backs.

## FFI Candidates from `lib/`

These are the runtime symbols that are useful to expose from examples because
they do not have a complete normal Ruby API in Spinel today.

### `sp_net` -> Ruby-Compatible Socket Layer

`lib/sp_net.c` and `lib/sp_net.h` contain socket, polling, process, and command
helpers. The web/file-server examples expose the subset they need through
`source/socket_shim.rb`.

That file gives example code Ruby-shaped calls:

- `TCPServer.new("0.0.0.0", port)`
- `TCPServer#accept`
- `TCPSocket#recv(maxlen)`
- `TCPSocket#readpartial(maxlen)`
- `TCPSocket#write(data)`
- `TCPSocket#close`

Under CRuby, the file loads Ruby's `socket` library and uses the real
`TCPServer` / `TCPSocket` classes. Under Spinel, it defines a small
compatibility layer backed by `SpinelSocketNative`, whose FFI declarations are:

| Native symbol | Suggested declaration | Ruby-facing purpose |
|---|---|---|
| `sp_net_listen` | `ffi_func :sp_net_listen, [:int, :int], :int` | Bind and listen on a TCP port |
| `sp_net_accept` | `ffi_func :sp_net_accept, [:int], :int` | Accept a blocking client connection |
| `sp_net_accept_nb` | `ffi_func :sp_net_accept_nb, [:int], :int` | Accept without blocking |
| `sp_net_connect` | `ffi_func :sp_net_connect, [:str, :int], :int` | Open an outbound TCP connection |
| `sp_net_close` | `ffi_func :sp_net_close, [:int], :int` | Close a socket/file descriptor |
| `sp_net_set_nonblock` | `ffi_func :sp_net_set_nonblock, [:int], :int` | Put a descriptor in non-blocking mode |
| `sp_net_set_nodelay` | `ffi_func :sp_net_set_nodelay, [:int], :void` | Disable Nagle's algorithm |
| `sp_net_recv_some` | `ffi_func :sp_net_recv_some, [:int, :int], :binstr` | Read some bytes from a descriptor |
| `sp_net_recv_all` | `ffi_func :sp_net_recv_all, [:int, :int], :binstr` | Read up to a byte limit |
| `sp_net_write_str` | `ffi_func :sp_net_write_str, [:int, :str], :int` | Write a NUL-terminated string |
| `sp_net_write_bytes` | `ffi_func :sp_net_write_bytes, [:int, :str, :int], :int` | Write an explicit byte count |
| `sp_net_poll_reset` | `ffi_func :sp_net_poll_reset, [], :int` | Clear the runtime poll set |
| `sp_net_poll_add` | `ffi_func :sp_net_poll_add, [:int, :int], :int` | Add a descriptor to the poll set |
| `sp_net_poll_run` | `ffi_func :sp_net_poll_run, [:int], :int` | Poll with a timeout in milliseconds |
| `sp_net_poll_ready` | `ffi_func :sp_net_poll_ready, [:int], :int` | Check whether a poll slot is ready |
| `sp_net_fork` | `ffi_func :sp_net_fork, [], :int` | Fork the process |
| `sp_net_exit` | `ffi_func :sp_net_exit, [:int], :int` | Exit the process |
| `sp_net_getpid` | `ffi_func :sp_net_getpid, [], :int` | Return the process id |
| `sp_net_wait_any` | `ffi_func :sp_net_wait_any, [], :int` | Wait for any child process |
| `sp_net_shell_capture` | `ffi_func :sp_net_shell_capture, [:str, :int], :binstr` | Capture command output |
| `sp_net_install_term_handlers` | `ffi_func :sp_net_install_term_handlers, [], :int` | Install SIGINT/SIGTERM handlers |
| `sp_net_shutdown_requested` | `ffi_func :sp_net_shutdown_requested, [], :int` | Check whether shutdown was requested |

Use `:binstr` for `sp_net_recv_some`, `sp_net_recv_all`, and
`sp_net_shell_capture`. `sp_net` records the real byte length in
`sp_net_bin_len`, and `:binstr` lets Spinel copy binary data without depending
on `strlen`.

The current web examples use this Ruby-facing subset:

| Ruby call | Spinel-backed native operation | Used by |
|---|---|---|
| `TCPServer.new("0.0.0.0", port)` | `sp_net_listen(port, 1)` | `simple_server_2.rb` through `simple_server_6.rb` |
| `server.accept` | `sp_net_accept(server_fd)` | `simple_server_2.rb` through `simple_server_6.rb` |
| `client.recv(2048)` | `sp_net_recv_some(fd, maxlen)` as `:binstr` | `simple_server_3.rb` through `simple_server_6.rb` |
| `client.readpartial(2048)` | same as `recv` | available for future examples |
| `client.write(response)` | `sp_net_write_str(fd, response)` | `simple_server_2.rb` through `simple_server_6.rb` |
| `client.close` | `sp_net_close(fd)` | `simple_server_2.rb` through `simple_server_6.rb` |

### `sp_crypto` -> Suggested Module: `SpinelCrypto`

`lib/sp_crypto.c` is always linked into the runtime. `require "digest"` exposes
only SHA1/SHA256 `hexdigest` methods. The rest is useful for future examples
such as WebSocket, token, password, and small auth demos.

| Native symbol | Suggested declaration | Ruby-facing purpose |
|---|---|---|
| `sp_crypto_sha1_hex` | `ffi_func :sp_crypto_sha1_hex, [:str], :str` | SHA1 hex digest |
| `sp_crypto_sha256_hex` | `ffi_func :sp_crypto_sha256_hex, [:str], :str` | SHA256 hex digest |
| `sp_crypto_websocket_accept` | `ffi_func :sp_crypto_websocket_accept, [:str], :str` | Compute a WebSocket accept key |
| `sp_crypto_hmac_sha256_hex` | `ffi_func :sp_crypto_hmac_sha256_hex, [:str, :str], :str` | HMAC-SHA256 as hex |
| `sp_crypto_hmac_sha256_b64url` | `ffi_func :sp_crypto_hmac_sha256_b64url, [:str, :str], :str` | HMAC-SHA256 as base64url |
| `sp_crypto_b64url_encode` | `ffi_func :sp_crypto_b64url_encode, [:str], :str` | Base64url encode |
| `sp_crypto_b64url_decode` | `ffi_func :sp_crypto_b64url_decode, [:str], :str` | Base64url decode |
| `sp_crypto_pbkdf2_sha256_b64url` | `ffi_func :sp_crypto_pbkdf2_sha256_b64url, [:str, :str, :int], :str` | PBKDF2-HMAC-SHA256 as base64url |
| `sp_crypto_random_b64url` | `ffi_func :sp_crypto_random_b64url, [:int], :str` | Random bytes encoded as base64url |

Prefer `require "digest"` for `Digest::SHA1.hexdigest` and
`Digest::SHA256.hexdigest`. Use FFI only when an example needs the extra
helpers above.

The `sp_crypto_*` helpers return static C buffers, so copy the result into a
Ruby string before making another crypto call if an example needs to keep both
values. `sp_crypto_b64url_decode` can produce arbitrary binary; the simple
`:str` declaration is safe only when the decoded payload is known to be text
without embedded NUL bytes. For a binary-safe decoder example, add a tiny C
wrapper that records the decoded length in `sp_net_bin_len` and expose the
wrapper as `:binstr`.

### Raw POSIX Calls -> Suggested Module: `PosixNet`

`source/simple_server_1.rb` intentionally demonstrates lower-level POSIX FFI:
`socket`, `setsockopt`, `htons`, `bind`, `listen`, `accept`, `write`, and
`close`.

Keep this style only when the lesson is raw FFI. For practical examples, prefer
the `socket_shim.rb` compatibility layer because it hides sockaddr packing
and keeps the example source close to CRuby.

## Bringing Your Own C (custom native code + `--link`)

Everything above binds symbols that already exist in the Spinel runtime
(`sp_net_*`, `sp_crypto_*`) or in libc. You can also compile **your own** C file
into the binary and call it from Ruby with the same `ffi_func` DSL. This repo
does exactly that in `native/socket_ext/socket_ext.c` (bound by
`source/socket_shim.rb`), so use it as the reference.

### The mechanism

The `spinel` compiler has a repeatable `--link` flag:

```
--link ARG   Extra link input (object/archive/-lLIB); repeatable
```

`ARG` can be a `.c` source, a `.o` object, a `.a` archive, or a `-lNAME`
library. A `.c` file is handed straight to the final `cc` step, so it is
compiled and linked in one shot. `ffi_func` emits a plain `extern`
declaration for each symbol; the linker resolves it against whatever you pass
via `--link`. There is no name mangling -- the C function name is used verbatim.

### The four steps

1. **Write the C.** Plain C functions with FFI-friendly signatures. Give them a
   short project prefix (this repo uses `sx_`) so it is obvious they are
   project-local, not runtime, symbols.

   ```c
   /* my_math.c */
   int my_add(int a, int b) { return a + b; }
   ```

2. **Declare the binding** in a Ruby module:

   ```ruby
   module MyNative
     ffi_func :my_add, [:int, :int], :int
   end
   ```

3. **Build with `--link`:**

   ```sh
   spinel --link native/my_math.c source/app.rb -o bin/app
   # probe form (compile + run in a temp dir): add -E, keep --link
   spinel --link native/my_math.c -E source/app.rb
   ```

4. **Call it** as `Module.symbol(args)`: `MyNative.my_add(2, 3)  # => 5`.

### C ABI cheat-sheet for `ffi_func` type specs

| Spec | C type | Notes |
|---|---|---|
| `:int` | `int` | also `:uint32` -> `uint32_t`, `:size_t` -> `size_t` |
| `:bool` | `int` | 0 / non-zero |
| `:float` / `:double` | `float` / `double` | |
| `:str` | `const char *` | NUL-terminated; stops at first `\0` |
| `:binstr` | `const char *` | binary-safe **return only**; see below |
| `:ptr` | `void *` | opaque pointer |
| `:void` | `void` | return type only |

**Returning strings.** A returned `const char *` is *borrowed* -- the buffer
stays owned by C, so return a `static` buffer (as `socket_ext.c` does) or a
string literal, not stack memory. For text, `:str` is fine. For bytes that may
contain embedded NULs, declare the return as `:binstr` and have the C function
set the runtime global `sp_net_bin_len` to the byte count before returning:

```c
extern int sp_net_bin_len;          /* runtime-provided length channel */
static char buf[65536];
const char *my_bytes(...) {
  /* ... fill buf, n = length ... */
  sp_net_bin_len = n;               /* MUST set before returning :binstr */
  return buf;
}
```

Same static-buffer caveat as the runtime helpers: the next FFI call may reuse
the buffer, so copy the result (`value.dup`) if you need to keep it, and it is
not thread-safe -- guard with a `Mutex` under real parallelism.

### Manual `cc` path (when you need full control)

If you need custom `CFLAGS`/`LDFLAGS`, static linking, or a specific `-I`/`-L`,
stop at C with `-c` and drive the linker yourself:

```sh
spinel source/app.rb -c -o app.c        # emit generated C only
cc -I<spinel>/lib -o bin/app app.c native/my_math.c \
   <spinel>/lib/libspinel_rt.a -lm
```

For linking against an installed system library instead of your own `.c`, prefer
the in-source `ffi_lib`/`ffi_cflags` directives (see `<spinel>/docs/FFI.md`);
they emit `SPINEL_LINK`/`SPINEL_CFLAGS` marker comments the compiler scrapes
automatically.

## Require-Based Features

These features should be reached with `require`, not hand-written FFI.

When writing or testing examples that demonstrate `require`, run them with
`SPINEL_REQUIRE_GATE=1`. In the current compiler this is still opt-in, and it
is the path that resolves the bundled package surfaces consistently.

| Require | Ruby surface | Backing implementation | Example guidance |
|---|---|---|---|
| `require "json"` | `JSON.generate`, `JSON.dump`, `JSON.parse`, `JSON.pretty_generate` | `packages/json` plus `sp_json.c` | Use for serialization examples |
| `require "base64"` | `Base64.encode64`, `decode64`, `strict_encode64`, `strict_decode64`, `urlsafe_encode64`, `urlsafe_decode64` | `packages/base64` plus `sp_base64.c` | Use for standard Base64 |
| `require "digest"` | `Digest::SHA1.hexdigest`, `Digest::SHA256.hexdigest` | Package declarations over `sp_crypto.c` | Use for simple digests |
| `require "stringio"` | `StringIO` | `packages/stringio` plus `sp_stringio.c` | Use for in-memory IO |
| `require "strscan"` | `StringScanner` | `packages/strscan` plus `sp_strscan.c` | Use for parser/scanner examples |
| `require "set"` | `Set` | Pure Ruby package | Use for uniqueness and set algebra |
| `require "forwardable"` | `Forwardable` / compile-time `def_delegators` handling | Stub plus compiler behavior | Use when porting Ruby code that extends `Forwardable` |
| `require "optparse"` | `OptionParser` subset | Pure Ruby package | Use for CLI examples |
| `require "erb"` | Minimal `ERB` placeholder | Pure Ruby package | Mostly for compatibility; it does not evaluate templates |
| `require "monitor"` | `Monitor`, `#synchronize` | Require-gated stdlib | Use for monitor examples |
| `require "io/console"` | `IO#winsize` | Require-gated core extension | Use before calling `winsize` |
| `require "time"` | `Time#iso8601` | Require-gated core extension | Use before calling `iso8601` |

No-op requires that Spinel accepts because the feature is already core:
`thread`, `enumerator`, and `fiber`.

Unsupported requires, with the require gate enabled, fail at compile time.
Examples seen locally: `date` and `net`.

## Core Runtime Methods That Do Not Need FFI

The following groups come from `lib/`. They should be used through Ruby methods
and classes, not wrapped directly.

### Strings: `sp_str.*`

Runtime helper names:

`sp_str_casecmp`, `sp_str_valid_encoding`, `sp_str_field`,
`sp_str_field_count`, `sp_str_concat`, `sp_str_concat3`, `sp_str_concat4`,
`sp_str_concat_arr`, `sp_str_inspect`, `sp_sym_plain_name_p`,
`sp_sym_simple_p`, `sp_sym_inspect_name`, `sp_sym_inspect_key`,
`sp_str_upcase`, `sp_str_downcase`, `sp_str_swapcase`, `sp_str_dump`,
`sp_str_delete_prefix`, `sp_str_substr`, `sp_str_delete_suffix`,
`sp_str_strip`, `sp_str_chomp`, `sp_str_chomp_sep`, `sp_str_chop`,
`sp_str_include`, `sp_str_start_with`, `sp_str_end_with`,
`sp_str_partition`, `sp_str_rpartition`, `sp_str_lines`,
`sp_str_lines_chomp`, `sp_str_byteslice`, `sp_str_ascii_only`,
`sp_str_format_strarr`, `sp_str_sub`, `sp_str_capitalize`,
`sp_str_repeat`, `sp_str_bytes`, `sp_str_crypt`, `sp_str_lstrip`,
`sp_str_rstrip`, `sp_str_dup`, `sp_str_length_m`, `sp_str_bytesize_m`,
`sp_str_empty_p`, `sp_str_plus`, `sp_str_count_chars`, `sp_str_length`,
`sp_str_ord`, `sp_utf8_byte_offset`, `sp_utf8_decode_all`,
`sp_utf8_decode_charset`, `sp_utf8_decode_charset_n`, `sp_str_split_into`,
`sp_str_undump`, `sp_str_succ_impl`, `sp_str_succ`, `sp_str_split`,
`sp_str_split_drop_trailing`, `sp_str_split_limit`, `sp_str_split_ws`,
`sp_str_gsub`, `sp_str_index`, `sp_str_index_from`, `sp_str_rindex`,
`sp_str_rindex_from`, `sp_str_byteindex`, `sp_str_byteindex_from`,
`sp_str_byterindex`, `sp_str_byterindex_from`, `sp_str_sub_range`,
`sp_str_char_at_or_nil`, `sp_str_sub_range_len`, `sp_str_sub_range_r`,
`sp_str_sub_range_len_r`, `sp_str_reverse`, `sp_str_count`,
`sp_str_count_n`, `sp_str_codepoints`, `sp_str_chars`, `sp_str_tr`,
`sp_str_tr_s`, `sp_str_delete`, `sp_str_squeeze`,
`sp_str_squeeze_chars`, `sp_str_delete_n`, `sp_str_squeeze_n`,
`sp_str_scrub`, `sp_str_ljust`, `sp_str_rjust`, `sp_str_center`,
`sp_str_ljust2`, `sp_str_rjust2`, `sp_str_center2`,
`sp_str_index_opt`, `sp_str_index_from_opt`, `sp_str_rindex_opt`.

Ruby surface:

`String#casecmp`, `#valid_encoding?`, indexing/slicing, interpolation and
concatenation, `#inspect`, symbol inspect forms, `#upcase`, `#downcase`,
`#swapcase`, `#dump`, `#delete_prefix`, `#delete_suffix`, `#strip`,
`#lstrip`, `#rstrip`, `#chomp`, `#chop`, `#include?`, `#start_with?`,
`#end_with?`, `#partition`, `#rpartition`, `#lines`, `#byteslice`,
`#ascii_only?`, `String#%`, `#sub`, `#gsub`, `#capitalize`, `#*`, `#bytes`,
`#crypt`, `#dup`, `#length`, `#size`, `#bytesize`, `#empty?`, `#+`,
`#ord`, `#split`, `#undump`, `#succ`, `#index`, `#rindex`, `#byteindex`,
`#byterindex`, `#reverse`, `#count`, `#codepoints`, `#chars`, `#tr`,
`#tr_s`, `#delete`, `#squeeze`, `#scrub`, `#ljust`, `#rjust`, and
`#center`.

### Mutable Strings: `sp_string.*`

Runtime helper names:

`sp_String_new`, `sp_String_append`, `sp_String_append_bin`,
`sp_String_cstr`, `sp_String_length`, `sp_String_prepend`,
`sp_String_insert`, `sp_String_replace`, `sp_String_dup`,
`sp_String_freeze`, `sp_String_is_frozen`.

Ruby surface:

`String.new`, mutable `String#<<`, `#prepend`, `#insert`, `#replace`, `#dup`,
`#freeze`, and frozen-string checks. Do not FFI these.

### Arrays: `sp_array.*`

Spinel uses typed arrays internally: `sp_IntArray`, `sp_FloatArray`,
`sp_StrArray`, `sp_PtrArray`, and polymorphic arrays from `sp_runtime.h`.

Common runtime helper names:

`*_new`, `*_push`, `*_pop`, `*_shift`, `*_length`, `*_empty`, `*_get`,
`*_set`, `*_dup`, `*_slice`, `*_slice_range`, `*_replace`, `*_splice`,
`*_reverse_bang`, `*_rotate_bang`, `*_sort`, `*_sort_bang`,
`*_shuffle`, `*_shuffle_bang`, `*_sample`, `*_min`, `*_max`, `*_sum`,
`*_include`, `*_index`, `*_rindex`, `*_delete_at`, `*_delete`,
`*_insert`, `*_uniq`, `*_uniq_bang`, `*_intersect`, `*_intersect_p`,
`*_union`, `*_difference`, `*_unshift`, `*_join`, `*_eq`, `*_cmp`,
`*_inspect`, `*_concat`, `*_slice_bang`.

Extra helper names:

`sp_IntArray_from_range`, `sp_IntArray_from_range_step`,
`sp_IntArray_slice_before`, `sp_IntArray_slice_after`,
`sp_IntArray_product`, `sp_IntArray_index_poly`,
`sp_IntArray_rindex_poly`, `sp_IntArray_index_opt`,
`sp_IntArray_rindex_opt`, `sp_IntArray_to_poly`,
`sp_FloatArray_from_step`, `sp_FloatArray_ffi_data`,
`sp_StrArray_from_string_range`, `sp_StrArray_index_poly`,
`sp_StrArray_rindex_poly`, `sp_StrArray_to_poly_fmt`,
`sp_PtrArray_str_join`.

Ruby surface:

Array literals and ranges, `Array#push`, `#<<`, `#pop`, `#shift`, `#length`,
`#size`, `#empty?`, `#[]`, `#[]=`, `#dup`, `#slice`, `#replace`,
`#reverse!`, `#rotate!`, `#sort`, `#sort!`, `#shuffle`, `#sample`, `#min`,
`#max`, `#sum`, `#include?`, `#index`, `#rindex`, `#delete_at`, `#delete`,
`#insert`, `#uniq`, `#uniq!`, `#intersection` / `&`, `#union` / `|`,
`#difference` / `-`, `#unshift`, `#join`, comparison, `#inspect`,
`#concat`, `#slice!`, `#slice_before`, `#slice_after`, and `#product`.

`sp_IntArray_ffi_data` and `sp_FloatArray_ffi_data` are compiler/runtime support
for passing arrays to native functions. Application examples should still use
Ruby arrays unless the example is specifically about FFI array arguments.

### Numbers, Rational, Complex, Range: `sp_core.*` and `sp_format.*`

Runtime helper names:

`sp_str_to_i_cruby`, `sp_str_to_i_base`, `sp_str_to_i_strict`,
`sp_str_to_i_strict_base`, `sp_str_to_f_strict`, `sp_gcd`, `sp_lcm`,
`sp_powmod`, `sp_ceildiv`, `sp_int_clamp`, `sp_float_clamp`,
`sp_int_sqrt`, `sp_ipow10`, `sp_int_round`, `sp_int_ceil`,
`sp_int_floor`, `sp_int_truncate`, `sp_str_oct`,
`sp_complex_inspect`, `sp_complex_to_s`, `sp_complex_polar`,
`sp_complex_add`, `sp_complex_sub`, `sp_complex_mul`, `sp_complex_div`,
`sp_complex_neg`, `sp_complex_conjugate`, `sp_complex_pow`,
`sp_complex_abs`, `sp_complex_abs2`, `sp_complex_eq`,
`sp_rational_inspect`, `sp_rational_to_s`, `sp_rational_new`,
`sp_str_to_r`, `sp_rational_add`, `sp_rational_sub`, `sp_rational_mul`,
`sp_rational_div`, `sp_rational_neg`, `sp_rational_abs`,
`sp_rational_pow`, `sp_rational_cmp`, `sp_rational_eq`,
`sp_rational_to_f`, `sp_float_to_rational`, `sp_float_rationalize`,
`sp_float_rationalize0`, `sp_Range_inspect`.

Ruby surface:

`String#to_i`, `Integer()`, `String#to_f`, `Integer#gcd`, `#lcm`, modular
power, `#ceildiv`, `#clamp`, `Integer.sqrt`, `#round`, `#ceil`, `#floor`,
`#truncate`, `String#oct`, `Complex`, `Complex.polar`, complex arithmetic,
`#conjugate`, `#abs`, `#abs2`, `Rational`, `String#to_r`, rational
arithmetic, `#to_f`, `Float#to_r`, `Float#rationalize`, ranges, `#inspect`,
and `#to_s`.

### Big Integers: `sp_bigint.*`

Runtime helper names:

`sp_bigint_new_int`, `sp_bigint_new_str`, `sp_bigint_add`,
`sp_bigint_sub`, `sp_bigint_mul`, `sp_bigint_div`, `sp_bigint_mod`,
`sp_bigint_pow`, `sp_bigint_cmp`, `sp_bigint_to_int`,
`sp_bigint_to_s`, `sp_bigint_free`, `sp_bigint_and`, `sp_bigint_or`,
`sp_bigint_xor`, `sp_bigint_shl`, `sp_bigint_shr`, `sp_bigint_not`.

Ruby surface:

Large integer arithmetic and bit operations. Use ordinary integer code. Do not
manage `sp_Bigint` pointers from examples.

### Time: `sp_time.*`

Runtime helper names:

`sp_time_now`, `sp_time_at_int`, `sp_time_at_float`, `sp_time_new`,
`sp_time_new_utc`, `sp_time_utc`, `sp_time_localtime`, `sp_time_vtm`,
`sp_time_year`, `sp_time_mon`, `sp_time_mday`, `sp_time_hour`,
`sp_time_min`, `sp_time_sec`, `sp_time_wday`, `sp_time_yday`,
`sp_time_isdst`, `sp_time_utc_offset`, `sp_time_add`, `sp_time_cmp`,
`sp_time_add_f`, `sp_time_add_i`, `sp_time_sub_i`, `sp_time_sub_t`,
`sp_time_strftime`, `sp_time_iso8601`, `sp_time_zone`,
`sp_time_inspect_v`.

Ruby surface:

`Time.now`, `Time.at`, `Time.new`, `Time.utc`, `#localtime`, `#year`, `#mon`,
`#mday`, `#hour`, `#min`, `#sec`, `#wday`, `#yday`, `#isdst`,
`#utc_offset`, time arithmetic, time comparison, `#strftime`, `#zone`,
`#inspect`, and `#iso8601`. Use `require "time"` before `#iso8601`.

### File and IO: `sp_io.*`

Runtime helper names:

`sp_File_open`, `sp_io_make_pipe`, `sp_io_fdopen`, `sp_File_write`,
`sp_File_close`, `sp_File_closed_p`, `sp_File_puts`, `sp_File_print`,
`sp_File_flush`, `sp_File_eof_p`, `sp_File_seek`, `sp_File_tell`,
`sp_File_rewind`, `sp_File_tty_p`, `sp_File_fileno`, `sp_File_winsize`,
`sp_io_stdout`, `sp_io_stderr`, `sp_io_stdin`, `sp_file_directory`,
`sp_file_file`, `sp_file_exist`, `sp_file_delete`.

Ruby surface:

`File.open`, `IO.pipe`, `IO#write`, `IO#close`, `IO#closed?`, `IO#puts`,
`IO#print`, `IO#flush`, `IO#eof?`, `IO#seek`, `IO#tell`, `IO#pos`,
`IO#rewind`, `IO#tty?`, `IO#isatty`, `IO#fileno`, `STDOUT`, `STDERR`,
`STDIN`, `File.directory?`, `File.file?`, `File.exist?`, and `File.delete`.
Use `require "io/console"` before `IO#winsize`.

### Regexp and MatchData: `sp_re.*`

Runtime helper names:

`re_compile`, `re_free`, `re_exec`, `re_num_named`, `re_named_name`,
`re_named_group`, `sp_re_push_match_roots`, `sp_re_last_paren_match`,
`sp_re_set_captures`, `sp_re_match`, `sp_re_rindex`,
`sp_re_rpartition`, `sp_re_match_p`, `sp_re_match_p_at`,
`sp_re_expand_rep`, `sp_re_gsub`, `sp_re_sub`, `sp_re_scan`,
`sp_re_split`, `sp_re_split_limit`, `sp_re_rindex_opt`,
`sp_re_rindex_poly`, `sp_re_index_poly`, `sp_str_splice_re`,
`sp_re_index_from_opt`, `sp_re_rindex_from_opt`, `sp_re_match_poly`,
`sp_re_named_capture`, `sp_re_escape`, `sp_re_scan_poly`,
`sp_re_match_data`, `sp_MatchData_scan`, `sp_re_matchdata`,
`sp_re_matchdata_at`, `sp_MatchData_aref`, `sp_MatchData_aref_name`,
`sp_MatchData_names`, `sp_MatchData_length`, `sp_md_char_off`,
`sp_MatchData_begin`, `sp_MatchData_end`, `sp_MatchData_offset`,
`sp_MatchData_bytebegin`, `sp_MatchData_byteend`,
`sp_MatchData_byteoffset`, `sp_MatchData_begin_name`,
`sp_MatchData_end_name`, `sp_MatchData_offset_name`,
`sp_MatchData_bytebegin_name`, `sp_MatchData_byteend_name`,
`sp_MatchData_byteoffset_name`, `sp_MatchData_to_s`,
`sp_MatchData_captures`, `sp_MatchData_to_a`,
`sp_MatchData_pre_match`, `sp_MatchData_post_match`,
`sp_re_default_error_handler`.

Ruby surface:

Regexp literals, `Regexp.new` where supported, `Regexp.escape`, `=~`,
`Regexp#match`, `#match?`, `String#match`, `#match?`, `#scan`, `#split`,
`#sub`, `#gsub`, regexp-aware `#index`/`#rindex`, global captures such as
`$1`, and `MatchData#[]`, `#names`, `#length`, `#begin`, `#end`, `#offset`,
`#bytebegin`, `#byteend`, `#byteoffset`, `#to_s`, `#captures`, `#to_a`,
`#pre_match`, and `#post_match`.

### Marshal and Pack/Unpack: `sp_marshal.*`, `sp_pack.*`

Runtime helper names:

`sp_marshal_dump`, `sp_marshal_load`, `sp_mar_b`, `sp_mar_sym`,
`sp_mar_long`, `sp_mar_w`, `sp_IntArray_pack`, `sp_FloatArray_pack`,
`sp_PolyArray_pack`, `sp_StrArray_pack`, `sp_str_unpack`,
`sp_str_unpack_off`, `sp_poly_pack`.

Ruby surface:

`Marshal.dump`, `Marshal.load`, `Array#pack`, and `String#unpack`. Do not call
the buffer writer helpers from examples.

### Fiber, Thread, Queue, Mutex: `sp_fiber.*` and `sp_sched.*`

Runtime helper names:

`sp_Fiber_new`, `sp_Fiber_resume`, `sp_Fiber_yield`,
`sp_Fiber_transfer`, `sp_Fiber_transfer_catch`, `sp_Fiber_raise`,
`sp_Fiber_kill`, `sp_Fiber_alive`, `sp_Fiber_storage_get`,
`sp_Fiber_storage_set`, `sp_Thread_spawn_fiber`, `sp_Thread_join`,
`sp_Thread_value`, `sp_Thread_kill`, `sp_Thread_raise`,
`sp_Thread_pass`, `sp_Thread_current`, `sp_Thread_alive`,
`sp_Thread_set_report_default`, `sp_Thread_get_report_default`,
`sp_Thread_set_report`, `sp_Thread_get_report`, `sp_Thread_main`,
`sp_Thread_list_count`, `sp_Thread_list_at`, `sp_Thread_get_name`,
`sp_Thread_set_name`, `sp_Thread_status`, `sp_Thread_tls_get`,
`sp_Thread_tls_set`, `sp_Thread_tls_key`, `sp_Queue_new`,
`sp_SizedQueue_new`, `sp_Queue_push`, `sp_Queue_pop`,
`sp_Queue_size`, `sp_Queue_empty`, `sp_Queue_max`, `sp_Queue_close`,
`sp_Queue_closed`, `sp_Queue_clear`, `sp_Mutex_new`,
`sp_Mutex_lock`, `sp_Mutex_unlock`, `sp_Mutex_try_lock`,
`sp_Mutex_locked`, `sp_Mutex_owned`, `sp_CondVar_new`,
`sp_CondVar_wait`, `sp_CondVar_signal`, `sp_CondVar_broadcast`,
`sp_sched_init`, `sp_sched_sleep`, `sp_sched_wait_io`,
`sp_sched_drain`, `sp_safepoint`.

Ruby surface:

`Fiber`, `Fiber#resume`, `Fiber.yield`, `Fiber#transfer`, `Fiber#raise`,
`Fiber#kill`, `Fiber#alive?`, fiber storage, `Thread.new`, `Thread#join`,
`Thread#value`, `Thread#kill`, `Thread#raise`, `Thread.pass`,
`Thread.current`, `Thread#alive?`, `Thread.report_on_exception`,
`Thread.main`, `Thread.list`, `Thread#name`, `Thread#name=`,
`Thread#status`, thread locals, `Queue`, `SizedQueue`, `Mutex`,
`ConditionVariable`, and `sleep`.

These are core. `require "thread"` and `require "fiber"` are tolerated no-ops.

#### Concurrency caveat: `File.read` and `Digest` are NOT thread-safe

Spinel runs green threads over N OS workers with **no GVL** (real parallelism),
so any runtime helper backed by shared/static state is a critical section.
Verified while building `source/parallel_digest.rb` (~30 runs plus minimal
probes):

- `File.read` and `Digest::SHA256.hexdigest` each return a shared, process-wide
  **static C buffer**. With two or more green threads live, one thread's call
  overwrites the buffer before another has copied its result out.
- Symptoms: blank digests, or a digest paired with the wrong file. Reproducible
  and independent of `SPINEL_WORKERS` -- it fails even with `SPINEL_WORKERS=1`
  (one OS worker running several green threads cooperatively).
- There is no thread-safe streaming API: `Digest::SHA256.new.update(...)` raises
  `undefined method 'update'`.
- Storing a nested `[path, digest]` array into a shared results array from
  multiple threads also corrupted; storing one flat `"path\tdigest"` string per
  entry is stable.

Resolution (matches `shasum -a 256`, identical under CRuby): run the whole
read + hash + append inside `mutex.synchronize`, so exactly one thread touches
the static buffers at a time. `Mutex#synchronize` is compiler-inlined with full
ensure semantics, so it is the idiomatic guard. This makes hashing effectively
serial on Spinel today; treat it as the teaching point rather than a bug to
route around. Also note `Thread#raise`/`Thread#kill` targeting the main thread
are no-ops. See `tmp/example_apps_plan/notes_deviations.md` and
`tmp/example_apps_plan/research_thread_queue_mutex.md` for the full analysis.

### System, Inspect, GC, Allocation: `sp_system.*`, `sp_inspect.*`, `sp_gc.*`, `sp_alloc.*`

Runtime helper names:

`sp_system_args`, `sp_last_status`, `sp_inspect_container`, `sp_gc_mark`,
`sp_gc_mark_all`, `sp_gc_collect`, `sp_gc_enforce_mem_limit`,
`sp_gc_collect_retune`, `sp_stw_collect`, `sp_oom_die`, `sp_str_sweep`,
`sp_str_lcache_clear`, `sp_str_collect_retune`, `sp_gc_collection_wanted`,
`sp_gc_alloc`, `sp_gc_alloc_nogc`, `sp_raise_cls`,
`sp_raise_frozen_str`, `sp_raise_frozen_array`.

Ruby surface:

`system`, backticks, `$?`, `inspect`, `p`, object allocation, strings, arrays,
exceptions, and garbage collection behavior. These are not application FFI
targets.

## Package Method Inventory

Use these through `require`.

### `json`

`JSON.generate`, `JSON.dump`, `JSON.parse`, `JSON.pretty_generate`.

### `base64`

`Base64.encode64`, `Base64.decode64`, `Base64.strict_encode64`,
`Base64.strict_decode64`, `Base64.urlsafe_encode64`,
`Base64.urlsafe_decode64`.

### `digest`

`Digest::SHA1.hexdigest`, `Digest::SHA256.hexdigest`.

### `stringio`

Constructors: `StringIO.new`, `StringIO.open`.

Instance methods: `#string`, `#pos`, `#tell`, `#size`, `#length`, `#lineno`,
`#write`, `#<<`, `#puts`, `#print`, `#putc`, `#flush`, `#read`, `#gets`,
`#getc`, `#getbyte`, `#rewind`, `#seek`, `#truncate`, `#eof?`, `#eof`,
`#close`, `#closed?`, `#sync`, `#isatty`, `#tty?`, `#fsync`, `#fileno`,
and `#pid`.

### `strscan`

Constructor: `StringScanner.new`.

Instance methods: `#scan`, `#check`, `#scan_until`, `#[]`, `#matched`,
`#matched?`, `#pos`, `#charpos`, `#pos=`, `#eos?`, `#getch`, `#peek`,
`#unscan`, `#rest`, `#rest_size`, `#rest?`, `#terminate`, `#string`,
`#pre_match`, `#post_match`, and `#reset`.

### `set`

Constructors: `Set.new`, `Set[]`.

Instance methods: `#add`, `#<<`, `#delete`, `#include?`, `#member?`, `#each`,
`#size`, `#length`, `#empty?`, `#to_a`, `#map`, `#collect`, `#&`,
`#intersection`, `#|`, `#union`, `#+`, `#-`, `#difference`, `#subset?`,
`#<=`, `#superset?`, and `#>=`.

### `forwardable`

`Forwardable` is a stub module; `def_delegators` is handled by the compiler.
Use it when porting Ruby code that already says `extend Forwardable`.

### `optparse`

`OptionParser.new`, `#banner=`, `#separator`, `#on_tail`, `#on`, `#parse!`,
`#to_s`, `OptionParser::ParseError#message`, and
`OptionParser::ParseError#to_s`.

The package is a small subset intended for common command-line parsing.

### `erb`

`ERB.new`, `#filename=`, and `#result_with_hash`.

This is a compatibility placeholder. It returns the template input rather than
evaluating embedded Ruby, because full ERB depends on runtime `eval`, which is a
bad fit for Spinel's AOT model.

## Internal Runtime Only

These files are important to Spinel but should not shape example APIs:

- `sp_types.h`, `mruby_shim.h`, and `spinel/runtime.h`: shared typedefs and
  compatibility declarations.
- `sp_fiber_ctx.h`: platform context switching.
- `regexp/re_internal.h`, `regexp/re_compile.c`, `regexp/re_exec.c`,
  `regexp/re_utf8.c`: regexp engine internals behind the Ruby regexp surface.
- `lib/stringio.c` and `lib/strscan.c`: older/standalone C files. Current
  require-backed package code lives under `packages/stringio` and
  `packages/strscan`.
- Most `static` functions in `.c` files: private helpers for the exported
  runtime functions above.

## Rule of Thumb for New Examples

- Socket server examples: use `socket_shim.rb` and Ruby-shaped
  `TCPServer` / `TCPSocket` calls.
- Process, polling, shell capture: add focused methods to a small native-backed
  compatibility layer when an example needs them.
- WebSocket accept key, HMAC, PBKDF2, random URL-safe token: use a
  `SpinelCrypto` FFI module unless a package exposes exactly what you need.
- JSON, Base64, Digest hexdigest, StringIO, StringScanner, Set, OptParse: use
  `require`.
- File, directory, string, array, regexp, time, marshal, pack/unpack, thread,
  fiber, queue, mutex: use Ruby directly.
- GC, allocation, typed-array internals, scheduler internals, match roots, and
  generated-runtime helpers: do not wrap them in app examples.
