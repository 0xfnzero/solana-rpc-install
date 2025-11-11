#!/bin/bash
set -euo pipefail

# ============================================
# 步骤3: 下载快照 + 启动 Solana RPC 节点
# ============================================
# 前置条件: 必须先运行 1-prepare.sh 和 2-install-solana.sh，并重启系统
# ============================================

SERVICE_NAME=${SERVICE_NAME:-sol}
LEDGER=${LEDGER:-/root/sol/ledger}
ACCOUNTS=${ACCOUNTS:-/root/sol/accounts}
SNAPSHOT=${SNAPSHOT:-/root/sol/snapshot}
LOGFILE=/root/solana-rpc.log

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "============================================"
echo "步骤 3: 下载快照并启动节点"
echo "============================================"
echo ""

# 验证优化已生效
echo "==> 1) 验证系统优化已生效..."
echo ""

# 验证 BBR
bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
if [[ "$bbr" == "bbr" ]]; then
  echo "  ✅ BBR 拥塞控制: 已启用"
else
  echo "  ⚠️  BBR 拥塞控制: 未启用 (当前: $bbr)"
fi

# 验证 TCP 缓冲区
rmem=$(sysctl -n net.core.rmem_max 2>/dev/null || echo "0")
if [[ "$rmem" == "536870912" ]]; then
  echo "  ✅ TCP 缓冲区: 512MB (极限)"
else
  echo "  ⚠️  TCP 缓冲区: 未达到极限 (当前: $rmem, 期望: 536870912)"
fi

# 验证磁盘预读
for dev in /sys/block/nvme* /sys/block/sd*; do
  [[ -e "$dev" ]] || continue
  devname=$(basename "$dev")
  ra=$(cat "$dev/queue/read_ahead_kb" 2>/dev/null || echo "0")
  if [[ "$ra" == "32768" ]]; then
    echo "  ✅ 磁盘预读: 32MB ($devname)"
  else
    echo "  ⚠️  磁盘预读: 未达到极限 (当前: ${ra}KB, 期望: 32768KB)"
  fi
  break
done

echo ""
echo "==> 2) 停止现有服务..."
systemctl stop $SERVICE_NAME 2>/dev/null || true
sleep 2
echo "  ✅ 服务已停止"

echo ""
echo "==> 3) 清理旧数据（保留身份密钥）..."
rm -f "$LOGFILE" || true

# 清理目录
dirs=("$LEDGER" "$ACCOUNTS" "$SNAPSHOT")
for dir in "${dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    echo "  - 清理目录: $dir"
    rm -rf "$dir"/* "$dir"/.[!.]* "$dir"/..?* || true
  else
    echo "  - 创建目录: $dir"
    mkdir -p "$dir"
  fi
done
echo "  ✅ 旧数据已清理"

echo ""
echo "==> 4) 准备快照下载工具..."
cd /root

# 安装依赖
echo "  - 安装 Python 依赖..."
apt-get update -qq
apt-get install -y python3-venv git >/dev/null 2>&1

# 克隆或更新 solana-snapshot-finder
if [[ ! -d "solana-snapshot-finder" ]]; then
  echo "  - 克隆 solana-snapshot-finder 仓库..."
  git clone https://github.com/0xfnzero/solana-snapshot-finder >/dev/null 2>&1
else
  echo "  - 更新 solana-snapshot-finder 仓库..."
  cd solana-snapshot-finder
  git pull >/dev/null 2>&1
  cd ..
fi

# 创建虚拟环境
cd solana-snapshot-finder
if [[ ! -d "venv" ]]; then
  echo "  - 创建 Python 虚拟环境..."
  python3 -m venv venv
fi

echo "  - 安装 Python 模块..."
source ./venv/bin/activate
pip3 install --upgrade pip >/dev/null 2>&1
pip3 install -r requirements.txt >/dev/null 2>&1

echo "  ✅ 工具准备完成"

echo ""
echo "==> 5) 下载快照（1-3 小时，取决于网络速度）..."
echo ""
echo "  🚀 预期下载速度: 500MB - 2GB/s（极限优化）"
echo ""

# 运行 snapshot finder
python3 snapshot-finder.py --snapshot_path "$SNAPSHOT"

echo ""
echo "  ✅ 快照下载完成"

echo ""
echo "==> 6) 启动 Solana RPC 节点..."
systemctl start $SERVICE_NAME

# 等待服务启动
sleep 3

# 检查状态
if systemctl is-active --quiet $SERVICE_NAME; then
  echo "  ✅ 节点已启动"
else
  echo "  ❌ 节点启动失败"
  echo ""
  echo "查看日志:"
  systemctl status $SERVICE_NAME --no-pager -l
  exit 1
fi

echo ""
echo "============================================"
echo "✅ 步骤 3 完成: 节点已成功启动!"
echo "============================================"
echo ""
echo "📊 节点状态:"
echo "  - 服务: 运行中"
echo "  - 快照: 已下载"
echo "  - 预计同步时间: 30-60 分钟"
echo ""
echo "📋 监控命令:"
echo ""
echo "  实时日志:"
echo "    journalctl -u $SERVICE_NAME -f"
echo "    或 tail -f $LOGFILE"
echo ""
echo "  性能监控:"
echo "    bash /root/performance-monitor.sh snapshot"
echo ""
echo "  健康检查:"
echo "    /root/get_health.sh"
echo ""
echo "  追块状态:"
echo "    /root/catchup.sh"
echo ""
echo "🎯 关键指标:"
echo "  - 内存峰值应 < 110GB"
echo "  - CPU 使用率 < 70%"
echo "  - 追块延迟 < 100 slots"
echo ""
echo "✅ 完成! RPC 节点正在同步区块链数据..."
echo ""
