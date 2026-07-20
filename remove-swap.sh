#!/bin/bash

# ==================================================================
# Remove Swap Configuration - Post-Sync Optimization
# ==================================================================
# Use this script AFTER node synchronization is complete
# Removes swap to optimize performance for steady-state operations
# ==================================================================

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "=================================================================="
echo "Swap Removal Tool - Post-Sync Optimization"
echo "=================================================================="

# Check if swap exists
SWAP_EXISTS=$(swapon --show | grep -c '/swapfile' || true)
if [[ $SWAP_EXISTS -eq 0 ]]; then
  echo ""
  echo "⚠️  No swapfile detected"
  echo "   Current swap configuration:"
  swapon --show || echo "   (No swap configured)"
  free -h | grep -i swap
  echo ""
  echo "Nothing to remove. Exiting."
  exit 0
fi

echo ""
echo "📊 Current System Status:"
echo ""
free -h
echo ""
swapon --show
echo ""

# Check swap usage
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
if [[ $SWAP_USED -gt 100 ]]; then
  echo "⚠️  WARNING: Swap is actively in use (${SWAP_USED}MB)"
  echo ""
  echo "   System is currently using swap memory. Removing swap now"
  echo "   could cause memory pressure or service instability."
  echo ""
  read -p "   Are you sure you want to continue? (yes/no): " CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    echo ""
    echo "❌ Swap removal cancelled."
    exit 1
  fi
else
  echo "✓ Swap usage is minimal (${SWAP_USED}MB)"
fi

# Confirm removal
echo ""
echo "🗑️  This will:"
echo "   1. Disable swap immediately (swapoff)"
echo "   2. Remove swap configuration from /etc/fstab"
echo "   3. Delete /swapfile (frees up 32GB disk space)"
echo ""
read -p "Proceed with swap removal? (yes/no): " FINAL_CONFIRM

if [[ "$FINAL_CONFIRM" != "yes" ]]; then
  echo ""
  echo "❌ Swap removal cancelled."
  exit 1
fi

echo ""
echo "==> Disabling swap..."
swapoff /swapfile

if [[ $? -eq 0 ]]; then
  echo "   ✓ Swap disabled successfully"
else
  echo "   ❌ Failed to disable swap"
  exit 1
fi

echo ""
echo "==> Removing from /etc/fstab..."
if grep -q '/swapfile' /etc/fstab; then
  sed -i.backup '/\/swapfile/d' /etc/fstab
  echo "   ✓ Removed from /etc/fstab (backup: /etc/fstab.backup)"
else
  echo "   ⚠️  No swap entry found in /etc/fstab"
fi

echo ""
echo "==> Removing swappiness configuration..."
if [[ -f /etc/sysctl.d/99-solana-swap.conf ]]; then
  rm -f /etc/sysctl.d/99-solana-swap.conf
  echo "   ✓ Removed /etc/sysctl.d/99-solana-swap.conf"
else
  echo "   ⚠️  No managed swappiness setting found"
fi
if [[ -f /etc/sysctl.conf ]] && grep -q '^vm\.swappiness=10$' /etc/sysctl.conf; then
  sed -i.backup '/^vm\.swappiness=10$/d' /etc/sysctl.conf
  echo "   ✓ Removed legacy vm.swappiness=10 from /etc/sysctl.conf"
fi

echo ""
echo "==> Deleting swapfile (frees 32GB disk space)..."
if [[ -f /swapfile ]]; then
  rm -f /swapfile
  echo "   ✓ /swapfile deleted"
else
  echo "   ⚠️  /swapfile not found"
fi

echo ""
echo "=================================================================="
echo "✅ Swap Successfully Removed!"
echo "=================================================================="
echo ""
echo "📊 Updated System Status:"
free -h
echo ""
echo "💡 Benefits:"
echo "   - No swap overhead, maximum performance"
echo "   - 32GB disk space freed"
echo "   - Optimized for steady-state RPC operations"
echo ""
echo "⚠️  Important Notes:"
echo "   - Monitor memory usage: systemctl status sol"
echo "   - If memory issues occur, re-add swap with:"
echo "     bash add-swap-128g.sh"
echo "=================================================================="
echo ""
