#!/bin/bash
# ============================================
# Auto-select appropriate validator script based on system RAM
# ============================================

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)

if [[ $TOTAL_MEM_GB -lt 160 ]]; then
  # TIER 1: 128GB
  VALIDATOR_SCRIPT="/root/sol/bin/validator-128g.sh"
  echo "🚀 Starting TIER 1 (128GB) validator configuration"
elif [[ $TOTAL_MEM_GB -lt 224 ]]; then
  # TIER 2: 192GB
  VALIDATOR_SCRIPT="/root/sol/bin/validator-192g.sh"
  echo "🚀 Starting TIER 2 (192GB) validator configuration"
elif [[ $TOTAL_MEM_GB -lt 384 ]]; then
  # TIER 3: 256GB
  VALIDATOR_SCRIPT="/root/sol/bin/validator-256g.sh"
  echo "🚀 Starting TIER 3 (256GB) validator configuration"
else
  # TIER 4: 512GB+
  VALIDATOR_SCRIPT="/root/sol/bin/validator-512g.sh"
  echo "🚀 Starting TIER 4 (512GB+) validator configuration"
fi

# Check if the selected validator script exists
if [[ ! -f "$VALIDATOR_SCRIPT" ]]; then
  echo "❌ ERROR: Validator script not found: $VALIDATOR_SCRIPT"
  echo "Available scripts:"
  ls -1 /root/sol/bin/validator*.sh 2>/dev/null || echo "None found"
  exit 1
fi

# Execute the selected validator script
echo "System RAM: ${TOTAL_MEM_GB}GB"
echo "Executing: $VALIDATOR_SCRIPT"
exec "$VALIDATOR_SCRIPT"
