# run_app_tests.sh -- run the black-box test suite for all four example apps.
#
# Builds any missing binaries (each per-app script self-builds) and runs the
# per-app tests, which each assert exact behavior against BOTH the compiled
# Spinel binary and the CRuby source. Prints a final ALL GREEN only if every
# app's suite passed. This complements scripts/build_all.sh: build_all is a
# fast smoke test, this is the thorough behavior/parity suite.
#
# Usage: sh tests/run_app_tests.sh

cd "$(dirname "$0")/.."

SUITES="fyel_srvr todo_cli log_report token_api parallel_digest"
FAILED=""

for name in $SUITES; do
  echo "############################################################"
  echo "# $name"
  echo "############################################################"
  if sh "tests/${name}_test.sh"; then
    :
  else
    FAILED="$FAILED $name"
  fi
  echo ""
done

echo "============================================================"
if [ -z "$FAILED" ]; then
  echo "APP TESTS: ALL GREEN"
  exit 0
fi
echo "APP TESTS FAILED:$FAILED"
exit 1
