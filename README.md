# FyelSrvr & Spinel Networking Examples

This repository contains step-by-step progressive iterations of a dependency-free, high-performance static file and routing web server (**FyelSrvr**) compiled natively using Matz's experimental Ahead-of-Time (AOT) type-inferred Ruby compiler, **Spinel**.

## Project Architecture

```text
.
├── README.md               # Setup and compilation blueprints
├── index.html              # Branded FyelSrvr premium marketing landing page
├── public/                 # Test directory for streaming file and folder indexes
└── source/
    ├── native_net.rb       # Clean architecture low-level C sp_net FFI bindings
    ├── simple_server_1.rb  # Iteration 1: Native POSIX FFI binding concept
    ├── simple_server_2.rb  # Iteration 2: Core sp_net namespace mapping
    ├── simple_server_3.rb  # Iteration 3: Safe binary string (:binstr) buffer reads
    ├── simple_server_4.rb  # Iteration 4: Static File system POSIX integration
    ├── simple_server_5.rb  # Iteration 5: Strict type-narrowing for ARGV inputs
    └── simple_server_6.rb  # Final FyelSrvr Engine: Secure traversal stack & index routing
```

---

## 1. Getting the Spinel Compiler

You can provision the static compiler toolchain via two distinct deployment methodologies:

### Option A: Automated installation via `asdf` (Recommended)
If you manage tool dependencies using the `asdf` runtime manager, you can automate your binary compilation tracking flags using the community plugin tool:

```bash
# 1. Register the custom version controller plugin repository
asdf plugin add spinel https://github.com/jockofcode/asdf-spinel

# 2. Extract and compile the latest stable automated edge version 
asdf install spinel latest

# 3. Bind the local workspace explicitly to use the compiled toolchain
asdf set spinel master
```

### Option B: Building from Matz's Source Repository
If you prefer tracking upstream changes directly out of the primary engineering core workspace:

```bash
# 1. Clone the master code storage natively
git clone https://github.com/matz/spinel.git 
cd spinel

# 2. Build the parser components and the compiler static runtime library (libspinel_rt.a)
make

# 3. Export the compiled path binary string globally onto your system profile
export PATH="\(PWD/bin:\)PATH"
cd -
```

---

## 2. Compilation and Execution

Because Spinel parses your whole program type graph down to pure, direct C layout maps before leveraging your system's `clang` or `gcc` compiler, you only need to supply the main script entry-point to the compiler. The tool resolves local `require_relative` directives autonomously.

### Compiling a Specific Iteration
To build the final feature-complete, secure **FyelSrvr** assembly loop (`simple_server_6.rb`):

```bash
# Invoke the static compilation pipeline targeting a native machine binary
spinel compile source/simple_server_6.rb -o fyel_srvr
```

### Running the Standalone Native Executable
Once compiled, your binary operates autonomously with **zero reliance on a Ruby Virtual Machine**.

```bash
# Boot the application server binary (Optionally passing a custom port number argument)
./fyel_srvr 8080
```

---

## 3. Verifying Server Operations

Once the native binary engine is listening on your local socket, perform the following validation workflows via your web browser or command-line utility tools:

1. **Branded Marketing Landing Page:** Navigate to `http://localhost:8080/`. The system auto-detects your custom `index.html` structure and bypasses raw folder indexing layout engines.
2. **SVG File Listing and Sizes:** Create assets inside your `./public` testing space and load `http://localhost:8080/public`. The server displays clean vector SVG indicators alongside human-readable integer space filesizes down to a decimal point (e.g., `4.2 KB`).
3. **Directory Traversal Verification:** Test the safety boundary layers directly to confirm path stack sanitation blocks root escape attempts:
   ```bash
   curl --path-as-is http://localhost:8080/../../etc/passwd
   ```
   *Expected Outcome: Returns a structured `404 Not Found` response payload without escaping your sandbox folder containment space.*

