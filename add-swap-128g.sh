#!/bin/bash

# ==================================================================
# Add 32GB Swap for Low Memory Systems (<160GB)
# ==================================================================
# Only adds swap if system RAM < 160GB
# Recommended for 128GB systems running Tier 1 configuration
# ==================================================================

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "=================================================================="
echo "Swap Configuration for Low Memory Systems"
echo "=================================================================="

# Detect system memory
TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
echo "System Memory: ${TOTAL_MEM_GB}GB detected"

# Check if swap addition is needed
if [[ $TOTAL_MEM_GB -ge 160 ]]; then
  echo ""
  echo "⚠️  System has ${TOTAL_MEM_GB}GB RAM (>= 160GB)"
  echo "   Swap is NOT recommended for high memory systems"
  echo "   Skipping swap configuration"
  exit 0
fi

echo ""
echo "✓ System qualifies for swap addition (${TOTAL_MEM_GB}GB < 160GB)"

# Check if swap already exists
EXISTING_SWAP=$(swapon --show | grep -c '/swapfile' || true)
if [[ $EXISTING_SWAP -gt 0 ]]; then
  echo ""
  echo "⚠️  Swap already configured:"
  swapon --show
  free -h | grep -i swap
  echo ""
  echo "Skipping swap creation"
  exit 0
fi

echo ""
echo "==> Creating 32GB swapfile..."
fallocate -l 32G /swapfile || dd if=/dev/zero of=/swapfile bs=1G count=32

echo "==> Setting permissions..."
chmod 600 /swapfile

echo "==> Formatting as swap..."
mkswap /swapfile

echo "==> Enabling swap..."
swapon /swapfile

echo ""
echo "==> Current swap status:"
free -h | grep -i swap
swapon --show

# Configure persistent swap
echo ""
echo "==> Configuring persistent swap..."
if ! grep -q '/swapfile' /etc/fstab; then
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "   ✓ Added to /etc/fstab (auto-mount on boot)"
else
  echo "   ✓ Already in /etc/fstab"
fi

# Set swappiness to minimize swap usage
echo ""
echo "==> Setting swappiness=10 (minimize swap usage)..."
sysctl vm.swappiness=10
if ! grep -q 'vm.swappiness' /etc/sysctl.conf; then
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
  echo "   ✓ Added to /etc/sysctl.conf (persistent)"
else
  echo "   ✓ Already in /etc/sysctl.conf"
fi

echo ""
echo "=================================================================="
echo "✅ 32GB Swap Successfully Configured!"
echo "=================================================================="
echo "Physical RAM:  ${TOTAL_MEM_GB}GB"
echo "Swap Space:    32GB"
echo "Total Available: $((TOTAL_MEM_GB + 32))GB"
echo ""
echo "Swappiness: 10 (minimal swap usage - only when RAM is full)"
echo "=================================================================="
