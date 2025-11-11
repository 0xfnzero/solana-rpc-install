#!/bin/bash
set -euo pipefail

# ============================================
# 步骤2: 安装 Solana（从源码构建）
# ============================================
# 前置条件: 必须先运行 1-prepare.sh
# - Install OpenSSL 1.1
# - Install Rust toolchain
# - Build & Install Solana CLI from source
# - Create validator keypair
# - UFW enable + allow ports
# - Create validator.sh and systemd service
# - Download Yellowstone gRPC geyser & config
# - Copy helper scripts from project directory
# ============================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
ufw allow 8000:8025/tcp
ufw allow 8000:8025/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo "==> 8) 生成 /root/sol/bin/validator.sh ..."
cat > "$BIN/validator.sh" <<'EOF'
#!/bin/bash

# ============================================
# Solana RPC Node - 128GB Memory Optimized
# ============================================
# CRITICAL: Memory-constrained optimization
# Target: Stay under 110GB peak usage
# Focus: Essential RPC functionality only
# ============================================

# Environment optimizations
export RUST_LOG=warn
export RUST_BACKTRACE=1
export SOLANA_METRICS_CONFIG=""

# Detect CPU cores for optimal threading
CPU_CORES=$(nproc)
# Conservative RPC threads to save memory
RPC_THREADS=$((CPU_CORES / 3))
[[ $RPC_THREADS -lt 8 ]] && RPC_THREADS=8
[[ $RPC_THREADS -gt 16 ]] && RPC_THREADS=16

echo "Starting Solana Validator - 128GB Memory Mode"
echo "CPU Cores: $CPU_CORES | RPC Threads: $RPC_THREADS"

# Memory distribution analysis:
# - Accounts DB: ~60-70GB (largest consumer)
# - Indexes: ~10-15GB (with minimal indexing)
# - RPC cache: ~5GB
# - Ledger/Snapshot: ~10GB
# - System/Geyser/Buffers: ~15-20GB
# Total: ~100-110GB peak

exec agave-validator \
 --geyser-plugin-config /root/sol/bin/yellowstone-config.json \
 --ledger /root/sol/ledger \
 --accounts /root/sol/accounts \
 --identity /root/sol/bin/validator-keypair.json \
 --snapshots /root/sol/snapshot \
 --log /root/solana-rpc.log \
 \
 `# ============ Network Configuration ============` \
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
 --no-port-check \
 --dynamic-port-range 8000-8025 \
 --gossip-port 8001 \
 \
 `# ============ RPC Configuration (Memory-Optimized) ============` \
 --rpc-bind-address 0.0.0.0 \
 --rpc-port 8899 \
 --full-rpc-api \
 --private-rpc \
 --rpc-threads $RPC_THREADS \
 --rpc-max-multiple-accounts 50 \
 --rpc-max-request-body-size 20971520 \
 --rpc-bigtable-timeout 180 \
 --rpc-send-retry-ms 1000 \
 --rpc-send-batch-ms 5 \
 --rpc-send-batch-size 100 \
 \
 `# ============ Account Index (MINIMAL - Critical for Memory) ============` \
 `# Each index adds ~2-5GB memory usage` \
 `# Only enable program-id (essential for RPC queries)` \
 --account-index program-id \
 --account-index-include-key AddressLookupTab1e1111111111111111111111111 \
 `# Exclude high-volume token program to save memory (~3-5GB saved)` \
 --account-index-exclude-key TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA \
 \
 `# ============ Snapshot Configuration (Memory-Efficient) ============` \
 --no-incremental-snapshots \
 --maximum-full-snapshots-to-retain 2 \
 --maximum-incremental-snapshots-to-retain 2 \
 --minimal-snapshot-download-speed 10485760 \
 --use-snapshot-archives-at-startup when-newest \
 \
 `# ============ Ledger Management ============` \
 --limit-ledger-size 50000000 \
 --wal-recovery-mode skip_any_corrupted_record \
 --enable-rpc-transaction-history \
 \
 `# ============ Accounts DB (CRITICAL Memory Settings) ============` \
 `# Skip shrink to avoid memory spikes during compaction` \
 --accounts-db-skip-shrink \
 `# Conservative cache limit (2GB instead of 4GB)` \
 --accounts-db-cache-limit-mb 2048 \
 `# Aggressive shrink threshold to reduce DB bloat` \
 --account-shrink-percentage 90 \
 `# Limit accounts index memory to 4GB (reduced from 8GB)` \
 --accounts-index-memory-limit-mb 4096 \
 `# Fewer bins = less memory overhead` \
 --accounts-index-bins 4096 \
 \
 `# ============ Performance Tuning (Memory-Aware) ============` \
 --block-production-method central-scheduler \
 --health-check-slot-distance 150 \
 --banking-trace-dir-byte-limit 0 \
 --disable-banking-trace \
 --poh-verify-threads 1 \
 \
 `# ============ RPC Node Specific ============` \
 --no-voting \
 --no-wait-for-vote-to-start-leader \
 --allow-private-addr \
 \
 `# ============ Memory & Resource Management ============` \
 --bind-address 0.0.0.0 \
 --log-messages-bytes-limit 536870912
