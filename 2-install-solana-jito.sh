#!/bin/bash
set -euo pipefail

# ============================================
# 步骤2: 安装 Solana (使用 Jito 预编译版本)
# ============================================
# 前置条件: 必须先运行 1-prepare.sh
# - Install OpenSSL 1.1
# - Download & Install Jito Solana precompiled binaries
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

echo "==> 节点安装（使用 Jito 预编译版本）开始..."

# =============================
# Step 0: Verify Jito Solana version first
# =============================
echo "==> 0) 验证 Jito Solana 版本 ..."

# Interactive version selection and validation
while true; do
  read -p "请输入 Jito Solana 版本号 (例如 v3.0.11, v3.0.10): " SOLANA_VERSION

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[错误] 版本号格式不正确，应为 vX.Y.Z 格式 (例如 v3.0.11)"
    read -p "是否重新输入版本号？(y/n): " retry
    [[ "$retry" != "y" && "$retry" != "Y" ]] && exit 1
    continue
  fi

  # Construct Jito precompiled download URL
  JITO_RELEASE_URL="https://github.com/jito-foundation/jito-solana/releases/download/${SOLANA_VERSION}-jito/solana-release-x86_64-unknown-linux-gnu.tar.bz2"

  echo "正在验证 Jito Solana 版本 ${SOLANA_VERSION}-jito ..."
  echo "下载地址: ${JITO_RELEASE_URL}"

  # Try to verify the precompiled tarball exists
  if wget --spider "$JITO_RELEASE_URL" 2>/dev/null; then
    echo "✓ 版本 ${SOLANA_VERSION}-jito 验证成功，继续安装流程..."
    break
  else
    echo "[错误] 版本 ${SOLANA_VERSION}-jito 不存在或下载地址不可用"
    echo "请访问 https://github.com/jito-foundation/jito-solana/releases 查看可用版本"
    read -p "是否重新输入版本号？(y/n): " retry
    [[ "$retry" != "y" && "$retry" != "Y" ]] && exit 1
  fi
done

echo "==> 版本验证完成，开始系统配置..."
apt update -y
apt install -y wget curl bzip2 ufw || true

echo "==> 1) 安装 OpenSSL 1.1 ..."
wget -q http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb -O /tmp/libssl1.1.deb
dpkg -i /tmp/libssl1.1.deb || true

echo "==> 2) 下载 Jito Solana 预编译版本 (${SOLANA_VERSION}-jito) ..."

# Download precompiled binaries
DOWNLOAD_DIR="/tmp/jito-solana-download"
mkdir -p "$DOWNLOAD_DIR"
cd "$DOWNLOAD_DIR"

# Clean old download if exists
if [[ -f "solana-release.tar.bz2" ]]; then
  echo "   - 清理旧的下载文件..."
  rm -f "solana-release.tar.bz2"
fi

echo "   - 下载 Jito Solana 预编译包..."
echo "   - URL: ${JITO_RELEASE_URL}"

if ! wget -q --show-progress -O "solana-release.tar.bz2" "$JITO_RELEASE_URL"; then
  echo "[错误] 下载失败"
  exit 1
fi

if [[ ! -f "solana-release.tar.bz2" ]]; then
  echo "[错误] 下载文件不存在"
  exit 1
fi

echo "   ✓ 下载完成"

echo "==> 3) 解压 Jito Solana 预编译包 ..."

# Extract the tarball
echo "   - 解压文件..."
if ! tar -xjf "solana-release.tar.bz2"; then
  echo "[错误] 解压失败"
  exit 1
fi

if [[ ! -d "solana-release" ]]; then
  echo "[错误] 解压后目录不存在: solana-release"
  exit 1
fi

echo "   ✓ 解压完成"

echo "==> 4) 安装 Jito Solana 到 ${SOLANA_INSTALL_DIR} ..."

# Remove old installation directory if exists
if [[ -d "$SOLANA_INSTALL_DIR" ]]; then
  echo "   - 删除旧的安装目录..."
  rm -rf "$SOLANA_INSTALL_DIR"
fi

# Move the extracted directory to install location
echo "   - 移动文件到安装目录..."
mv "solana-release" "$SOLANA_INSTALL_DIR"

# Cleanup download directory
echo "   - 清理临时下载文件..."
cd /root
rm -rf "$DOWNLOAD_DIR"

echo "   ✓ 安装完成"

echo "==> 5) 配置 PATH 环境变量 (持久化) ..."

# Configure PATH persistently
export PATH="$SOLANA_INSTALL_DIR/bin:$PATH"

