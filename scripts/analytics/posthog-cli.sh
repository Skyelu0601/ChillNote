#!/bin/bash
set -euo pipefail

# GUI-launched Xcode/Android Studio may omit Homebrew's Node location from PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
script_dir="$(cd "$(dirname "$0")" && pwd)"
cli="$script_dir/node_modules/.bin/posthog-cli"
if [[ ! -x "$cli" ]]; then
    echo "error: Install symbol tools with npm ci --prefix scripts/analytics" >&2
    exit 1
fi
exec "$cli" "$@"
