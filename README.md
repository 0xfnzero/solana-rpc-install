<div align="center">
    <h1>⚡ Solana RPC Install</h1>
    <h3><em>Production-ready Solana RPC node deployment in 3 simple steps</em></h3>
</div>

<p align="center">
    <strong>Deploy observable Solana RPC nodes with conservative configurations and source compilation from GitHub.</strong>
</p>

<p align="center">
    <a href="https://github.com/0xfnzero/solana-rpc-install/releases">
        <img src="https://img.shields.io/github/v/release/0xfnzero/solana-rpc-install?style=flat-square" alt="Release">
    </a>
    <a href="https://opensource.org/license/mit">
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
| `3-start.sh` | Reuse or download a snapshot, install systemd, and start the RPC node without deleting data by default |
| `validator.sh` | Auto-select the right validator profile for 128GB, 192GB, 256GB, or 512GB+ RAM |
| `yellowstone-config.json` | Base Yellowstone gRPC Geyser configuration |
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

**Phase 1: Prepare the server**

> `1-prepare.sh` can format eligible unmounted NVMe data disks. Verify that the
> server does not contain data you need before running it.

```bash
# Switch to root user
sudo su -

# Clone repository to /root
cd /root
git clone --branch dev --single-branch https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# Step 1: Mount disks + System optimization
bash 1-prepare.sh

# (Optional) Verify mount configuration
bash verify-mounts.sh

# Reboot to activate the host configuration
reboot
```

Reconnect over SSH after the server is back, then continue:

**Phase 2: Build and start the node**

```bash
sudo su -
cd /root/solana-rpc-install

# Step 2: Build Jito Solana from source with native CPU + LTO optimizations
bash 2-install-jito-validator.sh
# Press Enter to install the tested stable v4.2.1, or enter another existing Jito tag
# Supports stable, rc, and beta Jito tags

# Step 3: Download snapshot and start node
bash 3-start.sh
```

Re-running `3-start.sh` preserves ledger, accounts, and snapshots. A complete
snapshot is reused instead of downloaded again. To intentionally discard node
data and perform a fresh synchronization, use the explicit destructive mode:

```bash
bash 3-start.sh --fresh-sync
# The script requires typing FRESH-SYNC before it deletes any node data.
```

> **ℹ️ Installation Method**
> This installation uses **source compilation from GitHub** to build Jito Solana validator. This ensures you get the complete `agave-validator` binary with full MEV support required for RPC nodes.

## ⚠️ Critical: Memory Management Details (Required for 128GB Systems)

Agave memory usage depends on the release, account index, RPC traffic, and
Geyser subscriptions. Do not use a fixed GB threshold from an older release.
For the common 128GB and 192GB deployments, the service does not configure a
`MemoryHigh` throttle: replay latency must not be degraded by aggressive cgroup
reclaim. `MemoryMax=90%` is retained only as a last-resort host safeguard,
leaving at least 10% of RAM for the kernel, filesystem cache, SSH, and monitoring.

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

# The snapshot includes the busiest Agave threads and CPU/memory/I/O pressure
# Look for sustained solAcctsDbBg*, rocksdb:*, or solPohTickProd usage

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
- Diagnostic reports older than 7 days are removed when a new report is created.

## Updating An Existing Node

Run the update during a maintenance window. First update the local checkout to
the remote `dev` branch; the explicit fetch also works for single-branch clones:

```bash
cd /root/solana-rpc-install
git fetch origin dev:refs/remotes/origin/dev
git switch dev 2>/dev/null || git switch --track -c dev origin/dev
git pull --ff-only origin dev

# Check the installed validator version
/usr/local/solana/bin/agave-validator --version
```

If the node already runs `v4.2.1-jito` (or the same major line), update only the
host and runtime configuration:

```bash
sudo bash system-optimize.sh
sudo bash update-runtime.sh --restart
```

> **v4.2 note**: Agave/Jito v4.2+ enables XDP by default and requires
> `--no-xdp` together with `--allow-private-addr`. It also renamed
> `--accounts-db-cache-limit-mb` to `--accounts-db-write-cache-limit` and removed
> `--accounts-db-access-storages-method`. The launcher probes the installed
> binary and applies the correct flags automatically, but only after the runtime
> scripts are synced — otherwise the node crash-loops. Always run
> `update-runtime.sh` above after an upgrade.
>
> **v4.3 (upcoming)**: `--limit-ledger-size` will be deprecated in favor of
> `--limit-blockstore-size`. The launcher keeps the current flag for v4.2 and
> will switch when v4.3 lands.

