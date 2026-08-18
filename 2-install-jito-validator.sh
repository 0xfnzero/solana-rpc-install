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
BIN="$BASE/bin"
KEYPAIR="$BIN/validator-keypair.json"
GEYSER_CFG="$BIN/yellowstone-config.json"
SERVICE_NAME=${SERVICE_NAME:-sol}
SOLANA_INSTALL_DIR="/usr/local/solana"
BUILD_DIR="/tmp/jito-solana-build"
DEFAULT_SOLANA_VERSION="v4.2.1"
VALIDATOR_DYNAMIC_PORT_RANGE="8000-8030"
VALIDATOR_UFW_PORT_RANGE="${VALIDATOR_DYNAMIC_PORT_RANGE/-/:}"

# Yellowstone artifacts are resolved after the Jito Solana version is selected.
YELLOWSTONE_RELEASE_TAG=""
YELLOWSTONE_GEYSER_SO_URL=""
YELLOWSTONE_GEYSER_SO_SHA256=""
YELLOWSTONE_GEYSER_DIR="$BIN/yellowstone-grpc-geyser-release"
YELLOWSTONE_GEYSER_LIB_DIR="$YELLOWSTONE_GEYSER_DIR/lib"
YELLOWSTONE_GEYSER_LIB="$YELLOWSTONE_GEYSER_LIB_DIR/libyellowstone_grpc_geyser.so"

resolve_yellowstone_release() {
  local solana_version="$1"
  local clean_version="${solana_version#v}"
  local version_minor

  version_minor=$(sed -E 's/^([0-9]+\.[0-9]+)\..*$/\1/' <<<"$clean_version")

  local resolved
  resolved=$(python3 - "$clean_version" "$version_minor" <<'PY'
import json
import re
import sys
import urllib.request

exact_version = sys.argv[1]
minor_version = sys.argv[2]
api_url = "https://api.github.com/repos/rpcpool/yellowstone-grpc/releases?per_page=100"

with urllib.request.urlopen(api_url, timeout=30) as response:
    releases = json.load(response)

def find_asset(release):
    for asset in release.get("assets", []):
        if asset.get("name") == "libyellowstone_grpc_geyser.so":
            digest = asset.get("digest") or ""
            if digest.startswith("sha256:"):
                digest = digest[len("sha256:"):]
            return asset.get("browser_download_url", ""), digest
    return "", ""

candidates = []
for release in releases:
    tag = release.get("tag_name", "")
    url, digest = find_asset(release)
    if not url or not digest:
        continue

    exact_match = f"+solana.{exact_version}" in tag
    minor_match = f"+solana.{minor_version}." in tag
    if not exact_match and not minor_match:
        continue

    stable = not release.get("prerelease", False) and not re.search(r"(?i)(?:-rc|beta|alpha)", tag)
    score = (
        2 if exact_match else 1,
        1 if stable else 0,
        release.get("published_at") or release.get("created_at") or "",
    )
    candidates.append((score, tag, url, digest))

if not candidates:
    raise SystemExit(
        f"No compatible yellowstone-grpc release found for Solana {exact_version}. "
        "Check https://github.com/rpcpool/yellowstone-grpc/releases"
    )

candidates.sort(reverse=True)
_, tag, url, digest = candidates[0]
print(f"{tag}\t{url}\t{digest}")
PY
)

  IFS=$'\t' read -r YELLOWSTONE_RELEASE_TAG YELLOWSTONE_GEYSER_SO_URL YELLOWSTONE_GEYSER_SO_SHA256 <<<"$resolved"

  if [[ -z "$YELLOWSTONE_RELEASE_TAG" || -z "$YELLOWSTONE_GEYSER_SO_URL" || -z "$YELLOWSTONE_GEYSER_SO_SHA256" ]]; then
    echo "[ERROR] Failed to resolve Yellowstone gRPC release metadata" >&2
    exit 1
  fi
}

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] Please run as root: sudo bash $0" >&2
  exit 1
fi

prompt_lang

