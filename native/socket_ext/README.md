# Socket Native Extension

This directory holds C helpers for Spinel programs that need socket behavior
outside the built-in `sp_net` HTTP-server subset.

Compile a Spinel program with this extension by passing the C file as an extra
link input:

```sh
~/Projects/spinel/spinel --link native/socket_ext/socket_ext.c \
  source/app.rb \
  -o app
```

The Ruby side declares these helpers with `ffi_func` in
`source/lib/socket_shim.rb`. Symbols use the `sx_` prefix so it is clear they are
project-local socket extension functions, not Spinel runtime functions.

The extension returns simple FFI-friendly values: integers for file descriptors
and status codes, strings for sockaddr/address records, and binary strings for
received payloads. The Ruby shim wraps those values into the CRuby-shaped API.