# Add to root's bashrc if not already present
if ! grep -q 'solana/bin' /root/.bashrc 2>/dev/null; then
  echo "   - 添加到 /root/.bashrc"
  echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" >> /root/.bashrc
else
  echo "   - /root/.bashrc 已包含配置"
fi

# Add to system-wide profile for all users
echo "   - 添加到系统环境变量 /etc/profile.d/solana.sh"
echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" > /etc/profile.d/solana.sh
chmod 644 /etc/profile.d/solana.sh

# Also add to /etc/environment for system-wide PATH
if ! grep -q "$SOLANA_INSTALL_DIR/bin" /etc/environment 2>/dev/null; then
  echo "   - 添加到 /etc/environment"
  # Read current PATH from /etc/environment
  CURRENT_PATH=$(grep '^PATH=' /etc/environment | sed 's/PATH=//' | tr -d '"')
  # Add Solana path if not present
  if [[ -z "$CURRENT_PATH" ]]; then
    echo "PATH=\"$SOLANA_INSTALL_DIR/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"" > /etc/environment
  else
    sed -i "s|PATH=\"\(.*\)\"|PATH=\"$SOLANA_INSTALL_DIR/bin:\1\"|" /etc/environment
  fi
fi

echo "   ✓ PATH 配置完成"
echo ""
echo "   环境变量已添加到："
echo "     - /root/.bashrc (root 用户)"
echo "     - /etc/profile.d/solana.sh (所有用户登录时)"
echo "     - /etc/environment (系统级别)"
echo ""

# Verify installation
if ! command -v solana >/dev/null 2>&1; then
  echo "[错误] Solana 安装失败，命令不可用"
  echo "尝试手动验证: $SOLANA_INSTALL_DIR/bin/solana --version"
  exit 1
fi

echo "==> 6) 验证 Jito Solana 安装 ..."
echo "   - Solana 版本信息:"
solana --version
echo ""
echo "   - 安装路径: ${SOLANA_INSTALL_DIR}"
echo "   - 可执行文件: ${SOLANA_INSTALL_DIR}/bin/"
ls -lh "${SOLANA_INSTALL_DIR}/bin/" | grep -E "solana|agave" | head -5
echo "   ..."
echo ""

echo "==> 7) 生成 Validator Keypair ..."
[[ -f "$KEYPAIR" ]] || solana-keygen new -o "$KEYPAIR"

echo "==> 8) 配置 UFW 防火墙 ..."
ufw --force enable
ufw allow 22
ufw allow 8000:8025/tcp
ufw allow 8000:8025/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo "==> 9) 复制 validator 配置文件到 $BIN ..."
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

echo "==> 10) 复制 systemd 服务配置..."
cp -f "$SCRIPT_DIR/sol.service" /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload
echo "   ✓ systemd 服务配置已更新 (MemoryHigh=120G, WatchdogSec 已禁用)"

echo "==> 11) 下载 Yellowstone gRPC geyser 与配置 ..."
cd "$BIN"
wget -q "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xvjf yellowstone-grpc-geyser.tar.bz2
echo "   - 复制优化后的 yellowstone-config.json ..."
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ 已应用低延迟优化配置 (Tokio 16 threads, HTTP/2 优化, zstd 压缩)"

echo "==> 12) 复制辅助脚本到 /root ..."
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
cp -f "$SCRIPT_DIR/add-swap-128g.sh"     /root/add-swap-128g.sh
cp -f "$SCRIPT_DIR/remove-swap.sh"       /root/remove-swap.sh
chmod +x /root/redo_node.sh /root/restart_node.sh /root/get_health.sh /root/catchup.sh /root/performance-monitor.sh /root/add-swap-128g.sh /root/remove-swap.sh
echo "   ✓ 辅助脚本已复制到 /root (包含 swap 管理脚本)"

echo "==> 13) 配置开机自启 ..."
systemctl enable "${SERVICE_NAME}"

echo ""
echo "============================================"
echo "✅ 步骤 2 完成: Jito Solana 安装完成!"
echo "============================================"
echo ""
echo "版本: ${SOLANA_VERSION}-jito"
echo "安装路径: ${SOLANA_INSTALL_DIR}"
echo "环境变量: 已持久化到 /root/.bashrc, /etc/profile.d/solana.sh, /etc/environment"
echo ""
echo "📋 下一步:"
echo ""
echo "步骤 3: 验证环境变量（可选）"
echo "  source /etc/profile.d/solana.sh  # 加载环境变量"
echo "  solana --version  # 应显示 Jito Solana 版本"
echo ""
echo "步骤 4: 下载快照并启动节点"
echo "  cd $SCRIPT_DIR"
echo "  bash 3-start.sh"
echo ""
