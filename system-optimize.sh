#!/bin/bash
set -euo pipefail

# =============================
# System Optimize (exact tutorial)
# - Disable swap (comment fstab + swapoff -a)
# - sysctl.conf: westwood + vm/* + fs.nr_open...
# - /etc/systemd/system.conf: DefaultLimitNOFILE=1000000
# - /etc/security/limits.conf: * - nofile 1000000
# - CPU governor=performance
# - Apply changes (sysctl -p, daemon-reload, ulimit -n)
# =============================

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

echo "==> 1) Install tools (linux-tools for cpupower, ufw optional)..."
apt update -y
apt install -y linux-tools-common "linux-tools-$(uname -r)" || true

echo "==> 2) Disable swap now and at boot (comment swap lines in /etc/fstab)..."
swapoff -a || true
cp -a /etc/fstab /etc/fstab.bak.$(date +%s)
# Comment every active swap line
sed -i 's/^\(\s*[^#].*\s\+swap\s\+.*\)$/# \1/g' /etc/fstab

echo "==> 3) sysctl 低时延网络 + Kernel/VM/FD 调优..."
SYSCTL_CFG=/etc/sysctl.d/99-solana-tune.conf
cat > "$SYSCTL_CFG" <<'EOF'
# ===== Added by system-optimize.sh (tutorial exact) =====
# TCP Buffer Sizes (10k min, 87.38k default, 12M max)
net.ipv4.tcp_rmem=10240 87380 12582912
net.ipv4.tcp_wmem=10240 87380 12582912

# TCP Optimization
net.ipv4.tcp_congestion_control=westwood
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1

# Kernel Optimization
kernel.timer_migration=0
kernel.hung_task_timeout_secs=30
kernel.pid_max=49152

# Virtual Memory Tuning
vm.swappiness=30
vm.max_map_count=2000000
vm.stat_interval=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
vm.min_free_kbytes=3000000
vm.dirty_expire_centisecs=36000
vm.dirty_writeback_centisecs=3000
vm.dirtytime_expire_seconds=43200

# Solana Specific Tuning
net.core.rmem_max=134217728
net.core.rmem_default=134217728
net.core.wmem_max=134217728
net.core.wmem_default=134217728

# Increase number of allowed open file descriptors
fs.nr_open = 1000000
# ===== End tutorial block =====
EOF

echo "==> 4) Apply sysctl -p ..."
sysctl --system >/dev/null

echo "==> 5) 设置 nofile（系统+PAM 两端兜底）..."
# systemd 全局（不改原文件，放入 drop-in）
mkdir -p /etc/systemd/system.conf.d
cat >/etc/systemd/system.conf.d/99-solana-nofile.conf <<'EOF'
[Manager]
DefaultLimitNOFILE=1000000
EOF
systemctl daemon-reload

echo "==> 6) limits（nofile）..."
LIMITS_FILE=/etc/security/limits.d/99-solana-nofile.conf
cat > "$LIMITS_FILE" <<'EOF'
# From tutorial: Increase process file descriptor count limit
* - nofile 1000000
EOF

echo "==> 7) CPU governor -> performance (tutorial)..."
if command -v cpupower >/dev/null 2>&1; then
  cpupower frequency-set --governor performance || true
fi

echo "==> 8) Set current shell ulimit -n to 1000000 (tutorial immediate effect)..."
ulimit -n 1000000 || true

echo "==> Done. Reboot is recommended so all limits apply to future sessions."
