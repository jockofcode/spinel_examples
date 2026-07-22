# workaround_split_poly_test.rb
#
# Probes whether String#split works on poly-typed strings (sp_RbVal).
# If this prints WORKAROUND RESOLVED, the char-walk functions below can
# be replaced with direct .split() calls.
#
# Affected workarounds:
#   source/parallel_digest.rb  - split_tab() char loop, replace with .split("\t")
#   source/token_api.rb        - verify_token() char loop, replace with .split(".")

arr = ["path\tdigest"]
s = arr[0]    # array element access degrades type to sp_RbVal in Spinel
split_ok = false
begin
  parts = s.split("\t")
  split_ok = parts.length == 2 && parts[0] == "path" && parts[1] == "digest"
rescue
  split_ok = false
end
if split_ok
  puts "WORKAROUND RESOLVED: split_on_poly_string"
  puts "  Remove split_tab() from source/parallel_digest.rb, replace with .split(\"\\t\")."
  puts "  Remove the char-walk in verify_token() in source/token_api.rb, replace with .split(\".\")."
else
  puts "split_on_poly_string:still_needed"
end
