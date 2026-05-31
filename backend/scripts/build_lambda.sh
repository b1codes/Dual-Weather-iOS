#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING="${BACKEND_DIR}/build/staging"
ZIP_OUT="${BACKEND_DIR}/build/lambda.zip"

rm -rf "${BACKEND_DIR}/build"
mkdir -p "${STAGING}"

echo "[build_lambda] Exporting pinned requirements"
cd "${BACKEND_DIR}"
uv export \
  --frozen \
  --no-dev \
  --no-emit-project \
  --format requirements-txt \
  > "${BACKEND_DIR}/build/requirements.txt"

echo "[build_lambda] Installing deps into staging/"
uv pip install \
  --target "${STAGING}" \
  --requirement "${BACKEND_DIR}/build/requirements.txt" \
  --python-platform aarch64-manylinux2014 \
  --python-version 3.12 \
  --only-binary=:all:

echo "[build_lambda] Copying source"
cp -R "${BACKEND_DIR}/src/dual_weather" "${STAGING}/dual_weather"

find "${STAGING}" -type d -name '__pycache__' -prune -exec rm -rf {} +
find "${STAGING}" -name '*.dist-info' -prune -exec rm -rf {} + 2>/dev/null || true

echo "[build_lambda] Zipping"
cd "${STAGING}"
zip -qr "${ZIP_OUT}" .

SIZE_KB=$(du -k "${ZIP_OUT}" | cut -f1)
echo "[build_lambda] Done — ${ZIP_OUT} (${SIZE_KB} KB)"
