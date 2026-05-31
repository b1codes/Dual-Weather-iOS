#!/usr/bin/env bash
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA_RUNTIME="${BACKEND_DIR}/../infra/runtime"
ZIP_PATH="${BACKEND_DIR}/build/lambda.zip"

if [ ! -f "${ZIP_PATH}" ]; then
  echo "[deploy] ${ZIP_PATH} not found. Run 'make package' first." >&2
  exit 1
fi

echo "[deploy] Reading function name from ${INFRA_RUNTIME}"
FUNCTION_NAME=$(terraform -chdir="${INFRA_RUNTIME}" output -raw function_name)
REGION="us-east-2"

echo "[deploy] Uploading ${ZIP_PATH} to function ${FUNCTION_NAME} in ${REGION}"
aws lambda update-function-code \
  --region "${REGION}" \
  --function-name "${FUNCTION_NAME}" \
  --zip-file "fileb://${ZIP_PATH}" \
  --publish \
  --output text \
  --query 'FunctionArn'

echo "[deploy] Waiting for code update to finish"
aws lambda wait function-updated --region "${REGION}" --function-name "${FUNCTION_NAME}"

echo "[deploy] Ensuring handler is set to dual_weather.main.handler"
aws lambda update-function-configuration \
  --region "${REGION}" \
  --function-name "${FUNCTION_NAME}" \
  --handler dual_weather.main.handler \
  --output text \
  --query 'LastUpdateStatus' > /dev/null

aws lambda wait function-updated --region "${REGION}" --function-name "${FUNCTION_NAME}"

echo "[deploy] Done"
