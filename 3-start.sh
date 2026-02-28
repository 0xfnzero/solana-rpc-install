#!/bin/bash
set -euo pipefail

# ============================================
# Step 3: Download snapshot and start Solana RPC node
# ============================================
# Prerequisite: Run 1-prepare.sh and 2-install-jito-validator.sh first, then reboot
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANG_CACHE_FILE="$SCRIPT_DIR/solana-rpc-lang"
# shellcheck source=lang.sh
source "$SCRIPT_DIR/lang.sh"

SERVICE_NAME=${SERVICE_NAME:-sol}
LEDGER=${LEDGER:-/root/sol/ledger}
ACCOUNTS=${ACCOUNTS:-/root/sol/accounts}
SNAPSHOT=${SNAPSHOT:-/root/sol/snapshot}
LOGFILE=/root/solana-rpc.log

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

prompt_lang

if [[ "$LANG_SCRIPT" == "zh" ]]; then
  M_HEADER="步骤 3: 下载快照并启动节点"
  M_STEP1="验证系统优化已生效..."
  M_BBR_OK="BBR 拥塞控制: 已启用"
  M_BBR_OFF="BBR 拥塞控制: 未启用 (当前: %s)"
  M_TCP_OK="TCP 缓冲区: 512MB (极限)"
  M_TCP_OFF="TCP 缓冲区: 未达到极限 (当前: %s, 期望: 536870912)"
  M_RA_OK="磁盘预读: 32MB (%s)"
  M_RA_OFF="磁盘预读: 未达到极限 (当前: %sKB, 期望: 32768KB)"
  M_STEP2="停止现有服务..."
  M_SVC_STOPPED="服务已停止"
  M_STEP3="清理旧数据（保留身份密钥）..."
  M_CLEANING="清理目录: %s"
  M_CREATING="创建目录: %s"
  M_OLD_CLEANED="旧数据已清理"
  M_STEP4="准备快照下载工具..."
  M_INSTALL_PY="安装 Python 依赖..."
  M_CLONE="克隆 solana-snapshot-finder..."
  M_UPDATE="更新 solana-snapshot-finder..."
  M_VENV="创建 Python 虚拟环境..."
  M_PIP="安装 Python 模块..."
  M_TOOL_READY="工具准备完成"
  M_STEP5="下载快照（1-3 小时，取决于网络速度）..."
  M_SPEED="预期下载速度: 500MB - 2GB/s（极限优化）"
  M_SNAP_DONE="快照下载完成"
  M_STEP6="启动 Solana RPC 节点..."
  M_NODE_OK="节点已启动"
  M_NODE_FAIL="节点启动失败"
  M_CHECK_LOGS="查看日志:"
  M_DONE_HEADER="步骤 3 完成: 节点已成功启动!"
  M_STATUS="节点状态:"
  M_RUNNING="服务: 运行中"
  M_SNAPSHOT="快照: 已下载"
  M_SYNC_TIME="预计同步时间: 30-60 分钟"
  M_MONITOR="监控命令:"
  M_LIVE_LOG="实时日志:"
  M_PERF="性能监控:"
  M_HEALTH="健康检查:"
  M_CATCHUP="追块状态:"
  M_METRICS="关键指标:"
  M_MEM="内存峰值应 < 110GB"
  M_CPU="CPU 使用率 < 70%"
  M_LAG="追块延迟 < 100 slots"
  M_FINISH="完成! RPC 节点正在同步区块链数据..."
else
  M_HEADER="Step 3: Download snapshot and start node"
  M_STEP1="Verify system optimizations..."
  M_BBR_OK="BBR congestion control: enabled"
  M_BBR_OFF="BBR congestion control: disabled (current: %s)"
  M_TCP_OK="TCP buffer: 512MB (max)"
  M_TCP_OFF="TCP buffer: not at max (current: %s, expected: 536870912)"
  M_RA_OK="Disk read-ahead: 32MB (%s)"
  M_RA_OFF="Disk read-ahead: not at max (current: %sKB, expected: 32768KB)"
  M_STEP2="Stop existing service..."
  M_SVC_STOPPED="Service stopped"
  M_STEP3="Clean old data (keep identity key)..."
  M_CLEANING="Cleaning dir: %s"
  M_CREATING="Creating dir: %s"
  M_OLD_CLEANED="Old data cleaned"
  M_STEP4="Prepare snapshot download tool..."
  M_INSTALL_PY="Installing Python deps..."
  M_CLONE="Cloning solana-snapshot-finder..."
  M_UPDATE="Updating solana-snapshot-finder..."
  M_VENV="Creating Python venv..."
  M_PIP="Installing Python modules..."
  M_TOOL_READY="Tool ready"
  M_STEP5="Download snapshot (1-3 hours depending on network)..."
  M_SPEED="Expected speed: 500MB - 2GB/s (optimized)"
  M_SNAP_DONE="Snapshot download complete"
  M_STEP6="Start Solana RPC node..."
  M_NODE_OK="Node started"
  M_NODE_FAIL="Node failed to start"
  M_CHECK_LOGS="Check logs:"
  M_DONE_HEADER="Step 3 complete: Node started successfully!"
  M_STATUS="Node status:"
  M_RUNNING="Service: running"
  M_SNAPSHOT="Snapshot: downloaded"
  M_SYNC_TIME="Expected sync time: 30-60 minutes"
  M_MONITOR="Monitor commands:"
  M_LIVE_LOG="Live log:"
  M_PERF="Performance:"
  M_HEALTH="Health:"
  M_CATCHUP="Catchup:"
  M_METRICS="Key metrics:"
  M_MEM="Memory peak < 110GB"
  M_CPU="CPU usage < 70%"
  M_LAG="Catchup lag < 100 slots"
  M_FINISH="Done! RPC node is syncing..."
