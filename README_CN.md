<div align="center">
    <h1>⚡ Solana RPC Install</h1>
    <h3><em>三步部署生产级 Solana RPC 节点</em></h3>
</div>

<p align="center">
    <strong>使用保守配置、完整监控和 GitHub 源码编译部署 Solana RPC 节点。</strong>
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

## 这个项目适合什么场景

`solana-rpc-install` 是一个面向 Ubuntu 服务器的 Solana RPC 节点安装工具，覆盖 Jito Solana / Agave validator、Yellowstone gRPC、systemd 服务管理、NVMe 磁盘挂载、快照启动和生产环境 Linux 参数优化。

它适合需要部署 Solana mainnet RPC 的开发者和节点运维人员，常见用途包括交易机器人、链上数据索引、DEX 事件流、MEV 基础设施、私有 RPC 服务，以及需要快速复现稳定节点配置的测试环境。

## 脚本索引

| 脚本 | 用途 |
|------|------|
| `1-prepare.sh` | 挂载 NVMe 数据盘、创建 Solana 目录并应用 Linux 系统优化 |
| `2-install-jito-validator.sh` | 从源码构建并安装 Jito Solana / Agave validator |
| `3-start.sh` | 复用或下载快照、安装 systemd 服务并启动 RPC 节点；默认不删除数据 |
| `validator.sh` | 根据 128GB、192GB、256GB、512GB+ 内存自动选择 validator 配置 |
| `yellowstone-config.json` | Yellowstone gRPC Geyser 基础配置 |
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

**阶段一：准备服务器并重启**

> `1-prepare.sh` 可能格式化符合条件且尚未挂载的 NVMe 数据盘。执行前必须确认
> 服务器上没有需要保留的数据。

```bash
# 切换到 root 用户
sudo su -

# 克隆仓库到 /root 目录
cd /root
git clone --branch dev --single-branch https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install

# 步骤 1: 挂载磁盘 + 系统优化
bash 1-prepare.sh

# (可选) 验证挂载配置
bash verify-mounts.sh

# 重启，使主机参数完整生效
reboot
```

服务器启动后重新 SSH 登录，再继续执行：

**阶段二：编译并启动节点**

```bash
sudo su -
cd /root/solana-rpc-install

# 步骤 2: 使用原生 CPU 指令和 LTO 从源码构建 Jito Solana
bash 2-install-jito-validator.sh
# 直接回车安装已验证的稳定版 v4.2.1，也可以输入其它真实存在的 Jito 标签
# 支持 stable、rc、beta 等 Jito 标签

# 步骤 3: 下载快照并启动节点
bash 3-start.sh
```

重复运行 `3-start.sh` 会保留 ledger、accounts 和 snapshot，并复用已有完整快照。
只有明确需要删除数据并重新同步时，才执行：

```bash
bash 3-start.sh --fresh-sync
# 脚本要求再次输入 FRESH-SYNC，之后才会删除节点数据。
```

> **ℹ️ 安装方式**
> 本安装使用 **GitHub 源码编译** 方式构建 Jito Solana 验证节点。这确保您获得完整的 `agave-validator` 二进制文件和 RPC 节点所需的完整 MEV 支持。

## ⚠️ 重要：内存管理详解 (128GB 系统必读)

Agave 内存占用取决于具体版本、账户索引、RPC 流量和 Geyser 订阅，不能继续使用旧版本的固定 GB 数值判断。针对社区常见的 128GB 和 192GB 节点，服务不设置 `MemoryHigh` 软限流，避免 cgroup 强回收拖慢 replay；仅保留 `MemoryMax=90%` 作为主机失控时的最后保护，为内核、文件缓存、SSH 和监控保留至少 10% 内存。

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

# 输出包含高占用 Agave 线程和 CPU/内存/I/O pressure
# 重点观察持续出现的 solAcctsDbBg*、rocksdb:* 和 solPohTickProd

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
- 每次生成新诊断报告时，会清理 7 天前的旧诊断报告。

## 更新现有节点

请在维护窗口执行升级。先把本地仓库更新到远程 `dev` 分支；显式拉取命令也兼容
以前使用 `--single-branch` 克隆的节点：

```bash
cd /root/solana-rpc-install
git fetch origin dev:refs/remotes/origin/dev
git switch dev 2>/dev/null || git switch --track -c dev origin/dev
git pull --ff-only origin dev

# 查看当前 validator 版本
/usr/local/solana/bin/agave-validator --version
```

如果已经运行 `v4.2.1-jito`（或同主版本线），只更新主机和运行配置：

```bash
sudo bash system-optimize.sh
sudo bash update-runtime.sh --restart
```

