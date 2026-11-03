#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .test-build/ui
swiftc -emit-library -emit-module -module-name StudioCore Sources/StudioCore/*.swift \
  -emit-module-path .test-build/ui/StudioCore.swiftmodule -o .test-build/ui/libStudioCore.dylib
cat > .test-build/ui/module.modulemap <<MAP
module SQLBridge {
  header "$PWD/Sources/SQLBridge/include/SQLBridge.h"
  export *
}
MAP
cc -std=c11 -D_POSIX_C_SOURCE=200809L -Wall -Wextra -Werror -I Sources/SQLBridge/include \
  -c Sources/SQLBridge/SQLBridge.c -o .test-build/ui/bridge.o
sources=()
for source in Sources/SQLGarden/*.swift; do
  [[ "$source" == */SQLGardenApp.swift ]] || sources+=("$source")
done
swiftc -parse-as-library -I .test-build/ui -L .test-build/ui -lStudioCore \
  -Xlinker -rpath -Xlinker "$PWD/.test-build/ui" \
  "${sources[@]}" Tests/MacUI/Validation.swift .test-build/ui/bridge.o -o .test-build/ui/validate
for prefix in /opt/homebrew /usr/local; do
  if [[ -r "$prefix/opt/openssl@3/lib/libssl.3.dylib" ]]; then
    export DYLD_LIBRARY_PATH="$prefix/opt/openssl@3/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
    break
  fi
done
exec .test-build/ui/validate
