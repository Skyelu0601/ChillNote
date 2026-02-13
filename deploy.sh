#!/bin/bash
set -euo pipefail

# Backward-compatible entrypoint.
exec "$(dirname "$0")/scripts/ops/deploy.sh" "$@"