> **v4.2 注意**：本仓库运行脚本仅支持 Agave/Jito **v4.2+**。v4.2 默认启用 XDP，
> 且 `--allow-private-addr` 必须搭配 `--no-xdp`；账户缓存参数改为
> `--accounts-db-write-cache-limit`。升级二进制后若未同步运行脚本，节点会
> crash-loop —— 请务必执行上面的 `update-runtime.sh`。不再兼容 v4.1.x 启动参数。

如果仍是 `v4.1.x-jito` 或更早版本，先编译 v4.2.1。最后一次重启会短暂中断 RPC
服务：

```bash
# 版本提示处直接回车选择 v4.2.1。
# nice 可减少编译过程对仍在运行的 validator 的影响。
sudo nice -n 10 bash 2-install-jito-validator.sh
sudo bash system-optimize.sh
sudo bash update-runtime.sh --restart
```

`system-optimize.sh` 会关闭 swap。明确需要可选 swapfile 的 128GB 节点，应在系统
优化后执行 `sudo bash add-swap-128g.sh`。以上升级流程都不会删除 ledger、accounts
或 snapshot；普通更新不要运行 `3-start.sh --fresh-sync`。

## ✨ 核心特性

### 🔧 配置理念

默认配置优先考虑 128GB/192GB 稳定性、上游兼容性和可诊断性：

- **保守稳定 > 激进优化**
- **简单默认 > 复杂定制**
- **实测性能 > 理论收益**

### 📦 系统优化

- 🌐 **Socket 缓冲区上限**: 128MB，与 Anza validator 基础配置一致
- 💾 **资源限制**: 100 万文件描述符和 2GB memlock
- 🔄 **有界回写**: 后台脏页 512MB、硬上限 2GB，减少集中写盘
- ⚡ **CPU 策略**: 持久化 performance governor、EPP performance 和 turbo
- 🧠 **内存延迟**: 运行时关闭 Transparent Huge Pages
- 🌐 **网卡 Ring**: 自动读取并设置为网卡报告的最大值
- 🛡️ **保守范围**: 不修改 SMT、C-state、IRQ affinity、内核或 GRUB

### ⚡ Yellowstone gRPC 配置

- ✅ **可选压缩**: 客户端可协商 gzip/zstd，以 CPU 换取带宽
- 📦 **分档队列**: 128GB 使用 50K channel/128 unary；192GB 使用 100K/256
- 🎯 **上游默认**: Tokio 和 HTTP/2 参数保持默认
- 🛡️ **资源保护**: 限制过滤器和请求数量；鉴权仍为可选项

启动器会在 `/run/solana-rpc` 生成分档配置，不修改原始
`yellowstone-config.json`。设置 `GEYSER_CONFIG=/path/to/custom.json` 可以完全使用
自定义配置；`ENABLE_GEYSER=0`、`ENABLE_ALT_INDEX=0`、`ENABLE_TX_HISTORY=0`
可以分别关闭对应负载，默认安装行为保持不变。

### 🚀 部署特性

- 📦 **源码编译安装**:
  - 🔧 从官方 GitHub 构建 Jito Solana (启用 LTO 后通常 30-90 分钟)
  - ⚡ 使用同机原生 CPU 指令和 Jito release-with-LTO profile
  - ✅ 完整的 validator 二进制文件和完整 MEV 支持
  - 🎯 验证 Jito release tag 并记录源码 commit
- 🧠 **智能配置选择**: 自动检测系统 RAM 并选择最优 validator 配置
  - TIER 1 (128GB): 保守配置，适用于 128-159GB 系统
  - TIER 2 (192GB): 平衡配置，适用于 192-223GB 系统
  - TIER 3 (256GB): 高性能配置，适用于 256-383GB 系统
  - TIER 4 (512GB+): 最大容量配置，适用于企业级部署
- 🔄 **自动磁盘管理**: 智能磁盘检测和挂载
- 🛡️ **生产就绪**: Systemd 服务，90% 主机内存最后保护和 OOM 诊断
- 🌐 **网络容错**: 增强版本验证，优雅处理网络问题
- 📊 **监控工具**: 包含性能跟踪和健康检查
- 📸 **只加载快照**: 使用下载的归档启动，不再持续生成完整快照

## 🔌 网络端口

| 端口 | 协议 | 用途 |
|------|------|------|
| **8899** | HTTP | RPC 端点 |
| **8900** | WebSocket | 实时订阅 |
| **10900** | gRPC | 高性能数据流；为兼容现有客户端默认开放 |
| **8000-8030** | TCP/UDP | 验证者通信 (动态) |

安装器不会强制 gRPC token，现有客户端无需增加 metadata。固定出口 IP 的用户可选：

