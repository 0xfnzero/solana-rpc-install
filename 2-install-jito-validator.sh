#!/bin/bash
set -euo pipefail

# ============================================
# Step 2: Build and install Jito Solana Validator from source
# ============================================
# Purpose: Build and install Jito Solana validator for running RPC node
# Prerequisite: Run 1-prepare.sh first
# Note: ./start and ./bootstrap in the repo are for local testing only (faucet/single validator).
#       Production RPC is started via 3-start.sh + systemd; they are not needed.
# ============================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANG_CACHE_FILE="$SCRIPT_DIR/solana-rpc-lang"
# shellcheck source=lang.sh
source "$SCRIPT_DIR/lang.sh"

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
YELLOWSTONE_TARBALL_URL="https://github.com/rpcpool/yellowstone-grpc/releases/download/v12.1.0%2Bsolana.3.1.8/yellowstone-grpc-geyser-release24-x86_64-unknown-linux-gnu.tar.bz2"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

prompt_lang

if [[ "$LANG_SCRIPT" == "zh" ]]; then
  M_HEADER="Jito Solana Validator - 从源码编译安装"
  M_STEP0="选择 Jito Solana 版本..."
  M_VER_LIST="常用版本参考:"
  M_VER_30="v3.0.x 系列: v3.0.12, v3.0.11, v3.0.10"
  M_VER_31="v3.1.x 系列: v3.1.3, v3.1.2"
  M_SEE_TAGS="查看所有版本: https://github.com/jito-foundation/jito-solana/tags"
  M_ENTER_HINT="(页面显示 v3.0.12-jito 格式，您只需输入 v3.0.12)"
  M_VER_PROMPT="请输入 Jito Solana 版本号 (例如 v3.0.12): "
  M_VER_ERR="[错误] 版本号格式不正确，应为 vX.Y.Z 格式 (例如 v3.0.12)"
  M_VER_SUFFIX="只输入版本号，不要包含 -jito 后缀"
  M_WILL_INSTALL="将安装版本:"
  M_STEP1="安装编译依赖（与 Jito 官方文档一致）..."
  M_STEP2="安装 Rust 工具链..."
  M_RUST_OK="Rust 已安装:"
  M_RUST_INSTALL="安装 Rust..."
  M_RUST_DONE="Rust 安装完成"
  M_RUST_FMT="更新 Rust 到 stable 并安装 rustfmt..."
  M_STEP3="克隆 Jito Solana 源码（完整 clone 后 checkout tag）..."
  M_CLEAN_BUILD="清理旧的构建目录..."
  M_CLONE="克隆仓库（含子模块）..."
  M_CHECKOUT="切换到标签 %s 并更新子模块..."
  M_SOURCE_READY="源码就绪 (commit: %s)"
  M_STEP4="编译 Jito Solana Validator..."
  M_BUILD_TIME="这将需要 15-30 分钟，取决于 CPU 性能"
  M_BUILDING="开始编译 validator..."
  M_BUILD_FAIL="编译失败: solana-validator 未生成到 %s/bin"
  M_BUILD_DONE="编译完成"
  M_STEP5="验证安装..."
  M_FOUND_VAL="找到 validator: %s"
  M_BINARIES="二进制文件:"
  M_STEP6="配置环境变量..."
  M_ADDED_BASHRC="已添加到 ~/.bashrc"
  M_ADDED_PROFILE="已添加到 /etc/profile.d/solana.sh"
  M_ADDED_ENV="已添加到 /etc/environment"
  M_STEP7="测试 validator..."
  M_NO_VERSION="无法获取版本"
  M_VERSION="版本: %s"
  M_STEP8="生成 Validator Keypair..."
  M_STEP9="配置防火墙..."
  M_STEP10="复制 validator 配置文件..."
  M_TIER="检测到 %sGB RAM - 将使用 TIER %s 配置"
  M_STEP11="配置 systemd 服务..."
  M_SVC_UPDATED="systemd 服务配置已更新"
  M_STEP12="下载 Yellowstone gRPC geyser..."
  M_GEYSER_DONE="Yellowstone geyser 配置完成"
  M_STEP13="复制辅助脚本..."
  M_HELPERS_COPIED="辅助脚本已复制"
  M_STEP14="配置开机自启..."
  M_STEP15="清理构建文件..."
  M_BUILD_CLEANED="构建目录已清理"
  M_DONE_HEADER="Jito Solana Validator 编译安装完成！"
  M_VER_LABEL="版本: %s"
  M_INSTALL_PATH="安装路径: %s"
  M_NEXT_STEPS="下一步:"
  M_VERIFY="验证安装:"
  M_DOWNLOAD_START="下载快照并启动节点:"