If the node runs `v4.1.x-jito` or an older release, build the tested release
first. The final restart briefly interrupts RPC service:

```bash
# Press Enter at the version prompt to select v4.2.1.
# nice reduces build contention with a validator that is still running.
sudo nice -n 10 bash 2-install-jito-validator.sh
sudo bash system-optimize.sh
sudo bash update-runtime.sh --restart
```

`system-optimize.sh` disables swap. A 128GB operator who intentionally needs the
optional swapfile should run `sudo bash add-swap-128g.sh` after system optimization.
Neither upgrade path deletes ledger, accounts, or snapshots; do not run
`3-start.sh --fresh-sync` for a normal update.

## ✨ Key Features

### 🔧 Configuration Philosophy

The defaults prioritize 128GB/192GB stability, upstream compatibility, and diagnostics:

- **Conservative Stability > Aggressive Optimization**
- **Simple Defaults > Complex Customization**
- **Measured Performance > Theoretical Gains**

### 📦 System Optimizations (No Reboot Required)

- 🌐 **Socket Buffer Maximum**: 128MB, matching the Anza validator baseline
- 💾 **File Descriptors**: 1M limit and 2GB memlock limit
- 🔄 **Bounded Writeback**: 512MB background and 2GB hard dirty-memory limits
- ⚡ **CPU Policy**: Persistent performance governor, EPP performance, and turbo
- 🧠 **Memory Latency**: Transparent Huge Pages disabled at runtime
- 🌐 **NIC Rings**: Raised to each detected interface's advertised maximum
- 🛡️ **Conservative Scope**: No SMT, C-state, IRQ affinity, kernel, or GRUB changes

### ⚡ Yellowstone gRPC Configuration

- ✅ **Compression Available**: Clients can negotiate gzip or zstd when bandwidth savings justify CPU cost
- 📦 **Profile Buffers**: 50K channel/128 unary on 128GB; 100K/256 on 192GB
- 🎯 **Upstream Defaults**: System-managed Tokio and default HTTP/2 settings
- 🛡️ **Resource Protection**: Bounded filter/request counts; authentication remains optional

The launcher generates the profile-specific queue limits under `/run/solana-rpc`
without modifying `yellowstone-config.json`. Advanced operators can set
`GEYSER_CONFIG=/path/to/custom.json` to bypass generation. The optional
`ENABLE_GEYSER=0`, `ENABLE_ALT_INDEX=0`, and `ENABLE_TX_HISTORY=0` environment
variables disable individual workloads while keeping the default installation
fully compatible.

### 🚀 Deployment Features

- 📦 **Source Compilation Installation**:
  - 🔧 Jito Solana from official GitHub (typically 30-90 min with LTO)
  - ⚡ Native CPU instructions and Jito's release-with-LTO build profile
  - ✅ Complete validator binary with full MEV support
  - 🎯 Built from a verified Jito release tag and recorded source commit
- 🧠 **Intelligent Configuration Selection**: Auto-detects system RAM and selects optimal validator configuration
  - TIER 1 (128GB): Conservative settings for 128-159GB systems
  - TIER 2 (192GB): Balanced configuration for 192-223GB systems
  - TIER 3 (256GB): High-performance for 256-383GB systems
  - TIER 4 (512GB+): Maximum capacity for enterprise deployments
- 🔄 **Automatic Disk Management**: Smart disk detection and mounting
- 🛡️ **Production Ready**: Systemd service with a 90% last-resort host memory safeguard and OOM diagnostics
- 🌐 **Network Resilience**: Enhanced version verification with graceful degradation
- 📊 **Monitoring Tools**: Performance tracking and health checks included
- 📸 **Load-only Snapshots**: Bootstrap from downloaded archives without continuously generating full snapshots

## 🔌 Network Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| **8899** | HTTP | RPC endpoint |
| **8900** | WebSocket | Real-time subscriptions |
| **10900** | gRPC | High-performance data streaming; open by default for compatibility |
| **8000-8030** | TCP/UDP | Validator communication (dynamic) |

The installer does not require a gRPC token, so existing clients continue to
work without additional metadata. Operators with a fixed client IP can
optionally restrict port 10900:

