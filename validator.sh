#!/bin/bash

# ==================================================================
# Solana RPC Validator - Auto-Selector
# ==================================================================
# Automatically detects system memory and launches appropriate config
# Available configurations:
#   - validator-128g.sh: 128GB RAM (Extreme optimization, no TX history)
#   - validator-192g.sh: 192GB RAM (Standard, full RPC features)
#   - validator-256g.sh: 256GB RAM (High performance)
#   - validator-512g.sh: 512GB+ RAM (Maximum performance)
# ==================================================================

# Detect system memory in GB
TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
SWAP_GB=$(free -m | awk '/Swap:/ {printf "%.0f", $2/1024}')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================================="
echo "Solana RPC Validator - Auto-Selector"
echo "System Memory: ${TOTAL_MEM_GB}GB detected"

# Check for swap and adjust available memory
if [[ $SWAP_GB -gt 20 ]]; then
  TOTAL_AVAILABLE=$((TOTAL_MEM_GB + SWAP_GB))
  echo "Swap Space: ${SWAP_GB}GB detected"
  echo "Total Available: ${TOTAL_AVAILABLE}GB (RAM + Swap)"
  MEMORY_FOR_SELECTION=$TOTAL_AVAILABLE
else
  echo "No significant swap detected"
  MEMORY_FOR_SELECTION=$TOTAL_MEM_GB
fi

echo "=================================================================="

# Select appropriate configuration based on available memory
# With swap: lower thresholds by 10GB to enable full features sooner
if [[ $SWAP_GB -gt 20 ]]; then
  TIER2_THRESHOLD=150
  TIER3_THRESHOLD=214
  TIER4_THRESHOLD=374
else
  TIER2_THRESHOLD=160
  TIER3_THRESHOLD=224
  TIER4_THRESHOLD=384
fi

if [[ $MEMORY_FOR_SELECTION -lt $TIER2_THRESHOLD ]]; then
  CONFIG_FILE="$SCRIPT_DIR/validator-128g.sh"
  echo "Selected: TIER 1 (128GB) - Extreme Optimization"
  echo "⚠️  Note: Transaction history DISABLED to minimize memory"
elif [[ $MEMORY_FOR_SELECTION -lt $TIER3_THRESHOLD ]]; then
  CONFIG_FILE="$SCRIPT_DIR/validator-192g.sh"
  echo "Selected: TIER 2 (192GB) - Standard Configuration"
  echo "✅ Full RPC features ENABLED (including transaction history)"
elif [[ $MEMORY_FOR_SELECTION -lt $TIER4_THRESHOLD ]]; then
  CONFIG_FILE="$SCRIPT_DIR/validator-256g.sh"
  echo "Selected: TIER 3 (256GB) - High Performance"
  echo "✅ Full RPC features ENABLED with enhanced performance"
else
  CONFIG_FILE="$SCRIPT_DIR/validator-512g.sh"
  echo "Selected: TIER 4 (512GB+) - Maximum Performance"
  echo "✅ Full RPC features ENABLED with maximum resources"
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ ERROR: Configuration file not found: $CONFIG_FILE"
  exit 1
fi

echo "Launching: $(basename $CONFIG_FILE)"
echo "=================================================================="

# Execute the selected configuration
exec "$CONFIG_FILE"
