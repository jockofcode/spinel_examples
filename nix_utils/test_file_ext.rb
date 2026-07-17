require_relative 'file_ext'

system("/bin/ln -sf /tmp /tmp/sp_test_link")

target = FileExt.readlink("/tmp/sp_test_link")
puts "readlink: " + target

s = FileExt.stat_str("/tmp/sp_test_link")
puts "stat_str: " + s

ls = FileExt.lstat_str("/tmp/sp_test_link")
puts "lstat_str: " + ls

r = FileExt.symlink("/tmp", "/tmp/sp_test_sym2")
puts "symlink rc: " + r.to_s
puts "symlink exists: " + File.symlink?("/tmp/sp_test_sym2").to_s

r2 = FileExt.link("/tmp/sp_test_link", "/tmp/sp_test_hardlink")
puts "link rc: " + r2.to_s
puts "link exists: " + File.exist?("/tmp/sp_test_hardlink").to_s

system("/bin/rm -f /tmp/sp_test_link /tmp/sp_test_sym2 /tmp/sp_test_hardlink")
puts "done"
