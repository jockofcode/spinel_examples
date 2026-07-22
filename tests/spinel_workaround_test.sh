#!/bin/sh
# spinel_workaround_test.sh
#
# Runs each workaround probe file individually with spinel so that a compile-
# time type error in one probe (e.g. passing sp_RbVal to const char*) does not
# prevent the others from running.  Each probe prints either "still_needed" or
# "WORKAROUND RESOLVED: ..." with the exact location to clean up.
#
# Usage: sh tests/spinel_workaround_test.sh

cd "$(dirname "$0")/.."

run_probe() {
  file="$1"
  name=$(basename "$file" .rb)
  bin=$(mktemp)
  spinel "$file" -o "$bin" 2>/dev/null
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "${name}:still_needed (compile error -- workaround is still required)"
    rm -f "$bin"
    return
  fi
  out=$("$bin")
  rm -f "$bin"
  echo "$out"
}

# Fixed 2026-07-22: range slice on poly-typed strings; first_chars() removed from parallel_digest.rb
# run_probe tests/workaround_range_slice_test.rb

# Fixed 2026-07-22: String#split on poly-typed strings; split_tab() removed from parallel_digest.rb, char-walk removed from verify_token() in token_api.rb
# run_probe tests/workaround_split_poly_test.rb

run_probe tests/workaround_queue_file_read_test.rb

# Fixed 2026-07-22: ARGV elements can be passed directly to File.read; coercion removed from todo_cli.rb
# run_probe tests/workaround_argv_file_path_test.rb

# Fixed 2026-07-22: .to_i can be called directly on ARGV elements; coercion removed from token_api.rb
# run_probe tests/workaround_argv_to_i_test.rb

run_probe tests/workaround_socket_tcp_shim_test.rb
run_probe tests/workaround_socket_full_shim_test.rb
run_probe tests/workaround_openssl_shim_test.rb
