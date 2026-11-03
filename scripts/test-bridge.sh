#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .test-build
compiler="${CC:-cc}"
if [[ "$(uname -s)" == "Darwin" ]]; then
  shared_flags=(-dynamiclib)
  extra_links=(-lpthread)
  header_flags=(-I Sources/SQLBridge/include)
  if command -v brew >/dev/null 2>&1; then
    header_flags+=(-I "$(brew --prefix unixodbc)/include")
  fi
else
  shared_flags=(-shared)
  extra_links=(-ldl -lpthread)
  header_flags=(-I Sources/SQLBridge/include)
fi
"$compiler" -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -fPIC "${shared_flags[@]}" Tests/BridgeTests/fake_odbc.c -o .test-build/libodbc-test.so
"$compiler" -std=c11 -D_POSIX_C_SOURCE=200809L -DSG_TESTING -Wall -Wextra -Werror -fPIC "${shared_flags[@]}" Sources/SQLBridge/SQLBridge.c "${header_flags[@]}" "${extra_links[@]}" -o .test-build/bridge.so
python3 Tests/BridgeTests/test_bridge.py
