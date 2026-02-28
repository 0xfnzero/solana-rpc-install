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

echo "============================================"
echo "Jito Solana Validator - Build and install from source"
echo "============================================"
echo ""

# =============================
# Step 0: Select version
# =============================
echo "==> 0) Select Jito Solana version..."
echo ""
echo "Common versions:"
echo "  v3.0.x: v3.0.12, v3.0.11, v3.0.10"
echo "  v3.1.x: v3.1.3, v3.1.2"
echo ""
echo "See all tags: https://github.com/jito-foundation/jito-solana/tags"
echo "   (page shows v3.0.12-jito; enter only v3.0.12)"
echo ""

while true; do
  read -p "Enter Jito Solana version (e.g. v3.0.12): " SOLANA_VERSION

  # Validate version format
  if [[ ! "$SOLANA_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[ERROR] Invalid version format. Use vX.Y.Z (e.g. v3.0.12)"
    echo "        Enter version only, without -jito suffix"
    continue
  fi

  # Construct tag name
  JITO_TAG="${SOLANA_VERSION}-jito"
  echo "Will install: ${JITO_TAG}"
  break
done

echo ""
echo "==> 1) Install build dependencies (per Jito docs)..."
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
echo "==> 2) Install Rust toolchain..."

# Check if Rust is already installed
if command -v rustc &>/dev/null; then
  RUST_VERSION=$(rustc --version)
  echo "   ✓ Rust already installed: $RUST_VERSION"
else
  echo "   - Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "   ✓ Rust installed"
fi

# Ensure Rust is in PATH (for both current user and root when script runs as root)
export PATH="${HOME:-/root}/.cargo/bin:$PATH"

# Update Rust to stable and add rustfmt (required by Jito build)
echo "   - Update Rust to stable and add rustfmt..."
rustup default stable
rustup update
rustup component add rustfmt

echo ""
echo "==> 3) Clone Jito Solana source (full clone then checkout tag)..."

# Clean old build directory
if [[ -d "$BUILD_DIR" ]]; then
  echo "   - Cleaning old build dir..."
  rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "   - Cloning repo (with submodules)..."
git clone https://github.com/jito-foundation/jito-solana.git --recurse-submodules
cd jito-solana

echo "   - Checkout tag ${JITO_TAG} and update submodules..."
git checkout "tags/${JITO_TAG}"
git submodule update --init --recursive

echo "   ✓ Source ready (commit: $(git rev-parse HEAD))"

echo ""
echo "==> 4) Build Jito Solana Validator..."
echo "   ⚠️  This may take 15-30 minutes depending on CPU"
echo ""

# Build validator only (CI_COMMIT per official docs for version tracking)
echo "   - Building validator..."
CI_COMMIT=$(git rev-parse HEAD)
export CI_COMMIT
mkdir -p "$SOLANA_INSTALL_DIR"
scripts/cargo-install-all.sh --validator-only "$SOLANA_INSTALL_DIR"

if [[ ! -f "$SOLANA_INSTALL_DIR/bin/solana-validator" ]]; then
  echo "   ❌ Build failed: solana-validator not found at $SOLANA_INSTALL_DIR/bin"
  exit 1
fi

echo "   ✓ Build complete"

echo ""
echo "==> 5) Verify installation..."

VALIDATOR_CMD="solana-validator"
echo "   ✓ Found validator: $VALIDATOR_CMD"
echo "   - Binaries:"
ls -lh "$SOLANA_INSTALL_DIR/bin/" | grep -E "validator|solana" | head -10

echo ""
echo "==> 6) Configure environment..."

export PATH="$SOLANA_INSTALL_DIR/bin:$PATH"

# Add to bashrc
if ! grep -q "$SOLANA_INSTALL_DIR/bin" ~/.bashrc 2>/dev/null; then
  echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" >> ~/.bashrc
  echo "   ✓ Added to ~/.bashrc"
fi

# Add to system profile
echo "export PATH=\"$SOLANA_INSTALL_DIR/bin:\$PATH\"" > /etc/profile.d/solana.sh
chmod 644 /etc/profile.d/solana.sh
echo "   ✓ Added to /etc/profile.d/solana.sh"

# Update /etc/environment
if ! grep -q "$SOLANA_INSTALL_DIR/bin" /etc/environment 2>/dev/null; then
  sed -i "s|PATH=\"|PATH=\"$SOLANA_INSTALL_DIR/bin:|" /etc/environment
  echo "   ✓ Added to /etc/environment"
fi

echo ""
echo "==> 7) Test validator..."

VERSION_OUTPUT=$($VALIDATOR_CMD --version 2>&1 || echo "could not get version")
echo "   Version: $VERSION_OUTPUT"

echo ""
echo "==> 8) Generate Validator Keypair..."
[[ -f "$KEYPAIR" ]] || solana-keygen new --no-passphrase -o "$KEYPAIR"

echo ""
echo "==> 9) Configure firewall..."
ufw --force enable
ufw allow 22
ufw allow 8000:8025/tcp
ufw allow 8000:8025/udp
ufw allow 8899   # HTTP
ufw allow 8900   # WS
ufw allow 10900  # GRPC
ufw status || true

echo ""
echo "==> 10) Copy validator configs..."
cp -f "$SCRIPT_DIR/validator.sh" "$BIN/validator.sh"
cp -f "$SCRIPT_DIR/validator-128g.sh" "$BIN/validator-128g.sh"
cp -f "$SCRIPT_DIR/validator-192g.sh" "$BIN/validator-192g.sh"
cp -f "$SCRIPT_DIR/validator-256g.sh" "$BIN/validator-256g.sh"
cp -f "$SCRIPT_DIR/validator-512g.sh" "$BIN/validator-512g.sh"
cp -f "$SCRIPT_DIR/select-validator.sh" "$BIN/select-validator.sh"
chmod +x "$BIN"/validator*.sh "$BIN/select-validator.sh"

TOTAL_MEM_GB=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo)
if [[ $TOTAL_MEM_GB -lt 160 ]]; then
  echo "   ✓ ${TOTAL_MEM_GB}GB RAM detected - using TIER 1 (128GB) config"
elif [[ $TOTAL_MEM_GB -lt 224 ]]; then
  echo "   ✓ ${TOTAL_MEM_GB}GB RAM detected - using TIER 2 (192GB) config"
elif [[ $TOTAL_MEM_GB -lt 384 ]]; then
  echo "   ✓ ${TOTAL_MEM_GB}GB RAM detected - using TIER 3 (256GB) config"
else
  echo "   ✓ ${TOTAL_MEM_GB}GB RAM detected - using TIER 4 (512GB+) config"
fi

echo ""
echo "==> 11) Configure systemd service..."
cp -f "$SCRIPT_DIR/sol.service" /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload
echo "   ✓ systemd service updated"

echo ""
echo "==> 12) Download Yellowstone gRPC geyser..."
cd "$BIN"
wget -q --show-progress "$YELLOWSTONE_TARBALL_URL" -O yellowstone-grpc-geyser.tar.bz2
tar -xjf yellowstone-grpc-geyser.tar.bz2
cp -f "$SCRIPT_DIR/yellowstone-config.json" "$GEYSER_CFG"
echo "   ✓ Yellowstone geyser configured"

echo ""
echo "==> 13) Copy helper scripts..."
cp -f "$SCRIPT_DIR/redo_node.sh"         /root/redo_node.sh
cp -f "$SCRIPT_DIR/restart_node.sh"      /root/restart_node.sh
cp -f "$SCRIPT_DIR/get_health.sh"        /root/get_health.sh
cp -f "$SCRIPT_DIR/catchup.sh"           /root/catchup.sh
cp -f "$SCRIPT_DIR/performance-monitor.sh" /root/performance-monitor.sh
chmod +x /root/*.sh
echo "   ✓ Helper scripts copied"

echo ""
echo "==> 14) Enable service on boot..."
systemctl enable "${SERVICE_NAME}"

echo ""
echo "==> 15) Clean build dir..."
cd /root
rm -rf "$BUILD_DIR"
echo "   ✓ Build dir cleaned"

echo ""
echo "============================================"
echo "✅ Jito Solana Validator build and install complete!"
echo "============================================"
echo ""
echo "Version: ${JITO_TAG}"
echo "Validator: $VALIDATOR_CMD"
echo "Install path: $SOLANA_INSTALL_DIR"
echo ""
echo "Next steps:"
echo ""
echo "1. Verify install:"
echo "   source /etc/profile.d/solana.sh"
echo "   $VALIDATOR_CMD --version"
echo ""
echo "2. Download snapshot and start node:"
echo "   cd $SCRIPT_DIR"
echo "   bash 3-start.sh"
echo ""
