#!/bin/bash
set -euo pipefail

# ============================================
# Step 3: Download snapshot and start Solana RPC node
# ============================================
# Prerequisite: Run 1-prepare.sh and 2-install-jito-validator.sh first, then reboot
# ============================================

SERVICE_NAME=${SERVICE_NAME:-sol}
LEDGER=${LEDGER:-/root/sol/ledger}
ACCOUNTS=${ACCOUNTS:-/root/sol/accounts}
SNAPSHOT=${SNAPSHOT:-/root/sol/snapshot}
LOGFILE=/root/solana-rpc.log

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

echo "============================================"
echo "Step 3: Download snapshot and start node"
echo "============================================"
echo ""

# Verify system optimizations
echo "==> 1) Verify system optimizations..."
echo ""

# BBR
bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [[ "$bbr" == "bbr" ]]; then
  echo "  ✅ BBR congestion control: enabled"
else
  echo "  ⚠️  BBR congestion control: disabled (current: $bbr)"
fi

# TCP buffer
rmem=$(sysctl -n net.core.rmem_max 2>/dev/null || echo "0")
if [[ "$rmem" == "536870912" ]]; then
  echo "  ✅ TCP buffer: 512MB (max)"
else
  echo "  ⚠️  TCP buffer: not at max (current: $rmem, expected: 536870912)"
fi

# Disk read-ahead
for dev in /sys/block/nvme* /sys/block/sd*; do
  [[ -e "$dev" ]] || continue
  devname=$(basename "$dev")
  ra=$(cat "$dev/queue/read_ahead_kb" 2>/dev/null || echo "0")
  if [[ "$ra" == "32768" ]]; then
    echo "  ✅ Disk read-ahead: 32MB ($devname)"
  else
    echo "  ⚠️  Disk read-ahead: not at max (current: ${ra}KB, expected: 32768KB)"
  fi
  break
done

echo ""
echo "==> 2) Stop existing service..."
systemctl stop $SERVICE_NAME 2>/dev/null || true
sleep 2
echo "  ✅ Service stopped"

echo ""
echo "==> 3) Clean old data (keep identity key)..."
rm -f "$LOGFILE" || true

# Clean dirs
dirs=("$LEDGER" "$ACCOUNTS" "$SNAPSHOT")
for dir in "${dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    echo "  - Cleaning dir: $dir"
    rm -rf "$dir"/* "$dir"/.[!.]* "$dir"/..?* || true
  else
    echo "  - Creating dir: $dir"
    mkdir -p "$dir"
  fi
done
echo "  ✅ Old data cleaned"

echo ""
echo "==> 4) Prepare snapshot download tool..."
cd /root

# Install deps
echo "  - Installing Python deps..."
apt-get update -qq
apt-get install -y python3-venv git >/dev/null 2>&1

# Clone or update solana-snapshot-finder
if [[ ! -d "solana-snapshot-finder" ]]; then
  echo "  - Cloning solana-snapshot-finder..."
  git clone https://github.com/0xfnzero/solana-snapshot-finder >/dev/null 2>&1
else
  echo "  - Updating solana-snapshot-finder..."
  cd solana-snapshot-finder
  git pull >/dev/null 2>&1
  cd ..
fi

# Create venv
cd solana-snapshot-finder
if [[ ! -d "venv" ]]; then
  echo "  - Creating Python venv..."
  python3 -m venv venv
fi

echo "  - Installing Python modules..."
source ./venv/bin/activate
pip3 install --upgrade pip >/dev/null 2>&1
pip3 install -r requirements.txt >/dev/null 2>&1

echo "  ✅ Tool ready"

echo ""
echo "==> 5) Download snapshot (1-3 hours depending on network)..."
echo ""
echo "  🚀 Expected speed: 500MB - 2GB/s (optimized)"
echo ""

# Run snapshot finder
python3 snapshot-finder.py --snapshot_path "$SNAPSHOT"

echo ""
echo "  ✅ Snapshot download complete"

echo ""
echo "==> 6) Start Solana RPC node..."
systemctl start $SERVICE_NAME

# Wait for service
sleep 3

# Check status
if systemctl is-active --quiet $SERVICE_NAME; then
  echo "  ✅ Node started"
else
  echo "  ❌ Node failed to start"
  echo ""
  echo "Check logs:"
  systemctl status $SERVICE_NAME --no-pager -l
  exit 1
fi

echo ""
echo "============================================"
echo "✅ Step 3 complete: Node started successfully!"
echo "============================================"
echo ""
echo "Node status:"
echo "  - Service: running"
echo "  - Snapshot: downloaded"
echo "  - Expected sync time: 30-60 minutes"
echo ""
echo "Monitor commands:"
echo ""
echo "  Live log:"
echo "    journalctl -u $SERVICE_NAME -f"
echo "    or tail -f $LOGFILE"
echo ""
echo "  Performance:"
echo "    bash /root/performance-monitor.sh snapshot"
echo ""
echo "  Health:"
echo "    /root/get_health.sh"
echo ""
echo "  Catchup:"
echo "    /root/catchup.sh"
echo ""
echo "Key metrics:"
echo "  - Memory peak < 110GB"
echo "  - CPU usage < 70%"
echo "  - Catchup lag < 100 slots"
echo ""
echo "✅ Done! RPC node is syncing..."
echo ""
