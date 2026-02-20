#!/usr/bin/env bash
set -euo pipefail

BATCH="${1:-batch1}"

if [[ "$BATCH" == "batch1" ]]; then
  echo "Release Batch 1"
  echo "- Regions: US UK AU CA CN HK TW"
  echo "- Monitor: crash-free sessions, login success, voice transcription success"
elif [[ "$BATCH" == "batch2" ]]; then
  echo "Release Batch 2"
  echo "- Regions: JP FR DE ES KR"
  echo "- Monitor: subscription conversion, localized error rates"
else
  echo "Unknown batch: $BATCH"
  echo "Usage: $0 [batch1|batch2]"
  exit 1
fi
