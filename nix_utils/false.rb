# false.rb, do nothing, unsuccessfully (GNU false, Spinel port).
#
# Exit with a status code indicating failure.  All arguments are ignored,
# matching GNU false behavior.
#
# Compile: spinel nix_utils/false.rb -o nix_utils/bin/false
# Run:
#   ./bin/false || echo no    # -> no
#
# Core Ruby only; no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/false.rb ...`).

exit 1
