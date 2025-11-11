#!/bin/bash
set -euo pipefail

# =============================
# Solana Install (从源码构建版本)
# - 从源码编译安装 Solana (不再使用预编译二进制)
# - Install OpenSSL 1.1
# - Install Rust toolchain
# - Create /root/sol/* directories
# - Auto-detect data disks (exclude system disk), prefer largest candidates
# - Mount priority: /root/sol/accounts -> /root/sol/ledger -> /root/sol/snapshot
#   * fstab uses defaults per tutorial (no extra options)
# - Build & Install Solana CLI from source
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
SOLANA_INSTALL_DIR="/usr/local/solana"

# Yellowstone artifacts (as vars)
YELLOWSTONE_TARBALL_URL="https://github.com/rpcpool/yellowstone-grpc/releases/download/v8.0.0%2Bsolana.2.3.6/yellowstone-grpc-geyser-release22-x86_64-unknown-linux-gnu.tar.bz2"
YELLOWSTONE_CFG_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.8/yellowstone-config.json"

# Snapshot/ops scripts
REDO_NODE_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.8/redo_node.sh"
RESTART_NODE_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.8/restart_node.sh"
GET_HEALTH_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.8/get_health.sh"
CATCHUP_URL="https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.8/catchup.sh"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "==> 节点安装（从源码构建）开始..."

# =============================
# Step 0: Verify Solana version first
# =============================
echo "==> 0) 验证 Solana 版本 ..."

# Interactive version selection and validation
while true; do
  read -p "请输入 Solana 版本号 (例如 v3.0.10, v3.0.9): " SOLANA_VERSION

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[错误] 版本号格式不正确，应为 vX.Y.Z 格式 (例如 v3.0.10)"
    read -p "是否重新输入版本号？(y/n): " retry
    [[ "$retry" != "y" && "$retry" != "Y" ]] && exit 1
    continue
  fi

  # Construct source download URL (for building from source)
  SOLANA_SOURCE_URL="https://github.com/anza-xyz/agave/archive/refs/tags/${SOLANA_VERSION}.tar.gz"

  echo "正在验证版本 ${SOLANA_VERSION} 源码..."

  # Try to verify the source tarball exists
  if wget --spider "$SOLANA_SOURCE_URL" 2>/dev/null; then
    echo "版本 ${SOLANA_VERSION} 源码验证成功，继续安装流程..."
    break
  else
    echo "[错误] 版本 ${SOLANA_VERSION} 源码不存在或下载地址不可用"
    echo "请访问 https://github.com/anza-xyz/agave/releases 查看可用版本"
    read -p "是否重新输入版本号？(y/n): " retry
    [[ "$retry" != "y" && "$retry" != "Y" ]] && exit 1
  fi
done

echo "==> 版本验证完成，开始系统配置..."
apt update -y
apt install -y wget curl bzip2 ufw build-essential pkg-config libssl-dev libudev-dev \
               zlib1g-dev llvm clang cmake make libprotobuf-dev protobuf-compiler \
               libclang-dev git || true

echo "==> 1) 安装 OpenSSL 1.1 ..."
wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb -O /tmp/libssl1.1.deb
dpkg -i /tmp/libssl1.1.deb || true

echo "==> 2) 安装 Rust 工具链 ..."
if ! command -v rustc &> /dev/null; then
  echo "   - 未检测到 Rust，开始安装..."
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "   - Rust 安装完成"
else
  echo "   - Rust 已安装: $(rustc --version)"
fi

# Ensure Rust environment is loaded
if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi

# Update Rust to latest stable
echo "   - 更新 Rust 到最新稳定版..."
rustup update stable
rustup default stable
rustup component add rustfmt

echo "==> 3) 创建目录 ..."
mkdir -p "$LEDGER" "$ACCOUNTS" "$SNAPSHOT" "$BIN" "$TOOLS"

# ---------- 自动判盘并挂载（优先：accounts -> ledger -> snapshot） ----------
echo "==> 4) 自动检测磁盘并安全挂载（优先 accounts）..."
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

echo "==> 5) 从源码构建 Solana CLI (版本 ${SOLANA_VERSION}) ..."

# Download source code
BUILD_DIR="/tmp/solana-build"
SOURCE_DIR="${BUILD_DIR}/agave-${SOLANA_VERSION#v}"
mkdir -p "$BUILD_DIR"

# Clean old source if exists
if [[ -d "$SOURCE_DIR" ]]; then
  echo "   - 清理旧的源码目录..."
  rm -rf "$SOURCE_DIR"
