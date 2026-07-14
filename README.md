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

## What This Project Provides

`solana-rpc-install` is a focused installer for running a Solana RPC node on Ubuntu with Jito Solana / Agave validator, Yellowstone gRPC, systemd service management, NVMe disk mounting, snapshot bootstrap, and production-oriented Linux tuning.

It is built for operators who need a practical Solana mainnet RPC deployment guide for trading bots, indexing pipelines, DEX event streaming, MEV infrastructure, or private RPC workloads without hand-assembling every validator, Geyser, storage, and monitoring setting.

## Included Scripts

| Script | Purpose |
|--------|---------|
| `1-prepare.sh` | Mount NVMe data disks, create Solana directories, and apply Linux system optimizations |
| `2-install-jito-validator.sh` | Build and install Jito Solana / Agave validator from source |
| `3-start.sh` | Download snapshots, install the systemd service, and start the RPC node |
| `validator.sh` | Auto-select the right validator profile for 128GB, 192GB, 256GB, or 512GB+ RAM |
| `yellowstone-config.json` | Production-tested Yellowstone gRPC Geyser configuration |
| `performance-monitor.sh`, `get_health.sh`, `catchup.sh` | Monitor node health, memory, performance, and sync progress |
| `update-runtime.sh` | Apply runtime and monitoring fixes without deleting node data |
| `logrotate-solana-rpc` | Rotate and compress validator and monitoring logs |

## 🎯 System Requirements

**Minimum Configuration:**
- **CPU**: AMD Ryzen 9 9950X (or equivalent)
- **RAM**: 128 GB minimum (256 GB recommended)
- **Storage**: 1-3x NVMe SSDs (flexible configuration, script auto-adapts)
  - **1 disk**: System disk only (basic setup)
  - **2 disks**: System + 1 data disk (recommended, best cost-performance)
  - **3 disks**: System + 2 data disks (optimal performance)
  - **4+ disks**: System + 3 data disks (accounts/ledger/snapshot separated)
- **OS**: Ubuntu 22.04/24.04

> **128GB/192GB scope:** These are constrained RPC profiles using a disk-backed
> accounts index and indexing only the Address Lookup Table program. They are not
> suitable for enabling every account index; Agave recommends substantially more
> memory for that workload.
- **Network**: High-bandwidth connection (1 Gbps+)

## 🚀 Quick Start

**Three-Step Installation**

```bash
# Switch to root user
sudo su -

# Clone repository to /root
cd /root
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# Step 1: Mount disks + System optimization
bash 1-prepare.sh

# (Optional) Verify mount configuration
bash verify-mounts.sh

# Step 2: Build Jito Solana from source (15-30 minutes)
bash 2-install-jito-validator.sh
# Press Enter to install v4.1.1, or enter a specific version (e.g., v4.1.0-rc.1)
# Supports stable, rc, and beta Jito tags

# Step 3: Download snapshot and start node
bash 3-start.sh
```

> **ℹ️ Installation Method**
> This installation uses **source compilation from GitHub** to build Jito Solana validator. This ensures you get the complete `agave-validator` binary with full MEV support required for RPC nodes.

## ⚠️ Critical: Memory Management Details (Required for 128GB Systems)

Agave memory usage depends on the release, account index, RPC traffic, and
Geyser subscriptions. Do not use a fixed GB threshold from an older release.
For the common 128GB and 192GB deployments, the service does not configure a
`MemoryHigh` throttle: replay latency must not be degraded by aggressive cgroup
reclaim. `MemoryMax=95%` is retained only as a last-resort host safeguard.

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

**Evaluate Swap After Sync**

Check the service peak and Linux memory pressure after at least 24 hours:

```bash
# Check current memory usage
cat /proc/pressure/memory
bash /root/performance-monitor.sh snapshot
```

The monitor reads `memory.peak` directly on Ubuntu 22.04 and uses the systemd
property on Ubuntu 24.04. Only remove swap when the reported peak remains
comfortably below `MemoryMax`, swap is unused, and memory pressure is not sustained.