EOF
chmod +x "$BIN/validator.sh"

echo "==> 9) 写入 systemd 服务 /etc/systemd/system/${SERVICE_NAME}.service ..."
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Solana Validator
After=network.target network-online.target
Wants=network-online.target
StartLimitIntervalSec=300
StartLimitBurst=5

[Service]
Type=simple
Restart=on-failure
RestartSec=30
User=root
LimitNOFILE=1000000
LimitNPROC=1000000
LimitMEMLOCK=infinity
LimitSTACK=infinity
LimitCORE=infinity
LogRateLimitIntervalSec=0
Environment="PATH=${SOLANA_INSTALL_DIR}/bin:/usr/bin:/bin"
Environment="RUST_LOG=warn"
Environment="RUST_BACKTRACE=1"
# Prevent OOM killer from targeting this process
OOMScoreAdjust=-900
# Memory limits (adjust based on your system RAM)
MemoryHigh=110G
MemoryMax=120G
# CPU affinity and scheduling
Nice=-10
IOSchedulingClass=realtime
IOSchedulingPriority=0
# Watchdog for health monitoring
WatchdogSec=120
# Graceful shutdown timeout
TimeoutStopSec=300
KillMode=mixed
KillSignal=SIGINT
# Working directory
WorkingDirectory=/root/sol
# Startup command
ExecStart=$BIN/validator.sh
# Pre-start validation
ExecStartPre=/bin/bash -c 'test -f /root/sol/bin/validator-keypair.json'
ExecStartPre=/bin/bash -c 'test -d /root/sol/ledger'
ExecStartPre=/bin/bash -c 'test -d /root/sol/accounts'

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

echo "==> 10) 下载 Yellowstone gRPC geyser 与配置 ..."
cd "$BIN"
wget -q "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xvjf yellowstone-grpc-geyser.tar.bz2
wget -q "$YELLOWSTONE_CFG_URL" -O "$GEYSER_CFG"

echo "==> 11) 复制辅助脚本到 /root ..."
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
chmod +x /root/redo_node.sh /root/restart_node.sh /root/get_health.sh /root/catchup.sh /root/performance-monitor.sh
echo "   ✓ 辅助脚本已复制到 /root"

echo "==> 12) 配置开机自启 ..."
systemctl enable "${SERVICE_NAME}"

echo ""
echo "============================================"
echo "✅ 步骤 2 完成: Solana 安装完成!"
echo "============================================"
echo ""
echo "版本: ${SOLANA_VERSION}"
echo "安装路径: ${SOLANA_INSTALL_DIR}"
echo ""
echo "📋 下一步:"
echo ""
echo "步骤 3: 重启系统（使系统优化生效）"
echo "  reboot"
echo ""
echo "步骤 4: 重启后下载快照并启动节点"
echo "  bash /root/3-start.sh"
echo ""
