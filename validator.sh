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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================================="
echo "Solana RPC Validator - Auto-Selector"
echo "System Memory: ${TOTAL_MEM_GB}GB detected"
echo "=================================================================="

# Select appropriate configuration based on memory
if [[ $TOTAL_MEM_GB -lt 160 ]]; then
  CONFIG_FILE="$SCRIPT_DIR/validator-128g.sh"
  echo "Selected: TIER 1 (128GB) - Optimized Standard"
  echo "✅ Full RPC features with conservative parameters"
elif [[ $TOTAL_MEM_GB -lt 224 ]]; then
  CONFIG_FILE="$SCRIPT_DIR/validator-192g.sh"
  echo "Selected: TIER 2 (192GB) - Standard Configuration"
  echo "✅ Full RPC features with recommended parameters"
elif [[ $TOTAL_MEM_GB -lt 384 ]]; then
  CONFIG_FILE="$SCRIPT_DIR/validator-256g.sh"
  echo "Selected: TIER 3 (256GB) - High Performance"
  echo "✅ Enhanced RPC performance and capacity"
else
  CONFIG_FILE="$SCRIPT_DIR/validator-512g.sh"
  echo "Selected: TIER 4 (512GB+) - Maximum Performance"
  echo "✅ Maximum RPC capacity and throughput"
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
