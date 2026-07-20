#!/bin/bash
set -euo pipefail

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ((TOTAL_MEM_GB < 160)); then
  PROFILE=128g
elif ((TOTAL_MEM_GB < 224)); then
  PROFILE=192g
elif ((TOTAL_MEM_GB < 384)); then
  PROFILE=256g
else
  PROFILE=512g
fi

echo "Detected ${TOTAL_MEM_GB}GB RAM; selected $PROFILE profile"
exec "$SCRIPT_DIR/validator.sh" "$PROFILE"
