<div align="center">
    <h1>⚡ Solana RPC Install</h1>
    <h3><em>三步部署生产级 Solana RPC 节点</em></h3>
</div>

<p align="center">
    <strong>部署高度优化的 Solana RPC 节点，极限网络性能（500MB-2GB/s），自动化磁盘管理，GitHub源码编译。</strong>
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

## 🎯 系统要求

**最低配置：**
- **CPU**: AMD Ryzen 9 9950X (或同等性能)
- **内存**: 最低 192 GB (推荐 256 GB)
- **存储**: 2-3块 NVMe SSD (1TB系统 + 2TB账户 或 合并的2TB+账户/账本)
- **系统**: Ubuntu 20.04/22.04
- **网络**: 高带宽连接 (1 Gbps+)

## 🚀 快速开始

```bash
# 切换到 root 用户
sudo su -

# 克隆仓库到 /root 目录
cd /root
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# 步骤1: 挂载磁盘 + 系统优化
bash 1-prepare.sh

# 步骤2: 从源码安装 Solana (20-40分钟)
bash 2-install-solana.sh
# 提示时输入版本号 (例如: v3.0.10)

# 步骤3: 重启系统
reboot

# ⚠️ 步骤3.5: 重启后，如果系统RAM < 160GB，必须先添加swap
cd /root/solana-rpc-install
sudo bash add-swap-128g.sh
# （仅在RAM < 160GB时添加，否则自动跳过）

# 步骤4: 下载快照并启动节点
bash 3-start.sh
```

## ⚠️ 重要：内存管理详解 (128GB 系统必读)

> **📌 为什么需要 Swap？**
> - **实际内存峰值会超过128GB**（可达 115-130GB）
> - 没有swap会导致OOM崩溃，节点无法运行
> - Swap不会自动添加，需要在步骤3.5手动执行
> - 添加swap后总可用内存: 123GB RAM + 32GB Swap = 155GB

### 🔧 Swap 管理详细说明

**添加 Swap** (已包含在快速开始的步骤3.5中)

```bash
# 在步骤3 reboot之后立即执行
cd /root/solana-rpc-install
sudo bash add-swap-128g.sh

# 脚本会自动检测：
# ✓ 仅在系统 RAM < 160GB 时添加 swap
# ✓ 如果已存在 swap 会跳过
# ✓ 添加 32GB swap，swappiness=10（最小化使用）
```

**移除 Swap** (同步完成后，可选操作)

同步完成后，内存使用会降低到 85-105GB，此时可以移除 swap 以获得最佳性能：

```bash
# 检查内存使用情况
systemctl status sol | grep Memory

# 如果内存峰值 < 105GB，可以安全移除 swap
cd /root/solana-rpc-install
sudo bash remove-swap.sh
```

### 📊 判断标准

| 内存峰值 | 建议操作 |
|---------|---------|
| **< 105GB** | ✅ 可以移除 swap，性能最优 |
| **105-110GB** | ⚠️ 建议保留 swap 作为缓冲 |
| **> 110GB** | 🔴 必须保留 swap，避免 OOM |

**注意**: 如果移除 swap 后出现内存不足，可以随时重新添加：
```bash
cd /root/solana-rpc-install
sudo bash add-swap-128g.sh
```

---

## 📊 监控与管理

```bash
# 实时日志
journalctl -u sol -f

# 性能监控
bash /root/performance-monitor.sh snapshot

# 健康检查 (30分钟后可用)
/root/get_health.sh

# 同步进度
/root/catchup.sh
```

## ✨ 核心特性

- ⚡ **极限网络优化**: 500MB-2GB/s 快照下载速度
- 🔧 **TCP 缓冲区**: 512MB (极限性能)
- 💾 **磁盘预读**: 32MB (优化顺序读取)
- 🌐 **网络预算**: 150,000 (极限吞吐量)
- 🚄 **BBR 拥塞控制**: 针对高延迟网络优化
- 📦 **源码编译**: GitHub 最新 Agave 版本
- 🔄 **自动磁盘管理**: 智能磁盘检测和挂载
- 🛡️ **生产就绪**: Systemd 服务，内存限制和 OOM 保护

## 🔌 网络端口

| 端口 | 协议 | 用途 |
|------|------|------|
| **8899** | HTTP | RPC 端点 |
| **8900** | WebSocket | 实时订阅 |
| **10900** | gRPC | 高性能数据流 |
| **8000-8025** | TCP/UDP | 验证者通信 (动态) |

## 📈 性能指标

- **快照下载**: 500MB - 2GB/s (极限优化)
- **内存使用**: 60-110GB (针对 128GB 系统优化)
- **同步时间**: 1-3 小时 (从快照开始)
- **CPU 使用**: 多核优化 (推荐 32+ 核心)

## 🛠️ 架构说明

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC 节点堆栈                     │
├─────────────────────────────────────────────────────────┤
│  Agave 验证者 (最新 v3.0.x 源码版本)                      │
│  ├─ Yellowstone gRPC 插件 (数据流)                       │
│  ├─ RPC HTTP/WebSocket (端口 8899/8900)                 │
│  └─ 账户 & 账本 (优化的 RocksDB)                         │
├─────────────────────────────────────────────────────────┤
│  系统优化                                                 │
│  ├─ TCP: 512MB 缓冲区, BBR 拥塞控制                      │
│  ├─ 磁盘: 32MB 预读, mq-deadline 调度器                  │
│  ├─ 网络: 250k 队列, 150k 预算                          │
│  └─ 内存: OOM 保护, 110GB 高水位线                       │
├─────────────────────────────────────────────────────────┤
│  基础设施                                                 │
│  ├─ Systemd 服务 (自动重启, 优雅关闭)                    │
│  ├─ 多磁盘配置 (系统/账户/账本)                          │
│  └─ 监控工具 (性能/健康/追块)                            │
└─────────────────────────────────────────────────────────┘
```

## 📚 文档资源

- **安装指南**: 您正在阅读！
- **故障排除**: 使用 `journalctl -u sol -f` 查看日志
- **性能调优**: 默认已包含所有优化
- **监控**: 使用提供的辅助脚本

## 🤝 支持与社区

- **Telegram 群组**: [https://t.me/fnzero_group](https://t.me/fnzero_group)
- **Discord 服务器**: [https://discord.gg/vuazbGkqQE](https://discord.gg/vuazbGkqQE)
- **问题反馈**: [GitHub Issues](https://github.com/0xfnzero/solana-rpc-install/issues)
- **官方网站**: [https://fnzero.dev/](https://fnzero.dev/)

## 📜 开源协议

本项目采用 MIT 协议开源 - 详见 [LICENSE](LICENSE) 文件。

---

<div align="center">
    <p>
        <strong>⭐ 如果这个项目对您有帮助，请给我们一个 Star！</strong>
    </p>
    <p>
        Made with ❤️ by <a href="https://github.com/0xfnzero">fnzero</a>
    </p>
</div>