if [[ "$LANG_SCRIPT" == "zh" ]]; then
  M_HEADER="Jito Solana Validator - 从源码编译安装"
  M_STEP0="选择 Jito Solana 版本..."
  M_SEE_TAGS="查看所有版本: https://github.com/jito-foundation/jito-solana/tags"
  M_ENTER_HINT="(页面显示 v4.2.1-jito 格式，您只需输入 v4.2.1；预发布版可输入 v4.3.0-alpha.1)"
  M_VER_PROMPT="请输入 Jito Solana 版本号 [默认 v4.2.1]: "
  M_VER_ERR="[错误] 版本号格式不正确，应为 vX.Y.Z 或 vX.Y.Z-rc.N 格式 (例如 v4.2.1)"
  M_VER_SUFFIX="只输入版本号，不要包含 -jito 后缀"
  M_WILL_INSTALL="将安装版本:"
  M_STEP1="安装编译依赖（与 Jito 官方文档一致）..."
  M_STEP2="安装 Rust 工具链..."
  M_RUST_OK="Rust 已安装:"
  M_RUST_INSTALL="安装 Rust..."
  M_RUST_DONE="Rust 安装完成"
  M_RUST_FMT="更新 Rust 到 stable 并安装 rustfmt..."
  M_STEP3="按版本标签浅克隆 Jito Solana 源码..."
  M_CLEAN_BUILD="清理旧的构建目录..."
  M_CLONE="克隆仓库（含子模块）..."
  M_CHECKOUT="验证标签 %s 并更新子模块..."
  M_SOURCE_READY="源码就绪 (commit: %s)"
  M_STEP4="编译 Jito Solana Validator..."
  M_BUILD_TIME="启用 LTO 后通常需要 30-90 分钟，取决于 CPU 性能"
  M_BUILDING="开始编译 validator..."
  M_BUILD_FAIL="编译失败: validator 未生成到 %s/bin (应有 agave-validator 或 solana-validator)"
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
  M_FW_PUBLIC_CLOSED="8899/8900/10900 不对公网开放，仅本机可访问"
  M_STEP10="复制 validator 配置文件..."
  M_TIER="检测到 %sGB RAM - 将使用 TIER %s 配置"
  M_STEP11="配置 systemd 服务..."
  M_SVC_UPDATED="systemd 服务配置已更新"
  M_STEP12="下载 Yellowstone gRPC geyser..."
  M_GEYSER_VERSION="Yellowstone gRPC 版本: %s"
  M_GEYSER_VERIFY="校验 Yellowstone gRPC geyser..."
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
  M_SEE_TAGS="See all tags: https://github.com/jito-foundation/jito-solana/tags"
  M_ENTER_HINT="(page shows v4.2.1-jito; enter only v4.2.1; prereleases like v4.3.0-alpha.1 are allowed)"
  M_VER_PROMPT="Enter Jito Solana version [default v4.2.1]: "
  M_VER_ERR="[ERROR] Invalid version format. Use vX.Y.Z or vX.Y.Z-rc.N (e.g. v4.2.1)"
  M_VER_SUFFIX="Enter version only, without -jito suffix"
  M_WILL_INSTALL="Will install:"
  M_STEP1="Install build dependencies (per Jito docs)..."
  M_STEP2="Install Rust toolchain..."
  M_RUST_OK="Rust already installed:"
  M_RUST_INSTALL="Installing Rust..."
  M_RUST_DONE="Rust installed"
  M_RUST_FMT="Update Rust to stable and add rustfmt..."
  M_STEP3="Shallow-clone Jito Solana at the selected release tag..."
  M_CLEAN_BUILD="Cleaning old build dir..."
  M_CLONE="Cloning repo (with submodules)..."
  M_CHECKOUT="Verify tag %s and update submodules..."
  M_SOURCE_READY="Source ready (commit: %s)"
  M_STEP4="Build Jito Solana Validator..."
  M_BUILD_TIME="The LTO build usually takes 30-90 minutes depending on CPU"
  M_BUILDING="Building validator..."
  M_BUILD_FAIL="Build failed: no validator binary at %s/bin (expected agave-validator or solana-validator)"
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
  M_FW_PUBLIC_CLOSED="8899/8900/10900 are not open to the public; localhost only"
  M_STEP10="Copy validator configs..."
  M_TIER="%sGB RAM detected - using TIER %s config"
  M_STEP11="Configure systemd service..."
  M_SVC_UPDATED="systemd service updated"
  M_STEP12="Download Yellowstone gRPC geyser..."
  M_GEYSER_VERSION="Yellowstone gRPC version: %s"
  M_GEYSER_VERIFY="Verify Yellowstone gRPC geyser..."
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
echo "$M_SEE_TAGS"
echo "   $M_ENTER_HINT"
echo ""

while true; do
  read -r -p "$M_VER_PROMPT" SOLANA_VERSION
  SOLANA_VERSION=${SOLANA_VERSION:-$DEFAULT_SOLANA_VERSION}

  if [[ "$SOLANA_VERSION" == *-jito ]]; then
    echo "$M_VER_SUFFIX"
    continue
  fi

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z]+(\.[0-9A-Za-z]+)*)?$ ]]; then
    echo "$M_VER_ERR"
    echo "        $M_VER_SUFFIX"
    continue
  fi

  # Construct tag name
  JITO_TAG="${SOLANA_VERSION}-jito"
  if command -v git >/dev/null 2>&1 && \
      ! git ls-remote --exit-code --tags https://github.com/jito-foundation/jito-solana.git \
        "refs/tags/${JITO_TAG}" >/dev/null 2>&1; then
    echo "[ERROR] Jito release tag does not exist: $JITO_TAG" >&2
    continue
  fi
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
    python3 \
    jq \
    git \
    wget \
    curl \
    bzip2 \
    logrotate \
    sysstat \
    ufw