else
  M_HEADER="Jito Solana Validator - Build and install from source"
  M_STEP0="Select Jito Solana version..."
  M_VER_LIST="Common versions:"
  M_VER_30="v3.0.x: v3.0.12, v3.0.11, v3.0.10"
  M_VER_31="v3.1.x: v3.1.3, v3.1.2"
  M_SEE_TAGS="See all tags: https://github.com/jito-foundation/jito-solana/tags"
  M_ENTER_HINT="(page shows v3.0.12-jito; enter only v3.0.12)"
  M_VER_PROMPT="Enter Jito Solana version (e.g. v3.0.12): "
  M_VER_ERR="[ERROR] Invalid version format. Use vX.Y.Z (e.g. v3.0.12)"
  M_VER_SUFFIX="Enter version only, without -jito suffix"
  M_WILL_INSTALL="Will install:"
  M_STEP1="Install build dependencies (per Jito docs)..."
  M_STEP2="Install Rust toolchain..."
  M_RUST_OK="Rust already installed:"
  M_RUST_INSTALL="Installing Rust..."
  M_RUST_DONE="Rust installed"
  M_RUST_FMT="Update Rust to stable and add rustfmt..."
  M_STEP3="Clone Jito Solana source (full clone then checkout tag)..."
  M_CLEAN_BUILD="Cleaning old build dir..."
  M_CLONE="Cloning repo (with submodules)..."
  M_CHECKOUT="Checkout tag %s and update submodules..."
  M_SOURCE_READY="Source ready (commit: %s)"
  M_STEP4="Build Jito Solana Validator..."
  M_BUILD_TIME="This may take 15-30 minutes depending on CPU"
  M_BUILDING="Building validator..."
  M_BUILD_FAIL="Build failed: solana-validator not found at %s/bin"
  M_BUILD_DONE="Build complete"
  M_STEP5="Verify installation..."
  M_FOUND_VAL="Found validator: %s"
  M_BINARIES="Binaries:"
  M_STEP6="Configure environment..."
  M_ADDED_BASHRC="Added to ~/.bashrc"
  M_ADDED_PROFILE="Added to /etc/profile.d/solana.sh"
  M_ADDED_ENV="Added to /etc/environment"
  M_STEP7="Test validator..."
  M_NO_VERSION="could not get version"
  M_VERSION="Version: %s"
  M_STEP8="Generate Validator Keypair..."
  M_STEP9="Configure firewall..."
  M_STEP10="Copy validator configs..."
  M_TIER="%sGB RAM detected - using TIER %s config"
  M_STEP11="Configure systemd service..."
  M_SVC_UPDATED="systemd service updated"
  M_STEP12="Download Yellowstone gRPC geyser..."
  M_GEYSER_DONE="Yellowstone geyser configured"
  M_STEP13="Copy helper scripts..."
  M_HELPERS_COPIED="Helper scripts copied"
  M_STEP14="Enable service on boot..."
  M_STEP15="Clean build dir..."
  M_BUILD_CLEANED="Build dir cleaned"
  M_DONE_HEADER="Jito Solana Validator build and install complete!"
  M_VER_LABEL="Version: %s"
  M_INSTALL_PATH="Install path: %s"
  M_NEXT_STEPS="Next steps:"
  M_VERIFY="Verify install:"
  M_DOWNLOAD_START="Download snapshot and start node:"
