#!/bin/bash
set -euo pipefail

# Run against the exact archive being shipped. Only debug symbols, never source files.
script_dir="$(cd "$(dirname "$0")" && pwd)"
archive_path="${1:?Usage: upload-ios-symbols.sh /path/to/app.xcarchive}"
cli="$script_dir/posthog-cli.sh"
if [[ ! -x "$cli" ]]; then
    echo "error: Install symbol tools with npm ci --prefix scripts/analytics" >&2
    exit 1
fi
if [[ ! -d "$archive_path/dSYMs" ]]; then
    echo "error: Archive has no dSYMs: $archive_path" >&2
    exit 1
fi
export POSTHOG_CLI_HOST="https://us.posthog.com"
export POSTHOG_CLI_PROJECT_ID="596105"
exec "$cli" symbol-sets upload --directory "$archive_path/dSYMs" \
    --info-plist "$archive_path/Products/Applications/chillnote.app/Info.plist"
