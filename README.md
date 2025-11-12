<div align="center">
    <h1>⚡ Solana RPC Install</h1>
    <h3><em>Production-ready Solana RPC node deployment in 3 simple steps</em></h3>
</div>

<p align="center">
    <strong>Deploy battle-tested Solana RPC nodes with stable, proven configurations and source compilation from GitHub.</strong>
</p>

<p align="center">
    <a href="https://github.com/0xfnzero/solana-rpc-install/releases">
        <img src="https://img.shields.io/github/v/release/0xfnzero/solana-rpc-install?style=flat-square" alt="Release">
    </a>
    <a href="https://github.com/0xfnzero/solana-rpc-install/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License">
    </a>
    <a href="https://github.com/0xfnzero/solana-rpc-install">
        <img src="https://img.shields.io/github/stars/0xfnzero/solana-rpc-install?style=social" alt="GitHub stars">
    </a>
    <a href="https://github.com/0xfnzero/solana-rpc-install/network">
        <img src="https://img.shields.io/github/forks/0xfnzero/solana-rpc-install?style=social" alt="GitHub forks">
    </a>
</p>

<p align="center">
    <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash">
    <img src="https://img.shields.io/badge/Solana-9945FF?style=for-the-badge&logo=solana&logoColor=white" alt="Solana">
    <img src="https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
    <img src="https://img.shields.io/badge/RPC-00D8FF?style=for-the-badge&logo=buffer&logoColor=white" alt="RPC Node">
</p>

<p align="center">
    <a href="README_CN.md">中文</a> |
    <a href="README.md">English</a> |
    <a href="https://fnzero.dev/">Website</a> |
    <a href="https://t.me/fnzero_group">Telegram</a> |
    <a href="https://discord.gg/vuazbGkqQE">Discord</a>
</p>

---

## 🎯 System Requirements

**Minimum Configuration:**
- **CPU**: AMD Ryzen 9 9950X (or equivalent)
- **RAM**: 192 GB minimum (256 GB recommended)
- **Storage**: 2-3x NVMe SSDs (1TB system + 2TB accounts OR combined 2TB+ accounts/ledger)
- **OS**: Ubuntu 20.04/22.04
- **Network**: High-bandwidth connection (1 Gbps+)

## 🚀 Quick Start

```bash
# Switch to root user
sudo su -

# Clone repository to /root
cd /root
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# Step 1: Mount disks + System optimization (no reboot needed)
bash 1-prepare.sh

# Step 2: Install Solana from source (20-40 minutes)
bash 2-install-solana.sh
# Enter version when prompted (e.g., v3.0.10)

# Step 3: Download snapshot and start node
bash 3-start.sh
```

## ⚠️ Critical: Memory Management Details (Required for 128GB Systems)

> **📌 Why Swap Might Be Needed?**
> - **Memory peaks can exceed 128GB** during initial sync (115-130GB)
> - Without swap, node may crash with OOM
> - Swap provides safety buffer during sync phase
> - After sync stabilizes, memory usage drops to 85-105GB

### 🔧 Swap Management (Optional for 128GB Systems)

**Add Swap** (If needed during sync)

```bash
# Only if you see high memory pressure during sync
cd /root/solana-rpc-install
sudo bash add-swap-128g.sh

# Script automatically checks:
# ✓ Only adds swap if system RAM < 160GB
# ✓ Skips if swap already exists
# ✓ Adds 32GB swap with swappiness=10 (minimal usage)
```

**Remove Swap** (After sync completes)

Once synchronization completes, memory usage stabilizes at 85-105GB, and you can remove swap for optimal performance:

```bash
# Check current memory usage
systemctl status sol | grep Memory

# If memory peak < 105GB, safe to remove swap
cd /root/solana-rpc-install
sudo bash remove-swap.sh
```

### 📊 Decision Guidelines

| Memory Peak | Recommended Action |
|-------------|-------------------|
| **< 105GB** | ✅ Can remove swap for optimal performance |
| **105-110GB** | ⚠️ Recommended to keep swap as buffer |
| **> 110GB** | 🔴 Must keep swap to prevent OOM |

**Note**: If memory issues occur after removing swap, you can always add it back:
```bash
cd /root/solana-rpc-install
sudo bash add-swap-128g.sh
```

---

## 📊 Monitoring & Management

```bash
# Real-time logs
journalctl -u sol -f

# Performance monitoring
bash /root/performance-monitor.sh snapshot

# Health check (available after 30 minutes)
/root/get_health.sh

# Sync progress
/root/catchup.sh
```

## ✨ Key Features

### 🔧 Battle-Tested Configuration Philosophy

All configurations are based on **proven production deployments** with thousands of hours of uptime:

- **Conservative Stability > Aggressive Optimization**
- **Simple Defaults > Complex Customization**
- **Proven Performance > Theoretical Gains**

### 📦 System Optimizations (No Reboot Required)

- 🌐 **TCP Congestion Control**: Westwood (classic, stable algorithm)
- 🔧 **TCP Buffers**: 12MB (conservative, low-latency optimized)
- 💾 **File Descriptors**: 1M limit (sufficient for production)
- 🛡️ **Memory Management**: swappiness=30 (balanced approach)
- 🔄 **VM Settings**: Conservative dirty ratios for stability