if ! git ls-remote --exit-code --tags https://github.com/jito-foundation/jito-solana.git \
    "refs/tags/${JITO_TAG}" >/dev/null 2>&1; then
  echo "[ERROR] Jito release tag does not exist or GitHub is unreachable: $JITO_TAG" >&2
  exit 1
fi

resolve_yellowstone_release "$SOLANA_VERSION"
printf "Yellowstone gRPC: %s\n" "$YELLOWSTONE_RELEASE_TAG"

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
git clone --branch "$JITO_TAG" --depth 1 --recurse-submodules --shallow-submodules \
  https://github.com/jito-foundation/jito-solana.git
cd jito-solana

printf "   - $M_CHECKOUT\n" "$JITO_TAG"
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
export RUSTFLAGS="${RUSTFLAGS:--C target-cpu=native}"
mkdir -p "$SOLANA_INSTALL_DIR"
scripts/cargo-install-all.sh --release-with-lto --validator-only "$SOLANA_INSTALL_DIR"

# Per jito-solana scripts/agave-build-lists.sh, AGAVE_BINS_VAL_OP includes agave-validator.
# Check that first; fallback to solana-validator for older or alternate builds.
if [[ -f "$SOLANA_INSTALL_DIR/bin/agave-validator" ]]; then
  VALIDATOR_CMD="agave-validator"
elif [[ -f "$SOLANA_INSTALL_DIR/bin/solana-validator" ]]; then
  VALIDATOR_CMD="solana-validator"
else
  printf "   ❌ $M_BUILD_FAIL\n" "$SOLANA_INSTALL_DIR"
  exit 1
fi

echo "   ✓ $M_BUILD_DONE"

echo ""
echo "==> 5) $M_STEP5"
printf "   ✓ $M_FOUND_VAL\n" "$VALIDATOR_CMD"
echo "   - $M_BINARIES"
binary_count=0
for binary in "$SOLANA_INSTALL_DIR"/bin/*validator* "$SOLANA_INSTALL_DIR"/bin/solana*; do
  [[ -e "$binary" ]] || continue
  ls -lh "$binary"
  binary_count=$((binary_count + 1))
  ((binary_count >= 10)) && break
done

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
ufw allow "$VALIDATOR_UFW_PORT_RANGE"/tcp
ufw allow "$VALIDATOR_UFW_PORT_RANGE"/udp
# RPC / WebSocket / Yellowstone gRPC stay localhost-only. Public scanners
# hitting 8899/8900/10900 overload the node; allow a specific client IP later
# if remote access is required.
for port in 8899 8900 10900; do
  yes | ufw delete allow "$port" >/dev/null 2>&1 || true
  yes | ufw delete allow "$port/tcp" >/dev/null 2>&1 || true
done
echo "   ✓ $M_FW_PUBLIC_CLOSED"
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
if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify "$SCRIPT_DIR/sol.service"
fi
cp -f "$SCRIPT_DIR/sol.service" "/etc/systemd/system/${SERVICE_NAME}.service"
systemctl daemon-reload
echo "   ✓ $M_SVC_UPDATED"

echo ""
echo "==> 12) $M_STEP12"
printf "   - $M_GEYSER_VERSION\n" "$YELLOWSTONE_RELEASE_TAG"
rm -rf "$YELLOWSTONE_GEYSER_DIR"
mkdir -p "$YELLOWSTONE_GEYSER_LIB_DIR"
wget -q --show-progress "$YELLOWSTONE_GEYSER_SO_URL" -O "$YELLOWSTONE_GEYSER_LIB"
echo "   - $M_GEYSER_VERIFY"
echo "$YELLOWSTONE_GEYSER_SO_SHA256  $YELLOWSTONE_GEYSER_LIB" | sha256sum -c -
chmod 755 "$YELLOWSTONE_GEYSER_LIB"
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ $M_GEYSER_DONE"

echo ""
echo "==> 13) $M_STEP13"
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
sed "s/sol\.service/${SERVICE_NAME}.service/g" "$SCRIPT_DIR/logrotate-solana-rpc" \
  >/etc/logrotate.d/solana-rpc
chmod +x /root/*.sh
chmod 0644 /etc/logrotate.d/solana-rpc
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
