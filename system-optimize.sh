#!/bin/bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

echo "==> 1) Install CPU and NIC tools..."
apt-get update -y
apt-get install -y ethtool linux-tools-common
apt-get install -y "linux-tools-$(uname -r)" || true

echo "==> 2) Disable swap now and at boot..."
swapoff -a || true
cp -a /etc/fstab "/etc/fstab.bak.$(date +%s)"
sed -i 's/^\(\s*[^#].*\s\+swap\s\+.*\)$/# \1/g' /etc/fstab

echo "==> 3) Apply bounded Agave sysctl settings..."
SYSCTL_CFG=/etc/sysctl.d/99-solana-tune.conf
# Remove the exact legacy block previously appended by tcp-optimize.sh so it
# cannot override this managed file when sysctl --system is run.
if [[ -f /etc/sysctl.conf ]]; then
  sed -i '/^# gRPC 极限低延迟优化$/,/^net.ipv4.tcp_max_syn_backlog = 65535$/d' \
    /etc/sysctl.conf
fi
cat >"$SYSCTL_CFG" <<'EOF'
# Anza validator baseline
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
vm.max_map_count = 1000000
fs.nr_open = 1000000

# Absorb short packet bursts without assigning every socket a 128MB default.
net.core.netdev_max_backlog = 50000

# Bound dirty memory on 128GB/192GB hosts to avoid large periodic writeback.
vm.dirty_background_bytes = 536870912
vm.dirty_bytes = 2147483648
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 500
EOF
sysctl --system >/dev/null

echo "==> 4) Configure file descriptor limits..."
mkdir -p /etc/systemd/system.conf.d
cat >/etc/systemd/system.conf.d/99-solana-limits.conf <<'EOF'
[Manager]
DefaultLimitNOFILE=1000000
DefaultLimitMEMLOCK=2000000000
EOF

mkdir -p /etc/security/limits.d
cat >/etc/security/limits.d/99-solana-limits.conf <<'EOF'
* - nofile 1000000
* - memlock 2000000
EOF

echo "==> 5) Install persistent CPU, THP, and NIC ring tuning..."
cat >/usr/local/sbin/solana-host-performance.sh <<'EOF'
#!/bin/bash
set -u

for governor in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  [[ -w "$governor" ]] && echo performance >"$governor" || true
done
for epp in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
  [[ -w "$epp" ]] && echo performance >"$epp" || true
done
[[ -w /sys/devices/system/cpu/cpufreq/boost ]] && \
  echo 1 >/sys/devices/system/cpu/cpufreq/boost || true
[[ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]] && \
  echo 0 >/sys/devices/system/cpu/intel_pstate/no_turbo || true

for thp in /sys/kernel/mm/transparent_hugepage/enabled \
           /sys/kernel/mm/transparent_hugepage/defrag; do
  [[ -w "$thp" ]] && echo never >"$thp" || true
done

command -v ethtool >/dev/null 2>&1 || exit 0
default_iface=$(ip route show default 2>/dev/null | awk 'NR == 1 {print $5}')
[[ -n "$default_iface" ]] || exit 0

nics=("$default_iface")
if [[ -r "/sys/class/net/$default_iface/bonding/slaves" ]]; then
  read -r -a nics <"/sys/class/net/$default_iface/bonding/slaves"
fi

for nic in "${nics[@]}"; do
  ring_info=$(ethtool -g "$nic" 2>/dev/null || true)
  [[ -n "$ring_info" ]] || continue
  max_rx=$(awk '/Pre-set maximums:/ {section=1; next} /Current hardware settings:/ {section=0} section && $1 == "RX:" {print $2; exit}' <<<"$ring_info")
  max_tx=$(awk '/Pre-set maximums:/ {section=1; next} /Current hardware settings:/ {section=0} section && $1 == "TX:" {print $2; exit}' <<<"$ring_info")
  ring_args=()
  [[ "$max_rx" =~ ^[0-9]+$ ]] && ((max_rx > 0)) && ring_args+=(rx "$max_rx")
  [[ "$max_tx" =~ ^[0-9]+$ ]] && ((max_tx > 0)) && ring_args+=(tx "$max_tx")
  ((${#ring_args[@]} > 0)) && ethtool -G "$nic" "${ring_args[@]}" 2>/dev/null || true
done
EOF
chmod 0755 /usr/local/sbin/solana-host-performance.sh

cat >/etc/systemd/system/solana-host-performance.service <<'EOF'
[Unit]
Description=Apply conservative Solana host performance settings
After=network-online.target
Wants=network-online.target
Before=sol.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/solana-host-performance.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify /etc/systemd/system/solana-host-performance.service
fi
systemctl daemon-reload
systemctl enable --now solana-host-performance.service

echo "==> Done. No SMT, C-state, IRQ affinity, kernel, or GRUB changes were made."