fi

echo "============================================"
echo "$M_HEADER"
echo "============================================"
echo ""

# =============================
# Step 0: Select version
# =============================
echo "==> 0) $M_STEP0"
echo ""
echo "$M_VER_LIST"
echo "  $M_VER_30"
echo "  $M_VER_31"
echo ""
echo "$M_SEE_TAGS"
echo "   $M_ENTER_HINT"
echo ""

while true; do
  read -p "$M_VER_PROMPT" SOLANA_VERSION

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "$M_VER_ERR"
    echo "        $M_VER_SUFFIX"
    continue
  fi

  # Construct tag name
  JITO_TAG="${SOLANA_VERSION}-jito"
  echo "$M_WILL_INSTALL ${JITO_TAG}"
  break
done

echo ""
echo "==> 1) $M_STEP1"
apt update -y
apt install -y \
    build-essential \
    pkg-config \
    libudev-dev \
    libssl-dev \
    zlib1g-dev \
    llvm \
    clang \
    libclang-dev \
    cmake \
    make \
    libprotobuf-dev \
    protobuf-compiler \
    git \
    wget \
    curl \
    bzip2 \
    ufw

echo ""
echo "==> 2) $M_STEP2"

# Check if Rust is already installed
if command -v rustc &>/dev/null; then
  RUST_VERSION=$(rustc --version)
  echo "   ✓ $M_RUST_OK $RUST_VERSION"
else
  echo "   - $M_RUST_INSTALL"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "   ✓ $M_RUST_DONE"
fi

# Ensure Rust is in PATH (for both current user and root when script runs as root)
export PATH="${HOME:-/root}/.cargo/bin:$PATH"

# Update Rust to stable and add rustfmt (required by Jito build)
echo "   - $M_RUST_FMT"
rustup default stable
rustup update
rustup component add rustfmt

echo ""
echo "==> 3) $M_STEP3"

# Clean old build directory
if [[ -d "$BUILD_DIR" ]]; then
  echo "   - $M_CLEAN_BUILD"
  rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "   - $M_CLONE"
git clone https://github.com/jito-foundation/jito-solana.git --recurse-submodules
cd jito-solana

printf "   - $M_CHECKOUT\n" "$JITO_TAG"
git checkout "tags/${JITO_TAG}"
git submodule update --init --recursive

printf "   ✓ $M_SOURCE_READY\n" "$(git rev-parse HEAD)"

echo ""
echo "==> 4) $M_STEP4"
echo "   ⚠️  $M_BUILD_TIME"
echo ""

# Build validator only (CI_COMMIT per official docs for version tracking)
echo "   - $M_BUILDING"
CI_COMMIT=$(git rev-parse HEAD)
export CI_COMMIT
mkdir -p "$SOLANA_INSTALL_DIR"
scripts/cargo-install-all.sh --validator-only "$SOLANA_INSTALL_DIR"

if [[ ! -f "$SOLANA_INSTALL_DIR/bin/solana-validator" ]]; then
  printf "   ❌ $M_BUILD_FAIL\n" "$SOLANA_INSTALL_DIR"
  exit 1
fi

echo "   ✓ $M_BUILD_DONE"

echo ""
echo "==> 5) $M_STEP5"

VALIDATOR_CMD="solana-validator"
printf "   ✓ $M_FOUND_VAL\n" "$VALIDATOR_CMD"
echo "   - $M_BINARIES"
ls -lh "$SOLANA_INSTALL_DIR/bin/" | grep -E "validator|solana" | head -10

echo ""
echo "==> 6) $M_STEP6"

export PATH="$SOLANA_INSTALL_DIR/bin:$PATH"

# Add to bashrc
if ! grep -q "$SOLANA_INSTALL_DIR/bin" ~/.bashrc 2>/dev/null; then
  echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" >> ~/.bashrc
  echo "   ✓ $M_ADDED_BASHRC"
fi