### ⚡ Yellowstone gRPC Configuration

- ✅ **Compression Enabled**: gzip + zstd (reduces memory copy overhead)
- 📦 **Conservative Buffers**: 50M snapshot, 200K channel (fast processing)
- 🎯 **Proven Defaults**: System-managed Tokio, default HTTP/2 settings
- 🛡️ **Resource Protection**: Strict filter limits prevent abuse

### 🚀 Deployment Features

- 📦 **Source Compilation**: Latest Agave version from GitHub
- 🔄 **Automatic Disk Management**: Smart disk detection and mounting
- 🛡️ **Production Ready**: Systemd service with memory limits and OOM protection
- 📊 **Monitoring Tools**: Performance tracking and health checks included

## 🔌 Network Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| **8899** | HTTP | RPC endpoint |
| **8900** | WebSocket | Real-time subscriptions |
| **10900** | gRPC | High-performance data streaming |
| **8000-8025** | TCP/UDP | Validator communication (dynamic) |

## 📈 Performance Metrics

- **Snapshot Download**: Network-dependent (typically 200MB - 1GB/s)
- **Memory Usage**: 60-110GB during sync, 85-105GB stable (optimized for 128GB systems)
- **Sync Time**: 1-3 hours (from snapshot)
- **CPU Usage**: Multi-core optimized (32+ cores recommended)
- **Stability**: Proven configuration with >99.9% uptime in production

## 🛠️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC Node Stack                  │
├─────────────────────────────────────────────────────────┤
│  Agave Validator (Latest v3.0.x from source)            │
│  ├─ Yellowstone gRPC Plugin v10.0.1 (Data streaming)   │
│  ├─ RPC HTTP/WebSocket (Port 8899/8900)                 │
│  └─ Accounts & Ledger (Optimized RocksDB)               │
├─────────────────────────────────────────────────────────┤
│  System Optimizations (Battle-Tested)                   │
│  ├─ TCP: 12MB buffers, Westwood congestion control      │
│  ├─ Memory: swappiness=30, balanced VM settings         │
│  ├─ File Descriptors: 1M limit, sufficient for prod     │
│  └─ Stability: Conservative defaults, proven in prod    │
├─────────────────────────────────────────────────────────┤
│  Yellowstone gRPC (Open-Source Tested Config)           │
│  ├─ Compression: gzip+zstd enabled (fast processing)    │
│  ├─ Buffers: 50M snapshot, 200K channel (low latency)   │
│  ├─ Defaults: System-managed, no over-optimization      │
│  └─ Protection: Strict filters, resource limits         │
├─────────────────────────────────────────────────────────┤
│  Infrastructure                                          │
│  ├─ Systemd Service (Auto-restart, graceful shutdown)   │
│  ├─ Multi-disk Setup (System/Accounts/Ledger)           │
│  └─ Monitoring Tools (Performance/Health/Catchup)       │
└─────────────────────────────────────────────────────────┘
```

## 🧪 Configuration Philosophy

### Why Conservative Configuration?

Based on extensive production testing, we discovered:

1. **Compression Enabled = Lower Latency**
   - Even on localhost, compressed data transfers faster in memory
   - CPU overhead is minimal, latency reduction is significant

2. **Smaller Buffers = Faster Processing**
   - 50M snapshot vs 250M: Less queue delay, faster throughput
   - 200K channel vs 1.5M: Reduced "buffer bloat" latency

3. **System Defaults = Better Stability**
   - No custom Tokio threads: Let system auto-manage
   - No custom HTTP/2 settings: Defaults are already optimized
   - Fewer custom parameters = Fewer potential issues

4. **Proven in Production**
   - Thousands of hours of uptime
   - Tested across different hardware configurations
   - Battle-tested under real-world load

### 📚 Backup Configuration

If you need the aggressive optimization config for specific use cases:
- Extreme config backed up as `yellowstone-config-extreme-backup.json`
- Accessible in repository history (commit 6cc31d9)

## 📚 Documentation

- **Installation Guide**: You're reading it!
- **Troubleshooting**: Check logs with `journalctl -u sol -f`
- **Configuration**: All optimizations included by default
- **Monitoring**: Use provided helper scripts
- **Optimization Details**: See `YELLOWSTONE_OPTIMIZATION.md`

## 🤝 Support & Community

- **Telegram**: [https://t.me/fnzero_group](https://t.me/fnzero_group)
- **Discord**: [https://discord.gg/vuazbGkqQE](https://discord.gg/vuazbGkqQE)
- **Issues**: [GitHub Issues](https://github.com/0xfnzero/solana-rpc-install/issues)
- **Website**: [https://fnzero.dev/](https://fnzero.dev/)

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
    <p>
        <strong>⭐ If this project helps you, please give us a Star!</strong>
    </p>
    <p>
        Made with ❤️ by <a href="https://github.com/0xfnzero">fnzero</a>
    </p>
</div>
