#!/bin/sh

set -eu

archive_path="${1:-${ARCHIVE_PATH:-}}"
framework_name="GoMarketMeAppleCoreKit"

if [ -z "$archive_path" ] || [ ! -d "$archive_path" ]; then
    echo "error: GoMarketMe dSYM fix requires a valid .xcarchive path." >&2
    exit 1
fi

framework_binary="$(find "$archive_path/Products/Applications" \
    -path "*/Frameworks/$framework_name.framework/$framework_name" \
    -type f \
    -print \
    -quit)"

if [ -z "$framework_binary" ]; then
    echo "warning: $framework_name.framework was not found in the archive; skipping dSYM generation."
    exit 0
fi

dsym_path="$archive_path/dSYMs/$framework_name.framework.dSYM"
dsym_binary="$dsym_path/Contents/Resources/DWARF/$framework_name"

binary_uuid="$(/usr/bin/dwarfdump --uuid "$framework_binary" | /usr/bin/awk '{print $2; exit}')"

if [ -f "$dsym_binary" ]; then
    dsym_uuid="$(/usr/bin/dwarfdump --uuid "$dsym_binary" | /usr/bin/awk '{print $2; exit}')"
    if [ "$binary_uuid" = "$dsym_uuid" ]; then
        echo "$framework_name dSYM already matches UUID $binary_uuid."
        exit 0
    fi

    echo "warning: Replacing mismatched $framework_name dSYM (expected $binary_uuid, found $dsym_uuid)."
    /bin/rm -rf "$dsym_path"
fi

/usr/bin/dsymutil "$framework_binary" -o "$dsym_path"

if [ ! -f "$dsym_binary" ]; then
    echo "error: dsymutil did not create the expected $framework_name DWARF file." >&2
    exit 1
fi

dsym_uuid="$(/usr/bin/dwarfdump --uuid "$dsym_binary" | /usr/bin/awk '{print $2; exit}')"
if [ "$binary_uuid" != "$dsym_uuid" ]; then
    echo "error: Generated $framework_name dSYM UUID $dsym_uuid does not match framework UUID $binary_uuid." >&2
    exit 1
fi

echo "Generated $framework_name compatibility dSYM with matching UUID $binary_uuid."
echo "warning: The vendor binary contains no source-level debug symbols; ask GoMarketMe for the original dSYM."
