#!/bin/bash
set -euo pipefail

# ============================================
# 步骤2: 从源码编译安装 Jito Solana Validator
# ============================================
# 用途：编译并安装完整的 Jito Solana，包含 validator 二进制文件
# 前置条件: 必须先运行 1-prepare.sh
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
BUILD_DIR="/tmp/jito-solana-build"

# Yellowstone artifacts
YELLOWSTONE_TARBALL_URL="https://github.com/rpcpool/yellowstone-grpc/releases/download/v10.0.1%2Bsolana.3.0.6/yellowstone-grpc-geyser-release24-x86_64-unknown-linux-gnu.tar.bz2"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "============================================"
echo "Jito Solana Validator - 从源码编译安装"
echo "============================================"
echo ""

# =============================
# Step 0: 选择版本
# =============================
echo "==> 0) 选择 Jito Solana 版本..."
echo ""
echo "📋 常用版本参考:"
echo "  v3.0.x 系列: v3.0.12, v3.0.11, v3.0.10"
echo "  v3.1.x 系列: v3.1.3, v3.1.2"
echo ""
echo "🔍 查看所有版本: https://github.com/jito-foundation/jito-solana/tags"
echo "   (页面显示 v3.0.12-jito 格式，您只需输入 v3.0.12)"
echo ""

while true; do
  read -p "请输入 Jito Solana 版本号 (例如 v3.0.12): " SOLANA_VERSION

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[错误] 版本号格式不正确，应为 vX.Y.Z 格式 (例如 v3.0.12)"
    echo "       注意: 只输入版本号，不要包含 -jito 后缀"
    continue
  fi

  # Construct tag name
  JITO_TAG="${SOLANA_VERSION}-jito"
  echo "✓ 将安装版本: ${JITO_TAG}"
  break
done

echo ""
echo "==> 1) 安装编译依赖..."
apt update -y
apt install -y \
    build-essential \
    pkg-config \
    libudev-dev \
    llvm \
    libclang-dev \
    protobuf-compiler \
    libssl-dev \
    git \
    wget \
    curl \
    bzip2 \
    ufw

echo ""
echo "==> 2) 安装 Rust 工具链..."

# Check if Rust is already installed
if command -v rustc &>/dev/null; then
  RUST_VERSION=$(rustc --version)
  echo "   ✓ Rust 已安装: $RUST_VERSION"
else
  echo "   - 安装 Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "   ✓ Rust 安装完成"
fi

# Ensure Rust is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Update Rust to stable
echo "   - 更新 Rust 到 stable 版本..."
rustup default stable
rustup update

echo ""
echo "==> 3) 克隆 Jito Solana 源码..."

# Clean old build directory
if [[ -d "$BUILD_DIR" ]]; then
  echo "   - 清理旧的构建目录..."
  rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "   - 克隆仓库 (tag: ${JITO_TAG})..."
git clone --depth 1 --branch "${JITO_TAG}" --recurse-submodules \
    https://github.com/jito-foundation/jito-solana.git

cd jito-solana

echo "   ✓ 源码克隆完成"

echo ""
echo "==> 4) 编译 Jito Solana Validator..."
echo "   ⚠️  这将需要 15-30 分钟，取决于 CPU 性能"
echo ""

# Build validator only (faster than full build)
echo "   - 开始编译 validator..."
./scripts/cargo-install-all.sh --validator-only "$SOLANA_INSTALL_DIR"

if [[ ! -f "$SOLANA_INSTALL_DIR/bin/agave-validator" ]] && [[ ! -f "$SOLANA_INSTALL_DIR/bin/solana-validator" ]]; then
  echo "   ❌ 编译失败: validator 二进制文件未找到"
  exit 1
fi

echo "   ✓ 编译完成"

echo ""
echo "==> 5) 验证安装..."

# Check for validator binary
if [[ -f "$SOLANA_INSTALL_DIR/bin/agave-validator" ]]; then
  VALIDATOR_CMD="agave-validator"
elif [[ -f "$SOLANA_INSTALL_DIR/bin/solana-validator" ]]; then
  VALIDATOR_CMD="solana-validator"