---

## 🚀 Next Steps: Install Jito ShredStream

After completing your RPC node installation, you can enhance performance with Jito ShredStream:

- **Quick Start Guide**: [QUICK_START.md](https://github.com/0xfnzero/jito-shredstream-install/blob/main/QUICK_START.md)
- **Repository**: [jito-shredstream-install](https://github.com/0xfnzero/jito-shredstream-install)

ShredStream provides low-latency block streaming for Jito MEV infrastructure.

## 📊 Monitoring & Management

```bash
# Follow the actual Agave validator runtime log
bash /root/performance-monitor.sh logs

# Follow systemd startup and restart logs
bash /root/performance-monitor.sh journal

# Performance monitoring
bash /root/performance-monitor.sh snapshot

# Complete diagnostic report (prints and saves under /var/log)
bash /root/performance-monitor.sh diagnose

# Continuous metrics: prints and appends to /var/log/solana-performance.log
bash /root/performance-monitor.sh monitor

# Health check (available after 30 minutes)
/root/get_health.sh

# Sync progress
/root/catchup.sh
```

Log locations and retention:

- Validator runtime: `/root/solana-rpc.log`
- Continuous metrics: `/var/log/solana-performance.log`
- Diagnostic reports: `/var/log/solana-diagnostic-YYYYMMDD-HHMMSS.log`
- Validator and metrics logs rotate daily, are compressed, and retain 7 archives.

Apply configuration updates to an existing node without clearing its data:

```bash
sudo bash update-runtime.sh
# Restart during a maintenance window to activate validator and memory changes
sudo bash update-runtime.sh --restart
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

- 📦 **Source Compilation Installation**:
  - 🔧 Jito Solana from official GitHub (15-30 min)
  - ✅ Complete validator binary with full MEV support
  - 🎯 100% compliant with Jito Foundation standards
- 🧠 **Intelligent Configuration Selection**: Auto-detects system RAM and selects optimal validator configuration
  - TIER 1 (128GB): Conservative settings for 128-159GB systems
  - TIER 2 (192GB): Balanced configuration for 192-223GB systems
  - TIER 3 (256GB): High-performance for 256-383GB systems
  - TIER 4 (512GB+): Maximum capacity for enterprise deployments
- 🔄 **Automatic Disk Management**: Smart disk detection and mounting
- 🛡️ **Production Ready**: Systemd service with a last-resort host memory safeguard and OOM diagnostics
- 🌐 **Network Resilience**: Enhanced version verification with graceful degradation
- 📊 **Monitoring Tools**: Performance tracking and health checks included
- 📸 **Load-only Snapshots**: Bootstrap from downloaded archives without continuously generating full snapshots

## 🔌 Network Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| **8899** | HTTP | RPC endpoint |
| **8900** | WebSocket | Real-time subscriptions |
| **10900** | gRPC | High-performance data streaming |
| **8000-8030** | TCP/UDP | Validator communication (dynamic) |

## 📈 Performance Metrics

- **Snapshot Download**: Network-dependent (typically 200MB - 1GB/s)
- **Memory Protection**: No latency-inducing soft throttle; 95% hard host safeguard
- **Sync Time**: 1-3 hours (from snapshot)
- **CPU Usage**: Multi-core optimized (32+ cores recommended)
- **Stability**: Proven configuration with >99.9% uptime in production

## 🛠️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC Node Stack                  │
├─────────────────────────────────────────────────────────┤
│  Jito Solana Validator (v4.1.x)                         │
│  ├─ Installation: Source compilation from GitHub        │
│  │  • agave-validator with full MEV support             │
│  │  • 100% Jito Foundation compliant (15-30 min)        │
│  ├─ Yellowstone gRPC auto-matched to Solana version     │
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
- **Mount Strategy**: See [MOUNT_STRATEGY.md](MOUNT_STRATEGY.md)
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
