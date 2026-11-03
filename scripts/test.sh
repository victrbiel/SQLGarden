#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/test-bridge.sh
swift test --filter StudioCoreTests
