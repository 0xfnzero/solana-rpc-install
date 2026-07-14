<div align="center">
    <h1>⚡ Solana RPC Install</h1>
    <h3><em>三步部署生产级 Solana RPC 节点</em></h3>
</div>

<p align="center">
    <strong>使用稳定、经过验证的配置部署久经考验的 Solana RPC 节点，支持 GitHub 源码编译和 Jito 预编译版本。</strong>
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

## 这个项目适合什么场景

`solana-rpc-install` 是一个面向 Ubuntu 服务器的 Solana RPC 节点安装工具，覆盖 Jito Solana / Agave validator、Yellowstone gRPC、systemd 服务管理、NVMe 磁盘挂载、快照启动和生产环境 Linux 参数优化。

它适合需要部署 Solana mainnet RPC 的开发者和节点运维人员，常见用途包括交易机器人、链上数据索引、DEX 事件流、MEV 基础设施、私有 RPC 服务，以及需要快速复现稳定节点配置的测试环境。

## 脚本索引

| 脚本 | 用途 |
|------|------|
| `1-prepare.sh` | 挂载 NVMe 数据盘、创建 Solana 目录并应用 Linux 系统优化 |
| `2-install-jito-validator.sh` | 从源码构建并安装 Jito Solana / Agave validator |
| `3-start.sh` | 下载快照、安装 systemd 服务并启动 RPC 节点 |
| `validator.sh` | 根据 128GB、192GB、256GB、512GB+ 内存自动选择 validator 配置 |
| `yellowstone-config.json` | 经过生产测试的 Yellowstone gRPC Geyser 配置 |
| `performance-monitor.sh`, `get_health.sh`, `catchup.sh` | 查看节点健康状态、内存、性能和同步进度 |
| `update-runtime.sh` | 不删除节点数据，更新运行参数和监控脚本 |
| `logrotate-solana-rpc` | 轮转并压缩 validator 和监控日志 |

## 🎯 系统要求

**最低配置：**
- **CPU**: AMD Ryzen 9 9950X (或同等性能)
- **内存**: 128 GB 最低 (推荐 256 GB)
- **存储**: 1-3块 NVMe SSD (灵活配置，脚本自动适配)
  - **1块盘**: 仅系统盘 (基础配置)
  - **2块盘**: 系统盘 + 1块数据盘 (推荐，性价比最高)
  - **3块盘**: 系统盘 + 2块数据盘 (最优性能)
  - **4+块盘**: 系统盘 + 3块数据盘 (accounts/ledger/snapshot 完全隔离)
- **系统**: Ubuntu 22.04/24.04

> **128GB/192GB 适用范围：** 这两档是使用磁盘后备 accounts index 的受限 RPC 配置，仅为 Address Lookup Table 程序建立索引，不适合开启全部账户索引；全量账户索引需要明显更大的内存。
- **网络**: 高带宽连接 (1 Gbps+)

## 🚀 快速开始

**三步安装**

```bash
# 切换到 root 用户
sudo su -

# 克隆仓库到 /root 目录
cd /root
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# 步骤 1: 挂载磁盘 + 系统优化
bash 1-prepare.sh

# (可选) 验证挂载配置
bash verify-mounts.sh

# 步骤 2: 从源码构建 Jito Solana (15-30 分钟)
bash 2-install-jito-validator.sh
# 直接回车安装 v4.1.1，或输入指定版本 (例如: v4.1.0-rc.1)
# 支持 stable、rc、beta 等 Jito 标签

# 步骤 3: 下载快照并启动节点
bash 3-start.sh
```

> **ℹ️ 安装方式**
> 本安装使用 **GitHub 源码编译** 方式构建 Jito Solana 验证节点。这确保您获得完整的 `agave-validator` 二进制文件和 RPC 节点所需的完整 MEV 支持。

## ⚠️ 重要：内存管理详解 (128GB 系统必读)

Agave 内存占用取决于具体版本、账户索引、RPC 流量和 Geyser 订阅，不能继续使用旧版本的固定 GB 数值判断。针对社区常见的 128GB 和 192GB 节点，服务不设置 `MemoryHigh` 软限流，避免 cgroup 强回收拖慢 replay；仅保留 `MemoryMax=95%` 作为主机失控时的最后保护。

### 🔧 Swap 管理 (128GB 系统可选)

**添加 Swap** (同步期间内存压力大时)

