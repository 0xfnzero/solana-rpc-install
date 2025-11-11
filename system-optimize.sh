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
# ===== Solana RPC Node Performance Optimization =====
# Optimized for: Low latency, High throughput, Memory efficiency

# ============ Network Stack Optimization ============
# TCP Buffer Sizes - EXTREME for Solana high-speed sync (512MB max)
net.ipv4.tcp_rmem=8192 524288 536870912
net.ipv4.tcp_wmem=8192 524288 536870912
net.core.rmem_max=536870912
net.core.wmem_max=536870912
net.core.rmem_default=33554432
net.core.wmem_default=33554432

# UDP Buffer Sizes - EXTREME for Solana's high-frequency gossip
net.core.netdev_max_backlog=250000
net.core.netdev_budget=150000
net.core.netdev_budget_usecs=10000

# TCP Congestion Control - BBR for better throughput
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# TCP Fast Open - Reduce connection latency
net.ipv4.tcp_fastopen=3

# TCP Optimization
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_slow_start_after_idle=0

# Connection Tracking - Handle high connection count
net.netfilter.nf_conntrack_max=2000000
net.netfilter.nf_conntrack_tcp_timeout_established=600
net.netfilter.nf_conntrack_generic_timeout=60

# IP Routing
net.ipv4.ip_forward=0
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1

# ARP Cache - Optimize for large networks
net.ipv4.neigh.default.gc_thresh1=8192
net.ipv4.neigh.default.gc_thresh2=32768
net.ipv4.neigh.default.gc_thresh3=65536
net.ipv4.neigh.default.gc_interval=30
net.ipv4.neigh.default.gc_stale_time=120

# Socket Options
net.core.somaxconn=65535
net.core.optmem_max=134217728

# ============ Kernel Optimization ============
# Scheduler - Optimize for low latency
kernel.sched_migration_cost_ns=5000000
kernel.sched_autogroup_enabled=0
kernel.timer_migration=0
kernel.hung_task_timeout_secs=0
kernel.pid_max=4194304

# Core Dumps - Disable for production
kernel.core_pattern=/dev/null
kernel.core_uses_pid=0

# Security - Maintain security while optimizing
kernel.randomize_va_space=2
kernel.kptr_restrict=1
kernel.dmesg_restrict=1

# ============ Virtual Memory Optimization ============
# Swappiness - Minimize swap usage
vm.swappiness=1
vm.vfs_cache_pressure=50

# Memory Mapping
vm.max_map_count=2000000
vm.mmap_min_addr=65536

# Dirty Page Management - Optimize for SSD
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.dirtytime_expire_seconds=43200

# Memory Statistics
vm.stat_interval=10

# Huge Pages - Enable transparent huge pages
vm.nr_hugepages=0
vm.hugetlb_shm_group=0

# OOM Killer - More aggressive memory reclaim
vm.overcommit_memory=1
vm.overcommit_ratio=50
vm.panic_on_oom=0
vm.oom_kill_allocating_task=0

# Zone Reclaim
vm.zone_reclaim_mode=0
vm.min_free_kbytes=6291456

# Page Allocation
vm.percpu_pagelist_fraction=0
vm.extfrag_threshold=100

# ============ File System Optimization ============
# File Descriptor Limits
fs.nr_open=10000000
fs.file-max=10000000

# Inotify - For monitoring file changes
fs.inotify.max_user_instances=8192
fs.inotify.max_user_watches=524288
fs.inotify.max_queued_events=32768

# AIO - Asynchronous I/O
fs.aio-max-nr=1048576

# Pipe Buffer
fs.pipe-max-size=16777216

# ============ Solana Specific ============
# UDP Performance - Critical for gossip protocol
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# Reverse Path Filtering - Allow asymmetric routing
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2

# ICMP - Rate limiting
net.ipv4.icmp_ratelimit=100
net.ipv4.icmp_msgs_per_sec=1000

# IPv6 - Keep enabled for SSH compatibility
# WARNING: Do NOT disable IPv6 as it may break SSH access on some cloud providers
# net.ipv6.conf.all.disable_ipv6=0
# net.ipv6.conf.default.disable_ipv6=0

# ===== End Performance Block =====
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
  cpupower idle-set --disable-by-latency 0 || true
fi

# Disable CPU C-States for lower latency
echo "==> 7.1) Disable CPU C-States for minimum latency..."
if [[ -f /sys/module/intel_idle/parameters/max_cstate ]]; then
  echo 0 > /sys/module/intel_idle/parameters/max_cstate || true
fi