# Add to system profile
echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" > /etc/profile.d/solana.sh
chmod 644 /etc/profile.d/solana.sh
echo "   ✓ $M_ADDED_PROFILE"

# Update /etc/environment
if ! grep -q "$SOLANA_INSTALL_DIR/bin" /etc/environment 2>/dev/null; then
  sed -i "s|PATH=\"|PATH=\"$SOLANA_INSTALL_DIR/bin:|" /etc/environment
  echo "   ✓ $M_ADDED_ENV"
fi

echo ""
echo "==> 7) $M_STEP7"

VERSION_OUTPUT=$($VALIDATOR_CMD --version 2>&1 || echo "$M_NO_VERSION")
printf "   $M_VERSION\n" "$VERSION_OUTPUT"

echo ""
echo "==> 8) $M_STEP8"
[[ -f "$KEYPAIR" ]] || solana-keygen new --no-passphrase -o "$KEYPAIR"

echo ""
echo "==> 9) $M_STEP9"
ufw --force enable
ufw allow 22
ufw allow 8000:8025/tcp
ufw allow 8000:8025/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo ""
echo "==> 10) $M_STEP10"
cp -f "$SCRIPT_DIR/validator.sh" "$BIN/validator.sh"
cp -f "$SCRIPT_DIR/validator-128g.sh" "$BIN/validator-128g.sh"
cp -f "$SCRIPT_DIR/validator-192g.sh" "$BIN/validator-192g.sh"
cp -f "$SCRIPT_DIR/validator-256g.sh" "$BIN/validator-256g.sh"
cp -f "$SCRIPT_DIR/validator-512g.sh" "$BIN/validator-512g.sh"
cp -f "$SCRIPT_DIR/select-validator.sh" "$BIN/select-validator.sh"
chmod +x "$BIN"/validator*.sh "$BIN/select-validator.sh"

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
if [[ $TOTAL_MEM_GB -lt 160 ]]; then
  printf "   ✓ $M_TIER\n" "$TOTAL_MEM_GB" "1 (128GB)"
elif [[ $TOTAL_MEM_GB -lt 224 ]]; then
  printf "   ✓ $M_TIER\n" "$TOTAL_MEM_GB" "2 (192GB)"
elif [[ $TOTAL_MEM_GB -lt 384 ]]; then
  printf "   ✓ $M_TIER\n" "$TOTAL_MEM_GB" "3 (256GB)"
else
  printf "   ✓ $M_TIER\n" "$TOTAL_MEM_GB" "4 (512GB+)"
fi

echo ""
echo "==> 11) $M_STEP11"
cp -f "$SCRIPT_DIR/sol.service" /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload
echo "   ✓ $M_SVC_UPDATED"

echo ""
echo "==> 12) $M_STEP12"
cd "$BIN"
wget -q --show-progress "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xjf yellowstone-grpc-geyser.tar.bz2
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ $M_GEYSER_DONE"

echo ""
echo "==> 13) $M_STEP13"
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
chmod +x /root/*.sh
echo "   ✓ $M_HELPERS_COPIED"

echo ""
echo "==> 14) $M_STEP14"
systemctl enable "${SERVICE_NAME}"

echo ""
echo "==> 15) $M_STEP15"
cd /root
rm -rf "$BUILD_DIR"
echo "   ✓ $M_BUILD_CLEANED"

echo ""
echo "============================================"
echo "✅ $M_DONE_HEADER"
echo "============================================"
echo ""
printf "$M_VER_LABEL\n" "${JITO_TAG}"
echo "Validator: $VALIDATOR_CMD"
printf "$M_INSTALL_PATH\n" "$SOLANA_INSTALL_DIR"
echo ""
echo "$M_NEXT_STEPS"
echo ""
echo "1. $M_VERIFY"
echo "   source /etc/profile.d/solana.sh"
echo "   $VALIDATOR_CMD --version"
echo ""
echo "2. $M_DOWNLOAD_START"
echo "   cd $SCRIPT_DIR"
echo "   bash 3-start.sh"
echo ""