```bash
ufw delete allow 10900
ufw allow from 客户端公网IP to any port 10900 proto tcp
ufw deny 10900/tcp
ufw status numbered
```

IP 白名单配置简单，但客户端公网 IP 变化后必须同步修改。Token 更适合 IP 经常变化的
客户端，但每个客户端都必须携带 token，因此本项目不默认启用。

## 📈 性能指标

- **快照下载**: 取决于网络 (通常 200MB - 1GB/s)
- **内存保护**: 不设置影响延迟的软限流，90% 为主机最后保护
- **同步时间**: 1-3 小时 (从快照开始)
- **CPU 使用**: 多核优化 (推荐 32+ 核心)
- **稳定性**: 保守默认值，并提供 cgroup、pressure、磁盘和线程诊断

## 🛠️ 架构说明

```
┌─────────────────────────────────────────────────────────┐
│                   Solana RPC 节点堆栈                     │
├─────────────────────────────────────────────────────────┤
│  Jito Solana 验证者 (v4.2.x)                            │
│  ├─ 安装方式: 从 GitHub 源码编译                         │
│  │  • agave-validator 完整 MEV 支持                     │
│  │  • 原生 CPU + release-with-LTO 构建                  │
│  ├─ Yellowstone gRPC 自动匹配 Solana 版本               │
│  ├─ RPC HTTP/WebSocket (端口 8899/8900)                │
│  └─ 账户 & 账本 (优化的 RocksDB)                        │
├─────────────────────────────────────────────────────────┤
│  系统优化 (保守配置)                                      │
│  ├─ 网络: Anza 128MB socket 上限                        │
│  ├─ 内存: 有界脏页回写, THP 已关闭                       │
│  ├─ 文件描述符: 1M 限制, 生产环境足够                    │
│  └─ 稳定性: 保守默认值 + 完整诊断                        │
├─────────────────────────────────────────────────────────┤
│  Yellowstone gRPC (开源测试配置)                         │
│  ├─ 压缩: 客户端可协商 gzip+zstd                         │
│  ├─ 队列: 128GB 50K/128, 192GB 100K/256                │
│  ├─ 默认值: 系统管理, 无过度优化                         │
│  └─ 保护: 过滤器和请求限制                               │
├─────────────────────────────────────────────────────────┤
│  基础设施                                                 │
│  ├─ Systemd 服务 (自动重启, 优雅关闭)                   │
│  ├─ 多磁盘设置 (系统/账户/账本)                          │
│  └─ 监控工具 (性能/健康/同步进度)                        │
└─────────────────────────────────────────────────────────┘
```

## 🧪 配置理念

### 为什么选择保守配置？

1. **压缩存在权衡**
   - gzip/zstd 可以减少网络带宽，但会消耗 CPU。
   - 应根据实际客户端流量测试，而不是默认认为一定降低延迟。

2. **队列按内存分档并设置上限**
   - 128GB 节点每连接使用 50K channel，192GB 使用 100K。
   - 慢客户端可能落后或重连，避免无限消耗节点内存。

3. **无关运行参数保持上游默认**
   - 不覆盖 Tokio 和 HTTP/2 线程/窗口配置。
   - 不关闭 SMT/C-state，不设置 IRQ affinity，不修改内核和 GRUB。

4. **修改限制前先收集数据**
   - 使用 `performance-monitor.sh snapshot` 查看线程和 pressure。
   - 上报重启或同步问题前，先运行 `performance-monitor.sh diagnose`。

## 📚 文档资源

- **安装指南**: 您正在阅读！
- **挂载验证**: 运行 `sudo bash verify-mounts.sh`
- **故障排除**: 使用 `journalctl -u sol -f` 查看日志
- **配置**: 所有优化默认包含
- **监控**: 使用提供的辅助脚本
- **优化详情**: 查看上面的系统优化和 Yellowstone 章节

## 🤝 支持与社区

- **Telegram 群组**: [https://t.me/fnzero_group](https://t.me/fnzero_group)
- **Discord 服务器**: [https://discord.gg/vuazbGkqQE](https://discord.gg/vuazbGkqQE)
- **问题反馈**: [GitHub Issues](https://github.com/0xfnzero/solana-rpc-install/issues)
- **官方网站**: [https://fnzero.dev/](https://fnzero.dev/)

## 📜 开源协议

本项目采用 [MIT License](https://opensource.org/license/mit) 发布。

---

<div align="center">
    <p>
        <strong>⭐ 如果这个项目对您有帮助，请给我们一个 Star！</strong>
    </p>
    <p>
        Made with ❤️ by <a href="https://github.com/0xfnzero">fnzero</a>
    </p>
</div>
