#!/usr/bin/env bash
#
# start.sh - Run CLIProxyAPI from source with the local config file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

CONFIG_PATH="${CLI_PROXY_CONFIG_PATH:-./config.yaml}"

if ! command -v go >/dev/null 2>&1; then
  echo "Error: Go is not installed or not in PATH."
  exit 1
fi

if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "Error: config file not found: ${CONFIG_PATH}"
  echo "Hint: copy config.example.yaml to config.yaml first."
  exit 1
fi

exec go run ./cmd/server -config "${CONFIG_PATH}" "$@"
