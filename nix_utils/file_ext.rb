# file_ext.rb -- native_func bindings for File methods missing in Spinel.
#
# COMPILATION
#   SPINEL_LIB=~/.asdf/installs/spinel/master/lib/spinel
#   cc -c nix_utils/sp_file_ext.c -I$SPINEL_LIB/lib -o nix_utils/sp_file_ext.o
#   spinel nix_utils/tool.rb --link nix_utils/sp_file_ext.o -o nix_utils/bin/tool
#
# HOW THE DUAL-RUNTIME TRICK WORKS
#   `def self.native_func(*args); end` is a no-op in CRuby.
#   Spinel recognizes `native_func` as a built-in class-body directive even
#   when a Ruby-level method of the same name exists; Spinel's binding wins
#   at every call site and the def is compiled but never called.
#   The fallback def bodies use only backtick/system calls (Spinel-compatible),
#   so Spinel can type-check them without error.
#
# USAGE IN TOOLS
#   Call FileExt.readlink(path) / FileExt.stat_str(path) etc. instead of
#   the missing File class methods.  Under Spinel the C functions run directly;
#   under CRuby the backtick / system fallbacks below are used.

module FileExt
  # Makes `native_func(...)` a no-op in CRuby instead of a NameError.
  # Spinel ignores this def and uses its own built-in native_func semantics.
  def self.native_func(*args); end

  # ---- Spinel C bindings (built from sp_file_ext.c, linked via --link) ----

  # FileExt.readlink(path) -> String  (symlink target, or "" on error)
  native_func :readlink,  [:string],             :string, "sp_file_readlink"

  # FileExt.symlink(target, link_path) -> Integer  (0 = ok, errno on failure)
  native_func :symlink,   [:string, :string],    :int,    "sp_file_symlink_c"

  # FileExt.link(src, dst) -> Integer  (0 = ok, errno on failure)
  native_func :link,      [:string, :string],    :int,    "sp_file_link_c"

  # FileExt.chmod(mode_int, path) -> Integer  (0 = ok, errno on failure)
  native_func :chmod,     [:int, :string],       :int,    "sp_file_chmod_c"

  # FileExt.stat_str(path)  -> "mode_oct nlinks uid gid size blocks ino dev atime mtime ctime"
  # FileExt.lstat_str(path) ->  same but does not follow symlinks
  # Returns "" on error.  Split on " " to get individual fields.
  native_func :stat_str,  [:string],             :string, "sp_file_stat_str"
  native_func :lstat_str, [:string],             :string, "sp_file_lstat_str"

  # FileExt.utime_c(atime_epoch, mtime_epoch, path) -> Integer  (0 = ok, errno on failure)
  native_func :utime_c,   [:int, :int, :string], :int,    "sp_file_utime_c"

  # ---- CRuby fallback defs -----------------------------------------------
  # Spinel: compiles these (only backtick/system ops, which Spinel supports)
  #   but native_func takes priority at every call site — these are unreachable.
  # CRuby: no native_func machinery; these are the real implementations.

  def self.readlink(path)
    cpath = "" + path
    raw = "" + `/usr/bin/stat -f '%Y' '#{cpath}' 2>/dev/null`
    "" + raw.chomp
  end

  def self.symlink(target, link_path)
    ctgt  = "" + target
    clink = "" + link_path
    system("/bin/ln -s " + ctgt + " " + clink)
    0
  end

  def self.link(src, dst)
    csrc = "" + src
    cdst = "" + dst
    system("/bin/ln " + csrc + " " + cdst)
    0
  end

  def self.chmod(mode, path)
    cpath = "" + path
    system("/bin/chmod " + mode.to_s(8) + " " + cpath)
    0
  end

  def self.stat_str(path)
    cpath = "" + path
    raw = "" + `/usr/bin/stat -f '%p %l %u %g %z %b %i %d %a %m %c' '#{cpath}' 2>/dev/null`
    "" + raw.chomp
  end

  def self.lstat_str(path)
    cpath = "" + path
    raw = "" + `/usr/bin/stat -f '%p %l %u %g %z %b %i %d %a %m %c' '#{cpath}' 2>/dev/null`
    "" + raw.chomp
  end

  def self.utime_c(atime, mtime, path)
    cpath = "" + path
    system("/usr/bin/touch -t " + mtime.to_s + " '" + cpath + "' 2>/dev/null")
    0
  end
end