fi

cd "$BUILD_DIR"
echo "   - 下载源码 (${SOLANA_SOURCE_URL})..."
wget -q --show-progress -O "agave-${SOLANA_VERSION}.tar.gz" "$SOLANA_SOURCE_URL"

if [[ ! -f "agave-${SOLANA_VERSION}.tar.gz" ]]; then
  echo "[错误] 下载失败"
  exit 1
fi

echo "   - 解压源码..."
tar -xzf "agave-${SOLANA_VERSION}.tar.gz"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "[错误] 解压失败，目录不存在: $SOURCE_DIR"
  exit 1
fi

# Build Solana
echo "   - 开始编译 Solana (这可能需要 20-40 分钟)..."
cd "$SOURCE_DIR"

# Set build options
CPU_CORES=$(nproc)
export CARGO_BUILD_JOBS=$CPU_CORES
echo "   - 使用 ${CPU_CORES} 个 CPU 核心进行并行编译"

# Display start time
START_TIME=$(date +%s)
echo "   - 编译开始时间: $(date '+%Y-%m-%d %H:%M:%S')"

# Remove old installation directory if exists
if [[ -d "$SOLANA_INSTALL_DIR" ]]; then
  echo "   - 删除旧的安装目录..."
  rm -rf "$SOLANA_INSTALL_DIR"
fi
mkdir -p "$SOLANA_INSTALL_DIR"

# Execute build script
echo "   - 执行编译脚本..."
if ! ./scripts/cargo-install-all.sh "$SOLANA_INSTALL_DIR"; then
  echo "[错误] 编译失败！请检查错误信息"
  exit 1
fi

# Calculate build time
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo "   - 编译完成！耗时: ${MINUTES}分${SECONDS}秒"

# Cleanup build directory
echo "   - 清理临时编译文件..."
cd /root
rm -rf "$BUILD_DIR"

# Configure PATH persistently
export PATH="$SOLANA_INSTALL_DIR/bin:$PATH"

# Add to bashrc if not already present
if ! grep -q 'solana/bin' /root/.bashrc 2>/dev/null; then
  echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" >> /root/.bashrc
fi

# Add to system-wide profile
echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" > /etc/profile.d/solana.sh

# Verify installation
if ! command -v solana >/dev/null 2>&1; then
  echo "[错误] Solana 安装失败，命令不可用"
  exit 1
fi

echo "   - Solana ${SOLANA_VERSION} 安装成功"
solana --version

echo "==> 6) 生成 Validator Keypair ..."
[[ -f "$KEYPAIR" ]] || solana-keygen new -o "$KEYPAIR"

echo "==> 7) 配置 UFW 防火墙 ..."
ufw --force enable
ufw allow 22
ufw allow 8000:8020/tcp
ufw allow 8000:8020/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo "==> 8) 生成 /root/sol/bin/validator.sh ..."
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

echo "==> 9) 写入 systemd 服务 /etc/systemd/system/${SERVICE_NAME}.service ..."
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
Environment="PATH=${SOLANA_INSTALL_DIR}/bin:/usr/bin:/bin"
ExecStart=$BIN/validator.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

echo "==> 10) 下载 Yellowstone gRPC geyser 与配置 ..."
cd "$BIN"
wget -q "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xvjf yellowstone-grpc-geyser.tar.bz2
wget -q "$YELLOWSTONE_CFG_URL" -O "$GEYSER_CFG"

echo "==> 11) 下载 redo_node / restart_node / get_health / catchup ..."
cd /root
wget -q "$REDO_NODE_URL"    -O /root/redo_node.sh
wget -q "$RESTART_NODE_URL" -O /root/restart_node.sh
wget -q "$GET_HEALTH_URL"   -O /root/get_health.sh
wget -q "$CATCHUP_URL"      -O /root/catchup.sh
chmod +x /root/*.sh

echo "==> 12) 停止 systemd 服务（避免冲突），执行 redo_node.sh ..."
systemctl stop "${SERVICE_NAME}" || true
/root/redo_node.sh

echo "==> 13) 开机自启 ..."
systemctl enable "${SERVICE_NAME}"

echo "==> 安装完成。"
echo "日志： tail -f $LOGFILE"
echo "健康检查： /root/get_health.sh"
echo "追块： /root/catchup.sh"
echo "重启： /root/restart_node.sh  或  systemctl restart ${SERVICE_NAME}"