```bash
# 仅当同步期间内存压力大时使用
cd /root/solana-rpc-install
sudo bash add-swap-128g.sh

# 脚本会自动检测：
# ✓ 仅在系统 RAM < 160GB 时添加 swap
# ✓ 如果已存在 swap 会自动跳过
# ✓ 添加 32GB swap，swappiness=10（最小化使用）
```

**同步后评估 Swap**

至少稳定运行 24 小时后，检查服务峰值和 Linux 内存压力：

```bash
# 检查当前内存使用
cat /proc/pressure/memory
bash /root/performance-monitor.sh snapshot
```

监控脚本会在 Ubuntu 22.04 直接读取 `memory.peak`，在 Ubuntu 24.04 使用 systemd 属性。只有在峰值持续明显低于 `MemoryMax`、swap 未被使用且内存没有持续压力时，才应考虑移除 swap。

---

## 🚀 下一步：安装 Jito ShredStream

完成 RPC 节点安装后，您可以通过 Jito ShredStream 进一步提升性能：

- **快速开始指南**: [QUICK_START_CN.md](https://github.com/0xfnzero/jito-shredstream-install/blob/main/QUICK_START_CN.md)
- **项目仓库**: [jito-shredstream-install](https://github.com/0xfnzero/jito-shredstream-install)

ShredStream 为 Jito MEV 基础设施提供低延迟的区块流传输。

## 📊 监控与管理

```bash
# 持续查看 Agave validator 的真实运行日志
bash /root/performance-monitor.sh logs

# 持续查看 systemd 启动和重启日志
bash /root/performance-monitor.sh journal

# 性能监控
bash /root/performance-monitor.sh snapshot

# 完整诊断报告（打印并保存到 /var/log）
bash /root/performance-monitor.sh diagnose

# 持续打印指标并写入 /var/log/solana-performance.log
bash /root/performance-monitor.sh monitor

# 健康检查 (30分钟后可用)
/root/get_health.sh

# 同步进度
/root/catchup.sh
```

日志位置和保留策略：

- Validator 运行日志：`/root/solana-rpc.log`
- 持续监控指标：`/var/log/solana-performance.log`
- 完整诊断报告：`/var/log/solana-diagnostic-YYYYMMDD-HHMMSS.log`
- Validator 和监控日志每天轮转、压缩，并保留 7 份。

在不清理节点数据的情况下更新现有节点：

```bash
sudo bash update-runtime.sh
# 在维护窗口重启，以启用 validator 和内存参数
sudo bash update-runtime.sh --restart
```

## ✨ 核心特性

### 🔧 久经考验的配置理念

所有配置基于**经过验证的生产部署**，拥有数千小时的正常运行时间：

- **保守稳定 > 激进优化**
- **简单默认 > 复杂定制**
- **经过验证的性能 > 理论收益**

### 📦 系统优化

- 🌐 **TCP 拥塞控制**: Westwood (经典、稳定的算法)
- 🔧 **TCP 缓冲区**: 12MB (保守、低延迟优化)
- 💾 **文件描述符**: 1M 限制 (生产环境足够)
- 🛡️ **内存管理**: swappiness=30 (平衡方式)
- 🔄 **VM 设置**: 保守的脏页比率，确保稳定性

### ⚡ Yellowstone gRPC 配置

- ✅ **启用压缩**: gzip + zstd (减少内存拷贝开销)
- 📦 **保守缓冲区**: 50M 快照, 200K 通道 (快速处理)
- 🎯 **经过验证的默认值**: 系统管理的 Tokio，默认 HTTP/2 设置
- 🛡️ **资源保护**: 严格的过滤器限制防止滥用

### 🚀 部署特性

- 📦 **源码编译安装**:
  - 🔧 从官方 GitHub 构建 Jito Solana (15-30 分钟)
  - ✅ 完整的 validator 二进制文件和完整 MEV 支持
  - 🎯 100% 符合 Jito Foundation 官方标准
- 🧠 **智能配置选择**: 自动检测系统 RAM 并选择最优 validator 配置
  - TIER 1 (128GB): 保守配置，适用于 128-159GB 系统
  - TIER 2 (192GB): 平衡配置，适用于 192-223GB 系统
  - TIER 3 (256GB): 高性能配置，适用于 256-383GB 系统
  - TIER 4 (512GB+): 最大容量配置，适用于企业级部署
- 🔄 **自动磁盘管理**: 智能磁盘检测和挂载
- 🛡️ **生产就绪**: Systemd 服务，主机内存最后保护和 OOM 诊断
- 🌐 **网络容错**: 增强版本验证，优雅处理网络问题
- 📊 **监控工具**: 包含性能跟踪和健康检查
- 📸 **只加载快照**: 使用下载的归档启动，不再持续生成完整快照

## 🔌 网络端口

| 端口 | 协议 | 用途 |
|------|------|------|
| **8899** | HTTP | RPC 端点 |
| **8900** | WebSocket | 实时订阅 |
| **10900** | gRPC | 高性能数据流 |
| **8000-8030** | TCP/UDP | 验证者通信 (动态) |

## 📈 性能指标

- **快照下载**: 取决于网络 (通常 200MB - 1GB/s)
- **内存保护**: 不设置影响延迟的软限流，95% 为主机最后保护
- **同步时间**: 1-3 小时 (从快照开始)
- **CPU 使用**: 多核优化 (推荐 32+ 核心)
- **稳定性**: 经过验证的配置，生产环境正常运行时间 >99.9%

## 🛠️ 架构说明

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC 节点堆栈                     │
├─────────────────────────────────────────────────────────┤
│  Jito Solana 验证者 (v4.1.x)                            │
│  ├─ 安装方式: 从 GitHub 源码编译                         │
│  │  • agave-validator 完整 MEV 支持                     │
│  │  • 100% 符合 Jito Foundation 标准 (15-30 分钟)      │
│  ├─ Yellowstone gRPC 自动匹配 Solana 版本               │
│  ├─ RPC HTTP/WebSocket (端口 8899/8900)                │
│  └─ 账户 & 账本 (优化的 RocksDB)                        │
├─────────────────────────────────────────────────────────┤
│  系统优化 (久经考验)                                      │
│  ├─ TCP: 12MB 缓冲区, Westwood 拥塞控制                 │
│  ├─ 内存: swappiness=30, 平衡的 VM 设置                 │
│  ├─ 文件描述符: 1M 限制, 生产环境足够                    │
│  └─ 稳定性: 保守的默认值, 生产环境验证                   │
├─────────────────────────────────────────────────────────┤
│  Yellowstone gRPC (开源测试配置)                         │
│  ├─ 压缩: 启用 gzip+zstd (快速处理)                      │
│  ├─ 缓冲区: 50M 快照, 200K 通道 (低延迟)                │
│  ├─ 默认值: 系统管理, 无过度优化                         │
│  └─ 保护: 严格过滤器, 资源限制                           │
├─────────────────────────────────────────────────────────┤
│  基础设施                                                 │
│  ├─ Systemd 服务 (自动重启, 优雅关闭)                   │
│  ├─ 多磁盘设置 (系统/账户/账本)                          │
│  └─ 监控工具 (性能/健康/同步进度)                        │
└─────────────────────────────────────────────────────────┘
```

## 🧪 配置理念

### 为什么选择保守配置？

基于大量生产测试，我们发现：

1. **启用压缩 = 更低延迟**
   - 即使在本地主机上，压缩数据在内存中传输更快
   - CPU 开销很小，延迟降低显著

2. **更小的缓冲区 = 更快的处理**
   - 50M 快照 vs 250M: 更少的队列延迟，更快的吞吐量
   - 200K 通道 vs 1.5M: 减少"缓冲区膨胀"延迟

3. **系统默认值 = 更好的稳定性**
   - 无自定义 Tokio 线程: 让系统自动管理
   - 无自定义 HTTP/2 设置: 默认值已经优化
   - 更少的自定义参数 = 更少的潜在问题

4. **生产环境验证**
   - 数千小时的正常运行时间
   - 在不同硬件配置下测试
   - 在真实负载下久经考验

### 📚 备份配置

如果您需要针对特定用例的激进优化配置：
- 极限配置已备份为 `yellowstone-config-extreme-backup.json`
- 可在仓库历史中访问 (提交 6cc31d9)

## 📚 文档资源

- **安装指南**: 您正在阅读！
- **挂载策略**: 查看 [MOUNT_STRATEGY.md](MOUNT_STRATEGY.md)
- **故障排除**: 使用 `journalctl -u sol -f` 查看日志
- **配置**: 所有优化默认包含
- **监控**: 使用提供的辅助脚本
- **优化详情**: 查看 `YELLOWSTONE_OPTIMIZATION.md`

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
