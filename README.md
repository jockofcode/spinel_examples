# Spinel Examples: 5 Real Apps Compiled with Spinel

A set of professional example applications for learning the
[Spinel](https://github.com/matz/spinel) ahead-of-time Ruby-to-C compiler.
Each app is well-commented, compiles to a standalone native binary, and also
runs unmodified under plain `ruby`.

The repository ships five apps, a one-command build/smoke-test script
(`scripts/build_all.sh`), and a self-contained meetup slideshow
(`slides/july_2026_ruby_meetup.html`).

## What's Here

```text
.
├── README.md
├── .tool-versions
├── index.html            # demo page served by FyelSrvr
├── slides/
│   └── july_2026_ruby_meetup.html   # self-contained meetup slideshow
├── bin/                  # compiled binaries (generated)
├── data/
│   └── sample_access.log # sample input for log_report
├── native/
│   └── socket_ext/       # C extension for the raw-socket example
├── notes/                # Spinel reference + method-gap notes
├── public/               # static assets for the file-server demo
├── scripts/
│   └── build_all.sh      # build all apps + smoke test each
├── source/               # all five apps + the FyelSrvr progression
│   ├── lib/
│   │   └── socket_shim.rb                        # shared socket compatibility layer
│   ├── fyel_srvr_1.rb .. fyel_srvr_6.rb          # FyelSrvr build-up
│   ├── todo_cli.rb
│   ├── log_report.rb
│   ├── token_api.rb
│   └── parallel_digest.rb
└── tests/                # CRuby tests for socket_shim
```

Binaries in `bin/` are generated. Rebuild them whenever you want fresh copies.

## Apps

| App | Source | Compile | Run | Showcases |
|-----|--------|---------|-----|-----------|
| FyelSrvr | `source/fyel_srvr_6.rb` | `spinel source/fyel_srvr_6.rb -o bin/fyel_srvr` | `./bin/fyel_srvr -p 8080` | Sockets, HTTP, directory listings, path-traversal defense |
| todo_cli | `source/todo_cli.rb` | `SPINEL_REQUIRE_GATE=1 spinel source/todo_cli.rb -o bin/todo_cli` | `./bin/todo_cli add "write slides"` | CLI flags + `json` persistence round-trip |
| log_report | `source/log_report.rb` | `SPINEL_REQUIRE_GATE=1 spinel source/log_report.rb -o bin/log_report` | `./bin/log_report data/sample_access.log` | Named-capture Regexp, `StringScanner`, `Set` |
| token_api | `source/token_api.rb` | `SPINEL_REQUIRE_GATE=1 spinel source/token_api.rb -o bin/token_api` | `./bin/token_api -p 8080` | JSON API, HMAC tokens via FFI (`sp_crypto`) |
| parallel_digest | `source/parallel_digest.rb` | `SPINEL_REQUIRE_GATE=1 spinel source/parallel_digest.rb -o bin/parallel_digest` | `./bin/parallel_digest source -w 4` | `Thread` / `Queue` / `Mutex` worker pool |

Every app also runs under CRuby, e.g. `ruby source/todo_cli.rb list`.

## Install Spinel

With `asdf`:

```bash
asdf plugin add spinel https://github.com/jockofcode/asdf-spinel
asdf install spinel master
asdf set -u spinel master   # make it the default (~/.tool-versions)
```

Or build it from source:

```bash
git clone https://github.com/matz/spinel.git
cd spinel
make
export PATH="$PWD/bin:$PATH"
cd -
```

## Build everything

The fastest way to build all five apps and confirm each one runs:

```bash
sh scripts/build_all.sh
```

It compiles every app into `bin/` and smoke-tests each one, printing
`ALL GREEN` on success (and exiting non-zero if anything fails).

## Build and Run (individually)

Compile the final server:

```bash
spinel source/fyel_srvr_6.rb -o bin/fyel_srvr
```

Compile the raw socket example with the project-local native extension:

```bash
spinel --link native/socket_ext/socket_ext.c source/fyel_srvr_1.rb -o bin/fyel_srvr_1
```

Run it:

```bash
./bin/fyel_srvr -p 8080
```

Then open `http://localhost:8080/`.

For quick experiments, Spinel can compile and run in one step:

```bash
spinel -E source/fyel_srvr_6.rb -p 8080
```

## How FyelSrvr was built up

FyelSrvr (`fyel_srvr_6.rb`) is the end of a six-step progression, each
step adding one idea:

- `fyel_srvr_1.rb`: raw `Socket.new` / `bind` / `listen` / `accept` through the native extension
- `fyel_srvr_2.rb`: a tiny HTTP response with Ruby-shaped `TCPServer`
- `fyel_srvr_3.rb`: request parsing and a few hard-coded routes
- `fyel_srvr_4.rb`: `-p`, static files, and directory listings
- `fyel_srvr_5.rb`: `-p`, path cleanup, more content types, downloads
- `fyel_srvr_6.rb`: `-p`, `--no-index`, parent links, icons, file sizes

`lib/socket_shim.rb` is the small compatibility layer that lets examples run
under CRuby with `socket` and under Spinel with the same Ruby-shaped socket
calls. The later web-server examples use Spinel's built-in `sp_net` helpers
and compile without extra link inputs; lower-level socket features use
`native/socket_ext/socket_ext.c`.

## Try It (FyelSrvr)

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
./bin/fyel_srvr -p 8080 --no-index
```

Traversal check:

```bash
curl -i --path-as-is http://localhost:8080/../../etc/passwd
```

That last request should return `404 Not Found`.

## Slideshow

`slides/july_2026_ruby_meetup.html` is a self-contained deck (no external
assets) built for a Ruby Meetup talk that tours these five apps. Open it in
any browser:

```bash
open slides/july_2026_ruby_meetup.html
```

Navigate with the arrow keys or the on-screen ‹ › buttons; `#12` in the URL
jumps to a specific slide.

## Notes

- Run the server from the repository root.
- Paths are resolved relative to the current working directory.
- The server is deliberately simple: one connection at a time, up to 2048 bytes
  read per request.