```bash
ufw delete allow 10900
ufw allow from CLIENT_PUBLIC_IP to any port 10900 proto tcp
ufw deny 10900/tcp
ufw status numbered
```

An IP allowlist is simple for fixed servers but must be updated whenever the
client's public IP changes. Token authentication is more flexible for roaming
clients, but every client must be configured to send the token, so it is not
enabled automatically.

## 📈 Performance Metrics

- **Snapshot Download**: Network-dependent (typically 200MB - 1GB/s)
- **Memory Protection**: No latency-inducing soft throttle; 90% hard host safeguard
- **Sync Time**: 1-3 hours (from snapshot)
- **CPU Usage**: Multi-core optimized (32+ cores recommended)
- **Stability**: Conservative defaults with cgroup, pressure, disk, and thread diagnostics

## 🛠️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC Node Stack                  │
├─────────────────────────────────────────────────────────┤
│  Jito Solana Validator (v4.2.x)                         │
│  ├─ Installation: Source compilation from GitHub        │
│  │  • agave-validator with full MEV support             │
│  │  • Native CPU + release-with-LTO build               │
│  ├─ Yellowstone gRPC auto-matched to Solana version     │
│  ├─ RPC HTTP/WebSocket (Port 8899/8900)                 │
│  └─ Accounts & Ledger (Optimized RocksDB)               │
├─────────────────────────────────────────────────────────┤
│  System Optimizations (Conservative)                    │
│  ├─ Network: Anza 128MB socket maximum                  │
│  ├─ Memory: bounded dirty writeback, THP disabled       │
│  ├─ File Descriptors: 1M limit, sufficient for prod     │
│  └─ Stability: Conservative defaults + diagnostics      │
├─────────────────────────────────────────────────────────┤
│  Yellowstone gRPC (Open-Source Tested Config)           │
│  ├─ Compression: gzip+zstd enabled (fast processing)    │
│  ├─ Buffers: 50K/128 (128GB), 100K/256 (192GB)         │
│  ├─ Defaults: System-managed, no over-optimization      │
│  └─ Protection: Filter and request limits               │
├─────────────────────────────────────────────────────────┤
│  Infrastructure                                          │
│  ├─ Systemd Service (Auto-restart, graceful shutdown)   │
│  ├─ Multi-disk Setup (System/Accounts/Ledger)           │
│  └─ Monitoring Tools (Performance/Health/Catchup)       │
└─────────────────────────────────────────────────────────┘
```

## 🧪 Configuration Philosophy

### Why Conservative Configuration?

1. **Compression is a tradeoff**
   - gzip and zstd can reduce network bandwidth.
   - Compression consumes CPU, so clients should benchmark it for their traffic.

2. **Queues are bounded per profile**
   - 128GB nodes use a 50K per-connection channel; 192GB nodes use 100K.
   - A slow consumer may lag or reconnect instead of consuming unbounded node memory.

3. **Leave unrelated runtime controls at upstream defaults**
   - Tokio and HTTP/2 thread/window settings are not overridden.
   - SMT, C-states, IRQ affinity, kernel versions, and GRUB are not changed.

4. **Measure before changing limits**
   - Use `performance-monitor.sh snapshot` for thread and pressure data.
   - Use `performance-monitor.sh diagnose` before reporting a restart or sync issue.

## 📚 Documentation

- **Installation Guide**: You're reading it!
- **Mount Validation**: Run `sudo bash verify-mounts.sh`
- **Troubleshooting**: Check logs with `journalctl -u sol -f`
- **Configuration**: All optimizations included by default
- **Monitoring**: Use provided helper scripts
- **Optimization Details**: See the System Optimizations and Yellowstone sections above

## 🤝 Support & Community

- **Telegram**: [https://t.me/fnzero_group](https://t.me/fnzero_group)
- **Discord**: [https://discord.gg/vuazbGkqQE](https://discord.gg/vuazbGkqQE)
- **Issues**: [GitHub Issues](https://github.com/0xfnzero/solana-rpc-install/issues)
- **Website**: [https://fnzero.dev/](https://fnzero.dev/)

## 📜 License

This project is distributed under the [MIT License](https://opensource.org/license/mit).

---

<div align="center">
    <p>
        <strong>⭐ If this project helps you, please give us a Star!</strong>
    </p>
    <p>
        Made with ❤️ by <a href="https://github.com/0xfnzero">fnzero</a>
    </p>
</div>
