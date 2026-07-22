# workaround_range_slice_test.rb
#
# Probes whether range slices work on poly-typed strings (sp_RbVal).
# If this prints WORKAROUND RESOLVED, remove first_chars() from
# source/parallel_digest.rb and replace its call sites with direct range slices.

arr = ["hello world"]
s = arr[0]    # array element access degrades type to sp_RbVal in Spinel
if s[0...5] == "hello"
  puts "WORKAROUND RESOLVED: range_slice_on_poly_string"
  puts "  Remove first_chars() from source/parallel_digest.rb and replace"
  puts "  its call sites with direct range slices (e.g. digest[0...12])."
else
  puts "range_slice_on_poly_string:still_needed"
end
