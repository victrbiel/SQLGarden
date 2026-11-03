#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Optional developer tool only: python3 -m venv .dmg-venv && .dmg-venv/bin/pip install -r scripts/requirements-dmg.txt
# Then: SQLGARDEN_DMG_PYTHON="$PWD/.dmg-venv/bin/python" bash scripts/build-dmg.sh
packaging_python="${SQLGARDEN_DMG_PYTHON:-python3}"
"$packaging_python" -c 'import dmgbuild' 2>/dev/null || {
  echo 'O empacotamento visual requer Python 3 + dmgbuild somente no Mac de desenvolvimento. Consulte README.md.' >&2
  exit 1
}
exec "$packaging_python" scripts/build-dmg.py