echo "==> 8) Optimize I/O Scheduler for NVMe/SSD..."
# Detect all block devices
for dev in /sys/block/nvme* /sys/block/sd*; do
  [[ -e "$dev" ]] || continue
  devname=$(basename "$dev")

  # Check if it's an NVMe or SSD
  if [[ "$devname" =~ ^nvme ]]; then
    # NVMe devices - use none scheduler
    if [[ -f "/sys/block/$devname/queue/scheduler" ]]; then
      echo "none" > "/sys/block/$devname/queue/scheduler" 2>/dev/null || true
      echo "   - Set $devname scheduler to: none (NVMe)"
    fi
  else
    # Check if it's SSD
    rotational=$(cat "/sys/block/$devname/queue/rotational" 2>/dev/null || echo "1")
    if [[ "$rotational" == "0" ]]; then
      # SSD - use mq-deadline or none
      if [[ -f "/sys/block/$devname/queue/scheduler" ]]; then
        echo "mq-deadline" > "/sys/block/$devname/queue/scheduler" 2>/dev/null || \
        echo "deadline" > "/sys/block/$devname/queue/scheduler" 2>/dev/null || true
        echo "   - Set $devname scheduler to: mq-deadline (SSD)"
      fi
    fi
  fi

  # Optimize queue parameters
  if [[ -d "/sys/block/$devname/queue" ]]; then
    # EXTREME queue depth for high-speed snapshot downloads
    echo 4096 > "/sys/block/$devname/queue/nr_requests" 2>/dev/null || true

    # EXTREME read-ahead for large file sequential reads (32MB)
    echo 32768 > "/sys/block/$devname/queue/read_ahead_kb" 2>/dev/null || true

    # Disable add_random for better performance
    echo 0 > "/sys/block/$devname/queue/add_random" 2>/dev/null || true

    # Set rotational to 0 for SSD/NVMe
    echo 0 > "/sys/block/$devname/queue/rotational" 2>/dev/null || true

    # Optimize for latency
    echo 2 > "/sys/block/$devname/queue/rq_affinity" 2>/dev/null || true

    # Disable iostats for better performance
    echo 0 > "/sys/block/$devname/queue/iostats" 2>/dev/null || true

    echo "   - Optimized queue parameters for $devname"
  fi
done

echo "==> 9) Create persistent I/O scheduler rules..."
cat > /etc/udev/rules.d/60-solana-scheduler.rules <<'EOF'
# I/O Scheduler optimization for Solana - EXTREME PERFORMANCE
# NVMe devices - Optimized for multi-GB/s snapshot downloads
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/nr_requests}="4096"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/read_ahead_kb}="32768"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/add_random}="0"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rq_affinity}="2"
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/iostats}="0"

# SSD devices - Optimized for multi-GB/s snapshot downloads
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/nr_requests}="4096"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="32768"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/add_random}="0"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/rq_affinity}="2"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/iostats}="0"
EOF
udevadm control --reload-rules || true

echo "==> 10) Optimize Transparent Huge Pages (THP)..."
# Enable THP but use madvise mode for better control
if [[ -f /sys/kernel/mm/transparent_hugepage/enabled ]]; then
  echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
  echo advise > /sys/kernel/mm/transparent_hugepage/shmem_enabled
  echo defer+madvise > /sys/kernel/mm/transparent_hugepage/defrag
  echo 1 > /sys/kernel/mm/transparent_hugepage/khugepaged/defrag
  echo "   - THP configured to madvise mode"
fi

echo "==> 11) Disable unnecessary services for performance..."
# Disable services that can cause latency spikes
SERVICES_TO_DISABLE=(
  "snapd"
  "unattended-upgrades"
  "apt-daily.timer"
  "apt-daily-upgrade.timer"
  "motd-news.timer"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
  systemctl disable "$service" 2>/dev/null || true
  systemctl stop "$service" 2>/dev/null || true
done
echo "   - Disabled latency-inducing services"

echo "==> 12) Configure IRQ affinity for network cards..."
# Get network interface
NET_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [[ -n "$NET_IFACE" ]]; then
  # Try to set IRQ affinity for network card
  for irq in /proc/irq/*/smp_affinity; do
    echo "   - Configuring IRQ affinity: $irq"
    echo "ffffffff" > "$irq" 2>/dev/null || true
  done
fi

echo "==> 13) Set current shell ulimit -n to 10000000..."
ulimit -n 10000000 || true

echo "==> 14) Create performance monitoring script..."
cat > /usr/local/bin/solana-perf-check <<'PERFEOF'
#!/bin/bash
# Solana Performance Check Script

echo "========== System Performance Status =========="
echo "Date: $(date)"
echo ""

echo "=== CPU ==="
grep MHz /proc/cpuinfo | head -n1
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | head -n1 | xargs echo "CPU Governor:"
echo ""

echo "=== Memory ==="
free -h
echo ""

echo "=== Network Buffers ==="
sysctl net.core.rmem_max net.core.wmem_max | head -n2
echo ""

echo "=== I/O Scheduler ==="
for dev in /sys/block/nvme* /sys/block/sd*; do
  [[ -e "$dev" ]] || continue
  devname=$(basename "$dev")
  scheduler=$(cat "$dev/queue/scheduler" 2>/dev/null || echo "N/A")
  echo "$devname: $scheduler"
done
echo ""

echo "=== Solana Process ==="
if pgrep -x agave-validator >/dev/null; then
  pid=$(pgrep -x agave-validator)
  echo "PID: $pid"
  echo "Memory: $(ps -p $pid -o rss= | awk '{printf "%.2f GB\n", $1/1024/1024}')"
  echo "CPU: $(ps -p $pid -o %cpu= | awk '{print $1"%"}')"
  echo "Threads: $(ps -p $pid -o nlwp=)"
  echo "FD Count: $(ls /proc/$pid/fd 2>/dev/null | wc -l)"
else
  echo "agave-validator not running"
fi
echo ""

echo "=== Network Connections ==="
ss -s
echo ""

echo "=== Disk I/O ==="
iostat -x 1 2 | tail -n +4 | head -n10
echo ""

echo "==============================================="
PERFEOF
chmod +x /usr/local/bin/solana-perf-check

echo "==> Done. System optimized for Solana RPC node."
echo ""
echo "Performance check command: solana-perf-check"
echo "Reboot is REQUIRED for all optimizations to take effect."
