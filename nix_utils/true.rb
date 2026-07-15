# true.rb, do nothing, successfully (GNU true, Spinel port).
#
# Exit with a status code indicating success.  All arguments are ignored
# (including --help and --version), matching GNU true behavior.
#
# Compile: spinel nix_utils/true.rb -o nix_utils/bin/true
# Run:
#   ./bin/true && echo yes    # -> yes
#
# Core Ruby only; no require gate needed.
# Runs unmodified under CRuby (`ruby nix_utils/true.rb ...`).

exit 0
