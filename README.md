<div align="center">
    <h1>⚡ Solana RPC Install</h1>
    <h3><em>Production-ready Solana RPC node deployment in 3 simple steps</em></h3>
</div>

<p align="center">
    <strong>Deploy highly optimized Solana RPC nodes with extreme network performance (500MB-2GB/s), automated disk management, and source compilation from GitHub.</strong>
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
- **Storage**: 3x NVMe SSDs (1TB system + 2TB accounts + 2TB ledger)
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

# Step 1: Mount disks + System optimization
bash 1-prepare.sh

# Step 2: Install Solana from source (20-40 minutes)
bash 2-install-solana.sh
# Enter version when prompted (e.g., v3.0.10)

# Step 3: Reboot system
reboot

# Step 4: After reboot, download snapshot and start node
bash 3-start.sh
```

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

- ⚡ **Extreme Network Optimization**: 500MB-2GB/s snapshot download speed
- 🔧 **TCP Buffers**: 512MB (maximum performance)
- 💾 **Disk Read-ahead**: 32MB (optimized for sequential reads)
- 🌐 **Network Budget**: 150,000 (extreme throughput)
- 🚄 **BBR Congestion Control**: Enabled for high-latency networks
- 📦 **Source Compilation**: Latest Agave version from GitHub
- 🔄 **Automatic Disk Management**: Smart disk detection and mounting
- 🛡️ **Production Ready**: Systemd service with memory limits and OOM protection

## 🔌 Network Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| **8899** | HTTP | RPC endpoint |
| **8900** | WebSocket | Real-time subscriptions |
| **10900** | gRPC | High-performance data streaming |
| **8000-8025** | TCP/UDP | Validator communication (dynamic) |

## 📈 Performance Metrics

- **Snapshot Download**: 500MB - 2GB/s (with extreme optimizations)
- **Memory Usage**: 60-110GB (optimized for 128GB systems)
- **Sync Time**: 1-3 hours (from snapshot)
- **CPU Usage**: Multi-core optimized (32+ cores recommended)

## 🛠️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC Node Stack                  │
├─────────────────────────────────────────────────────────┤
│  Agave Validator (Latest v3.0.x from source)            │
│  ├─ Yellowstone gRPC Plugin (Data streaming)            │
│  ├─ RPC HTTP/WebSocket (Port 8899/8900)                 │
│  └─ Accounts & Ledger (Optimized RocksDB)               │
├─────────────────────────────────────────────────────────┤
│  System Optimizations                                    │
│  ├─ TCP: 512MB buffers, BBR congestion control          │
│  ├─ Disk: 32MB read-ahead, mq-deadline scheduler        │
│  ├─ Network: 250k backlog, 150k budget                  │
│  └─ Memory: OOM protection, 110GB high watermark        │
├─────────────────────────────────────────────────────────┤
│  Infrastructure                                          │
│  ├─ Systemd Service (Auto-restart, graceful shutdown)   │
│  ├─ Multi-disk Setup (System/Accounts/Ledger)           │
│  └─ Monitoring Tools (Performance/Health/Catchup)       │
└─────────────────────────────────────────────────────────┘
```

## 📚 Documentation

- **Installation Guide**: You're reading it!
- **Troubleshooting**: Check logs with `journalctl -u sol -f`
- **Performance Tuning**: All optimizations included by default
- **Monitoring**: Use provided helper scripts

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