fi

echo "============================================"
echo "$M_HEADER"
echo "============================================"
echo ""

# Verify system optimizations
echo "==> 1) $M_STEP1"
echo ""

# BBR
bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [[ "$bbr" == "bbr" ]]; then
  echo "  ✅ $M_BBR_OK"
else
  printf "  ⚠️  $M_BBR_OFF\n" "$bbr"
fi

# TCP buffer
rmem=$(sysctl -n net.core.rmem_max 2>/dev/null || echo "0")
if [[ "$rmem" == "536870912" ]]; then
  echo "  ✅ $M_TCP_OK"
else
  printf "  ⚠️  $M_TCP_OFF\n" "$rmem"
fi

# Disk read-ahead
for dev in /sys/block/nvme* /sys/block/sd*; do
  [[ -e "$dev" ]] || continue
  devname=$(basename "$dev")
  ra=$(cat "$dev/queue/read_ahead_kb" 2>/dev/null || echo "0")
  if [[ "$ra" == "32768" ]]; then
    printf "  ✅ $M_RA_OK\n" "$devname"
  else
    printf "  ⚠️  $M_RA_OFF\n" "$ra"
  fi
  break
done

echo ""
echo "==> 2) $M_STEP2"
systemctl stop $SERVICE_NAME 2>/dev/null || true
sleep 2
echo "  ✅ $M_SVC_STOPPED"

echo ""
echo "==> 3) $M_STEP3"
rm -f "$LOGFILE" || true

# Clean dirs
dirs=("$LEDGER" "$ACCOUNTS" "$SNAPSHOT")
for dir in "${dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    printf "  - $M_CLEANING\n" "$dir"
    rm -rf "$dir"/* "$dir"/.[!.]* "$dir"/..?* || true
  else
    printf "  - $M_CREATING\n" "$dir"
    mkdir -p "$dir"
  fi
done
echo "  ✅ $M_OLD_CLEANED"

echo ""
echo "==> 4) $M_STEP4"
cd /root

# Install deps
echo "  - $M_INSTALL_PY"
apt-get update -qq
apt-get install -y python3-venv git >/dev/null 2>&1

# Clone or update solana-snapshot-finder
if [[ ! -d "solana-snapshot-finder" ]]; then
  echo "  - $M_CLONE"
  git clone https://github.com/0xfnzero/solana-snapshot-finder >/dev/null 2>&1
else
  echo "  - $M_UPDATE"
  cd solana-snapshot-finder
  git pull >/dev/null 2>&1
  cd ..
fi

# Create venv
cd solana-snapshot-finder
if [[ ! -d "venv" ]]; then
  echo "  - $M_VENV"
  python3 -m venv venv
fi

echo "  - $M_PIP"
source ./venv/bin/activate
pip3 install --upgrade pip >/dev/null 2>&1
pip3 install -r requirements.txt >/dev/null 2>&1

echo "  ✅ $M_TOOL_READY"

echo ""
echo "==> 5) $M_STEP5"
echo ""
echo "  🚀 $M_SPEED"
echo ""

# Run snapshot finder
python3 snapshot-finder.py --snapshot_path "$SNAPSHOT"

echo ""
echo "  ✅ $M_SNAP_DONE"

echo ""
echo "==> 6) $M_STEP6"
systemctl start $SERVICE_NAME

# Wait for service
sleep 3

# Check status
if systemctl is-active --quiet $SERVICE_NAME; then
  echo "  ✅ $M_NODE_OK"
else
  echo "  ❌ $M_NODE_FAIL"
  echo ""
  echo "$M_CHECK_LOGS"
  systemctl status $SERVICE_NAME --no-pager -l
  exit 1
fi

echo ""
echo "============================================"
echo "✅ $M_DONE_HEADER"
echo "============================================"
echo ""
echo "$M_STATUS"
echo "  - $M_RUNNING"
echo "  - $M_SNAPSHOT"
echo "  - $M_SYNC_TIME"
echo ""
echo "$M_MONITOR"
echo ""
echo "  $M_LIVE_LOG"
echo "    journalctl -u $SERVICE_NAME -f"
echo "    or tail -f $LOGFILE"
echo ""
echo "  $M_PERF"
echo "    bash /root/performance-monitor.sh snapshot"
echo ""
echo "  $M_HEALTH"
echo "    /root/get_health.sh"
echo ""
echo "  $M_CATCHUP"
echo "    /root/catchup.sh"
echo ""
echo "$M_METRICS"
echo "  - $M_MEM"
echo "  - $M_CPU"
echo "  - $M_LAG"
echo ""
echo "✅ $M_FINISH"
echo ""
