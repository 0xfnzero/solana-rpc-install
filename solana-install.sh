#!/bin/bash
set -euo pipefail

# =============================
# Solana Install (exact tutorial + auto mount priority: accounts -> ledger -> snapshot)
# - Install OpenSSL 1.1
# - Create /root/sol/* directories
# - Auto-detect data disks (exclude system disk), prefer largest candidates
# - Mount priority: /root/sol/accounts -> /root/sol/ledger -> /root/sol/snapshot
#   * fstab uses defaults per tutorial (no extra options)
# - Install Solana CLI v2.3.6 & PATH
# - Create validator keypair
# - UFW enable + allow ports
# - Create validator.sh and systemd service
# - Download Yellowstone gRPC geyser & config
# - Download redo_node.sh / restart_node.sh / get_health.sh / catchup.sh
# - Run redo_node.sh
# =============================

BASE=${BASE:-/root/sol}
LEDGER="$BASE/ledger"
ACCOUNTS="$BASE/accounts"
SNAPSHOT="$BASE/snapshot"
BIN="$BASE/bin"
TOOLS="$BASE/tools"
KEYPAIR="$BIN/validator-keypair.json"
LOGFILE=/root/solana-rpc.log
GEYSER_CFG="$BIN/yellowstone-config.json"
SERVICE_NAME=${SERVICE_NAME:-sol}

# Yellowstone artifacts (as vars)
YELLOWSTONE_TARBALL_URL="https://github.com/rpcpool/yellowstone-grpc/releases/download/v8.0.0%2Bsolana.2.3.6/yellowstone-grpc-geyser-release22-x86_64-unknown-linux-gnu.tar.bz2"
YELLOWSTONE_CFG_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/yellowstone-config.json"

# Snapshot/ops scripts
REDO_NODE_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/redo_node.sh"
RESTART_NODE_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/restart_node.sh"
GET_HEALTH_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/get_health.sh"
CATCHUP_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/catchup.sh"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "==> 节点安装（按教程）开始..."
apt update -y
apt install -y wget curl bzip2 ufw || true

echo "==> 1) 安装 OpenSSL 1.1 ..."
wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb -O /tmp/libssl1.1.deb
dpkg -i /tmp/libssl1.1.deb || true

echo "==> 2) 创建目录 ..."
mkdir -p "$LEDGER" "$ACCOUNTS" "$SNAPSHOT" "$BIN" "$TOOLS"

# ---------- 自动判盘并挂载（优先：accounts -> ledger -> snapshot） ----------
echo "==> 3) 自动检测磁盘并安全挂载（优先 accounts）..."
ROOT_SRC=$(findmnt -no SOURCE / || true)
ROOT_DISK=""
if [[ -n "${ROOT_SRC:-}" ]]; then
  ROOT_DISK=$(lsblk -no pkname "$ROOT_SRC" 2>/dev/null || true)
  [[ -n "$ROOT_DISK" ]] && ROOT_DISK="/dev/$ROOT_DISK"