else
  echo "   ❌ Validator 未找到"
  exit 1
fi

echo "   ✓ 找到 validator: $VALIDATOR_CMD"
echo "   - 二进制文件:"
ls -lh "$SOLANA_INSTALL_DIR/bin/" | grep -E "validator|solana|agave" | head -10

echo ""
echo "==> 6) 配置环境变量..."

export PATH="$SOLANA_INSTALL_DIR/bin:$PATH"

# Add to bashrc
if ! grep -q "$SOLANA_INSTALL_DIR/bin" ~/.bashrc 2>/dev/null; then
  echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" >> ~/.bashrc
  echo "   ✓ 已添加到 ~/.bashrc"
fi

# Add to system profile
echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" > /etc/profile.d/solana.sh
chmod 644 /etc/profile.d/solana.sh
echo "   ✓ 已添加到 /etc/profile.d/solana.sh"

# Update /etc/environment
if ! grep -q "$SOLANA_INSTALL_DIR/bin" /etc/environment 2>/dev/null; then
  sed -i "s|PATH=\"|PATH=\"$SOLANA_INSTALL_DIR/bin:|" /etc/environment
  echo "   ✓ 已添加到 /etc/environment"
fi

echo ""
echo "==> 7) 测试 validator..."

VERSION_OUTPUT=$($VALIDATOR_CMD --version 2>&1 || echo "无法获取版本")
echo "   版本: $VERSION_OUTPUT"

echo ""
echo "==> 8) 生成 Validator Keypair..."
[[ -f "$KEYPAIR" ]] || solana-keygen new --no-passphrase -o "$KEYPAIR"

echo ""
echo "==> 9) 配置防火墙..."
ufw --force enable
ufw allow 22
ufw allow 8000:8025/tcp
ufw allow 8000:8025/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo ""
echo "==> 10) 复制 validator 配置文件..."
cp -f "$SCRIPT_DIR/validator.sh" "$BIN/validator.sh"
cp -f "$SCRIPT_DIR/validator-128g.sh" "$BIN/validator-128g.sh"
cp -f "$SCRIPT_DIR/validator-192g.sh" "$BIN/validator-192g.sh"
cp -f "$SCRIPT_DIR/validator-256g.sh" "$BIN/validator-256g.sh"
cp -f "$SCRIPT_DIR/validator-512g.sh" "$BIN/validator-512g.sh"
cp -f "$SCRIPT_DIR/select-validator.sh" "$BIN/select-validator.sh"
chmod +x "$BIN"/validator*.sh "$BIN/select-validator.sh"

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

echo ""
echo "==> 11) 配置 systemd 服务..."
cp -f "$SCRIPT_DIR/sol.service" /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload
echo "   ✓ systemd 服务配置已更新"

echo ""
echo "==> 12) 下载 Yellowstone gRPC geyser..."
cd "$BIN"
wget -q --show-progress "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xjf yellowstone-grpc-geyser.tar.bz2
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ Yellowstone geyser 配置完成"

echo ""
echo "==> 13) 复制辅助脚本..."
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
chmod +x /root/*.sh
echo "   ✓ 辅助脚本已复制"

echo ""
echo "==> 14) 配置开机自启..."
systemctl enable "${SERVICE_NAME}"

echo ""
echo "==> 15) 清理构建文件..."
cd /root
rm -rf "$BUILD_DIR"
echo "   ✓ 构建目录已清理"

echo ""
echo "============================================"
echo "✅ Jito Solana Validator 编译安装完成！"
echo "============================================"
echo ""
echo "版本: ${JITO_TAG}"
echo "Validator: $VALIDATOR_CMD"
echo "安装路径: $SOLANA_INSTALL_DIR"
echo ""
echo "📋 下一步:"
echo ""
echo "1. 验证安装:"
echo "   source /etc/profile.d/solana.sh"
echo "   $VALIDATOR_CMD --version"
echo ""
echo "2. 下载快照并启动节点:"
echo "   cd $SCRIPT_DIR"
echo "   bash 3-start.sh"
echo ""
