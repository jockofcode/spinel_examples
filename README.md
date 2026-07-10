# FyelSrvr and Spinel Examples

Small Ruby examples for learning the
[Spinel](https://github.com/matz/spinel) ahead-of-time compiler.

The examples start with native socket calls and end with `FyelSrvr`, a tiny
static-file server that compiles to a standalone binary.

## What's Here

```text
.
├── README.md
├── .tool-versions
├── index.html
├── public/
└── source/
    ├── native_net.rb
    ├── simple_server_1.rb
    ├── simple_server_2.rb
    ├── simple_server_3.rb
    ├── simple_server_4.rb
    ├── simple_server_5.rb
    └── simple_server_6.rb
```

`fyel_srvr` is generated. Rebuild it whenever you want a fresh binary.

## Install Spinel

With `asdf`:

```bash
asdf plugin add spinel https://github.com/jockofcode/asdf-spinel
asdf install
```

Or build it from source:

```bash
git clone https://github.com/matz/spinel.git
cd spinel
make
export PATH="$PWD/bin:$PATH"
cd -
```

## Build and Run

Compile the final server:

```bash
spinel source/simple_server_6.rb -o fyel_srvr
```

Run it:

```bash
./fyel_srvr -p 8080
```

Then open `http://localhost:8080/`.

For quick experiments, Spinel can compile and run in one step:

```bash
spinel -E source/simple_server_6.rb -p 8080
```

## The Examples

- `simple_server_1.rb`: raw POSIX socket bindings with `extern`
- `simple_server_2.rb`: `sp_net` bindings through `ffi_func`
- `simple_server_3.rb`: request parsing and a few hard-coded routes
- `simple_server_4.rb`: `-p`, static files, and directory listings
- `simple_server_5.rb`: `-p`, path cleanup, more content types, downloads
- `simple_server_6.rb`: `-p`, `--no-index`, parent links, icons, file sizes

`native_net.rb` holds the shared `sp_net` bindings used by the later examples.

## Try It

Landing page:

```bash
curl -i http://localhost:8080/
```

Directory listing:

```bash
curl -i http://localhost:8080/public
```

By default, directories serve `index.html` when present. To always show
directory contents instead:

```bash
./fyel_srvr -p 8080 --no-index
```

Traversal check:

```bash
curl -i --path-as-is http://localhost:8080/../../etc/passwd
```

That last request should return `404 Not Found`.

## Notes

- Run the server from the repository root.
- Paths are resolved relative to the current working directory.
- The server is deliberately simple: one connection at a time, up to 2048 bytes
  read per request.
