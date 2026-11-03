#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then
  echo "A validação real usa o driver Microsoft no macOS." >&2; exit 1
fi
if [[ -z "${SQLGARDEN_INTEGRATION_PASSWORD:-}" ]]; then
  echo "Defina SQLGARDEN_INTEGRATION_PASSWORD no ambiente, nunca no código ou logs." >&2; exit 1
fi
mkdir -p .test-build/classroom
swiftc -emit-library -emit-module -module-name StudioCore Sources/StudioCore/*.swift \
  -emit-module-path .test-build/classroom/StudioCore.swiftmodule -o .test-build/classroom/libStudioCore.dylib
cat > .test-build/classroom/module.modulemap <<EOF
module SQLBridge {
  header "$PWD/Sources/SQLBridge/include/SQLBridge.h"
  export *
}
EOF
cc -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -I Sources/SQLBridge/include \
  -c Sources/SQLBridge/SQLBridge.c -o .test-build/classroom/bridge.o
swiftc -parse-as-library -I .test-build/classroom -L .test-build/classroom -lStudioCore \
  -Xlinker -rpath -Xlinker "$PWD/.test-build/classroom" \
  Sources/SQLGarden/SQLClient.swift Tests/MacIntegration/ClassroomAudit.swift \
  .test-build/classroom/bridge.o -o .test-build/classroom/validate
# Apply the same process-local OpenSSL selection as the .app launcher.
for prefix in /opt/homebrew /usr/local; do
  if [[ -r "$prefix/opt/openssl@3/lib/libssl.3.dylib" ]]; then
    export DYLD_LIBRARY_PATH="$prefix/opt/openssl@3/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
    break
  fi
done
export SQLGARDEN_CLASSROOM_JSON="$PWD/.test-build/classroom/results.json"
exec .test-build/classroom/validate "$@"
