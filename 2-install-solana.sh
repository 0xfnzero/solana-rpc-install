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
# - Download Yellowstone gRPC geyser & copy optimized config
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
YELLOWSTONE_TARBALL_URL="https://github.com/rpcpool/yellowstone-grpc/releases/download/v10.0.1%2Bsolana.3.0.6/yellowstone-grpc-geyser-release24-x86_64-unknown-linux-gnu.tar.bz2"

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


echo "==> 8) 复制 validator 配置文件到 $BIN ..."
cp -f "$SCRIPT_DIR/validator.sh" "$BIN/validator.sh"
cp -f "$SCRIPT_DIR/validator-128g.sh" "$BIN/validator-128g.sh"
cp -f "$SCRIPT_DIR/validator-192g.sh" "$BIN/validator-192g.sh"
cp -f "$SCRIPT_DIR/validator-256g.sh" "$BIN/validator-256g.sh"
cp -f "$SCRIPT_DIR/validator-512g.sh" "$BIN/validator-512g.sh"
chmod +x "$BIN"/validator*.sh

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
if [[ $TOTAL_MEM_GB -lt 160 ]]; then
  echo "   ✓ 检测到 ${TOTAL_MEM_GB}GB RAM - 将使用 TIER 1 (128GB) 配置"
elif [[ $TOTAL_MEM_GB -lt 224 ]]; then
  echo "   ✓ 检测到 ${TOTAL_MEM_GB}GB RAM - 将使用 TIER 2 (192GB) 配置"
elif [[ $TOTAL_MEM_GB -lt 384 ]]; then
  echo "   ✓ 检测到 ${TOTAL_MEM_GB}GB RAM - 将使用 TIER 3 (256GB) 配置"
else
  echo "   ✓ 检测到 ${TOTAL_MEM_GB}GB RAM - 将使用 TIER 4 (512GB+) 配置"
fi


echo "==> 9) 复制 systemd 服务配置..."
cp -f "$SCRIPT_DIR/sol.service" /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload
echo "   ✓ systemd 服务配置已更新 (MemoryHigh=120G, WatchdogSec 已禁用)"

echo "==> 10) 下载 Yellowstone gRPC geyser 与配置 ..."
cd "$BIN"
wget -q "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xvjf yellowstone-grpc-geyser.tar.bz2
echo "   - 复制优化后的 yellowstone-config.json ..."
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ 已应用低延迟优化配置 (Tokio 16 threads, HTTP/2 优化, zstd 压缩)"

echo "==> 11) 复制辅助脚本到 /root ..."
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
cp -f "$SCRIPT_DIR/add-swap-128g.sh"     /root/add-swap-128g.sh
cp -f "$SCRIPT_DIR/remove-swap.sh"       /root/remove-swap.sh
chmod +x /root/redo_node.sh /root/restart_node.sh /root/get_health.sh /root/catchup.sh /root/performance-monitor.sh /root/add-swap-128g.sh /root/remove-swap.sh
echo "   ✓ 辅助脚本已复制到 /root (包含 swap 管理脚本)"

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
echo "步骤 4: 重启后回到项目目录，下载快照并启动节点"
echo "  cd $SCRIPT_DIR"
echo "  bash 3-start.sh"
echo ""
