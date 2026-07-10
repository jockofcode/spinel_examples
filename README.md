# FyelSrvr and Spinel Networking Examples

This repository demonstrates how to write small Ruby programs for the
[Spinel](https://github.com/matz/spinel) ahead-of-time compiler. The examples
build up from raw native socket bindings to a compiled static-file server named
FyelSrvr.

The final example compiles to a standalone native executable and does not need a
Ruby VM at runtime.

## Project Layout

```text
.
├── README.md
├── .tool-versions          # asdf pin for Spinel
├── index.html              # page served automatically at /
├── public/                 # empty test directory for directory listings
└── source/
    ├── native_net.rb       # shared Spinel FFI bindings for sp_net helpers
    ├── simple_server_1.rb  # raw POSIX socket extern declarations
    ├── simple_server_2.rb  # sp_net FFI functions under NativeNet
    ├── simple_server_3.rb  # request parsing and simple route handling
    ├── simple_server_4.rb  # static file and directory serving
    ├── simple_server_5.rb  # path sanitizing and content disposition handling
    └── simple_server_6.rb  # final server with index.html and file-size listings
```

`fyel_srvr` is a generated binary. Rebuild it from `source/simple_server_6.rb`
when needed.

## Install Spinel

### Option A: asdf

This project includes `.tool-versions` with `spinel master`.

```bash
asdf plugin add spinel https://github.com/jockofcode/asdf-spinel
asdf install
```

If you are not using this repository's `.tool-versions` file, install and select
the same version explicitly:

```bash
asdf install spinel master
asdf set spinel master
```

### Option B: Build Spinel from source

```bash
git clone https://github.com/matz/spinel.git
cd spinel
make
export PATH="$PWD/bin:$PATH"
cd -
```

## Compile and Run

Spinel compiles the entry-point Ruby file and follows local `require_relative`
dependencies such as `source/native_net.rb`.

Compile the final server:

```bash
spinel source/simple_server_6.rb -o fyel_srvr
```

Run it on the default port:

```bash
./fyel_srvr
```

Run it on a custom port:

```bash
./fyel_srvr 8080
```

You can also compile and run in one step while experimenting:

```bash
spinel -E source/simple_server_6.rb 8080
```

## Example Progression

- `simple_server_1.rb` declares C/POSIX socket functions with top-level
  `extern` declarations and serves a fixed HTML response.
- `simple_server_2.rb` switches to Spinel `ffi_func` bindings for the `sp_net`
  helper functions.
- `simple_server_3.rb` uses `sp_net_recv_some` with a `:binstr` return type,
  parses the HTTP request line, and serves a few in-code routes.
- `simple_server_4.rb` adds filesystem access with `File` and `Dir` APIs,
  including simple directory listings and basic content types.
- `simple_server_5.rb` adds URL path sanitizing, more content types, and
  `Content-Disposition` handling for inline web files versus downloads.
- `simple_server_6.rb` adds automatic `index.html` serving for directories,
  parent-directory links, SVG icons, and human-readable file sizes.

## Verify the Final Server

After starting the server:

```bash
./fyel_srvr 8080
```

Check the landing page:

```bash
curl -i http://localhost:8080/
```

Expected result: `200 OK` with `Content-Type: text/html`, serving the repository
root `index.html`.

Check the directory listing:

```bash
curl -i http://localhost:8080/public
```

Expected result: `200 OK` with an HTML directory index. The checked-in
`public/` directory is empty, so the listing shows only the parent-directory
entry until you add test files.

Check traversal handling:

```bash
curl -i --path-as-is http://localhost:8080/../../etc/passwd
```

Expected result: `404 Not Found`. The final server normalizes path segments
before resolving them under the current working directory.

## Notes

- Run the server from the repository root. The final example resolves paths
  relative to the current working directory.
- The server is intentionally small and educational. It handles one accepted
  connection at a time and reads up to 2048 bytes from each request.
- The SVG snippets in the directory listing use `http://w3.org` as written in
  the examples.