fi
MAP_DISKS=($(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'))

is_mounted_dev() { findmnt -no TARGET "$1" &>/dev/null; }
has_fs() { blkid -o value -s TYPE "$1" &>/dev/null; }

mount_one() {
  local dev="$1"; local target="$2"
  if is_mounted_dev "$dev"; then
    echo "   - 已挂载：$dev -> $(findmnt -no TARGET "$dev")，跳过"; return 0
  fi
  if ! has_fs "$dev"; then
    echo "   - 为 $dev 创建 ext4 文件系统（首次使用）"; mkfs.ext4 -F "$dev"
  fi
  mkdir -p "$target"
  # 教程要求 /etc/fstab 使用 defaults（不附加额外选项）
  mount -o defaults "$dev" "$target"
  if ! grep -qE "^[^ ]+ +$target " /etc/fstab; then
    echo "$dev $target ext4 defaults 0 0" >> /etc/fstab
  fi
  echo "   - 挂载完成：$dev -> $target"
}

# 收集候选设备（排除系统盘；对有分区的磁盘选择最大未挂载分区）
CANDIDATES=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"
  [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]] && continue
  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))
  if ((${#parts[@]}==0)); then
    is_mounted_dev "$disk" || CANDIDATES+=("$disk")
  else
    best=""; best_size=0
    for p in "${parts[@]}"; do
      part="/dev/$p"; is_mounted_dev "$part" && continue
      size=$(lsblk -bno SIZE "$part")
      (( size > best_size )) && { best="$part"; best_size=$size; }
    done
    [[ -n "$best" ]] && CANDIDATES+=("$best")
  fi
done

echo "==> 候选数据设备：${CANDIDATES[*]:-"<无>"}"
ASSIGNED_ACC=""; ASSIGNED_LED=""; ASSIGNED_SNAP=""
((${#CANDIDATES[@]}>0)) && ASSIGNED_ACC="${CANDIDATES[0]}"
((${#CANDIDATES[@]}>1)) && ASSIGNED_LED="${CANDIDATES[1]}"
((${#CANDIDATES[@]}>2)) && ASSIGNED_SNAP="${CANDIDATES[2]}"

[[ -n "$ASSIGNED_ACC"  ]] && mount_one "$ASSIGNED_ACC"  "$ACCOUNTS"  || echo "   - accounts 使用系统盘：$ACCOUNTS"
[[ -n "$ASSIGNED_LED"  ]] && mount_one "$ASSIGNED_LED"  "$LEDGER"    || echo "   - ledger  使用系统盘：$LEDGER"
[[ -n "$ASSIGNED_SNAP" ]] && mount_one "$ASSIGNED_SNAP" "$SNAPSHOT"  || echo "   - snapshot使用系统盘：$SNAPSHOT"

echo "==> 4) 安装 Solana CLI v2.3.6 ..."
if ! command -v solana >/dev/null 2>&1; then
  sh -c "$(curl -sSfL https://release.anza.xyz/v2.3.6/install)"
fi
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
if ! grep -q 'solana/install/active_release/bin' /root/.bashrc 2>/dev/null; then
  echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> /root/.bashrc
fi
echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >/etc/profile.d/solana.sh

echo "==> 5) 生成 Validator Keypair ..."
[[ -f "$KEYPAIR" ]] || solana-keygen new -o "$KEYPAIR"

echo "==> 6) 配置 UFW 防火墙 ..."
ufw --force enable
ufw allow 22
ufw allow 8000:8020/tcp
ufw allow 8000:8020/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo "==> 7) 生成 /root/sol/bin/validator.sh ..."
cat > "$BIN/validator.sh" <<'EOF'
#!/bin/bash

RUST_LOG=warn agave-validator \
 --geyser-plugin-config /root/sol/bin/yellowstone-config.json \
 --ledger /root/sol/ledger \
 --accounts /root/sol/accounts \
 --identity /root/sol/bin/validator-keypair.json \
 --snapshots /root/sol/snapshot \
 --log /root/solana-rpc.log \
 --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
 --known-validator Certusm1sa411sMpV9FPqU5dXAYhmmhygvxJ23S6hJ24 \
 --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
 --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
 --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
 --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
 --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
 --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
 --only-known-rpc \
 --disable-banking-trace \
 --rpc-bind-address 0.0.0.0 \
 --rpc-port 8899 \
 --full-rpc-api \
 --private-rpc \
 --no-voting \
 --dynamic-port-range 8000-8020 \
 --wal-recovery-mode skip_any_corrupted_record \
 --limit-ledger-size 60000000 \
 --no-port-check \
 --no-snapshot-fetch \
 --account-index-include-key AddressLookupTab1e1111111111111111111111111 \
 --account-index program-id \
 --rpc-bigtable-timeout 300 \
 --full-snapshot-interval-slots 1577880000 \
 --incremental-snapshot-interval-slots 788940000 \
 --incremental-snapshot-archive-path /root/sol/snapshot
EOF
chmod +x "$BIN/validator.sh"

echo "==> 8) 写入 systemd 服务 /etc/systemd/system/${SERVICE_NAME}.service ..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Solana Validator
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
LimitNOFILE=1000000
LogRateLimitIntervalSec=0
Environment="PATH=/bin:/usr/bin:/root/.local/share/solana/install/active_release/bin"
ExecStart=$BIN/validator.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

echo "==> 9) 下载 Yellowstone gRPC geyser 与配置 ..."
cd "$BIN"
wget -q "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xvjf yellowstone-grpc-geyser.tar.bz2
wget -q "$YELLOWSTONE_CFG_URL" -O "$GEYSER_CFG"

echo "==> 10) 下载 redo_node / restart_node / get_health / catchup ..."
cd /root
wget -q "$REDO_NODE_URL"    -O /root/redo_node.sh
wget -q "$RESTART_NODE_URL" -O /root/restart_node.sh
wget -q "$GET_HEALTH_URL"   -O /root/get_health.sh
wget -q "$CATCHUP_URL"      -O /root/catchup.sh
chmod +x /root/*.sh

echo "==> 11) 停止 systemd 服务（避免冲突），执行 redo_node.sh ..."
systemctl stop "${SERVICE_NAME}" || true
/root/redo_node.sh

echo "==> 12) 开机自启 ..."
systemctl enable "${SERVICE_NAME}"

echo "==> 安装完成。"
echo "日志： tail -f $LOGFILE"
echo "健康检查： /root/get_health.sh"
echo "追块： /root/catchup.sh"
echo "重启： /root/restart_node.sh  或  systemctl restart ${SERVICE_NAME}"
