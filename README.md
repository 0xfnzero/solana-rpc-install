# Solana RPC Node - 3-Step Installation

[English](#english) | [中文](#中文)

---

## English

### System Requirements

**Minimum Configuration:**
- CPU: AMD Ryzen 9 9950X (or equivalent)
- RAM: 192 GB minimum
- Storage: 3x NVMe SSDs (1TB system + 2TB accounts + 2TB ledger)
- OS: Ubuntu 20.04/22.04

### Installation Steps

**1. Clone Repository**

```bash
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install
```

**2. Switch to Root**

```bash
sudo su -
cd /path/to/solana-rpc-install
```

**3. Run Installation Scripts**

```bash
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

### Monitoring

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

### Key Features

- **Extreme Network Optimization**: 500MB-2GB/s snapshot download speed
- **TCP Buffers**: 512MB (extreme)
- **Disk Read-ahead**: 32MB (extreme)
- **Network Budget**: 150,000 (extreme)
- **BBR Congestion Control**: Enabled
- **Source Compilation**: Latest Agave version from GitHub

### Ports

- **8899**: HTTP RPC
- **8900**: WebSocket
- **10900**: gRPC
- **8000-8025**: Validator communication (dynamic port range)

### Support

Telegram: [https://t.me/fnzero_group](https://t.me/fnzero_group)

---

## 中文

### 系统要求

**最低配置：**
- CPU: AMD Ryzen 9 9950X (或同等性能)
- 内存: 最低 192 GB
- 存储: 3块 NVMe SSD (1TB系统 + 2TB账户 + 2TB账本)
- 系统: Ubuntu 20.04/22.04

### 安装步骤

**1. 克隆仓库**

```bash
git clone https://github.com/0xfnzero/solana-rpc-install.git
cd solana-rpc-install
```

**2. 切换到 root 用户**

```bash
sudo su -
cd /path/to/solana-rpc-install
```

**3. 执行安装脚本**

```bash
# 步骤1: 挂载磁盘 + 系统优化
bash 1-prepare.sh

# 步骤2: 从源码安装 Solana (20-40分钟)
bash 2-install-solana.sh
# 提示时输入版本号 (例如: v3.0.10)

# 步骤3: 重启系统
reboot

# 步骤4: 重启后下载快照并启动节点
bash 3-start.sh
```

### 监控命令

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

### 核心特性

- **极限网络优化**: 500MB-2GB/s 快照下载速度
- **TCP 缓冲区**: 512MB (极限)
- **磁盘预读**: 32MB (极限)
- **网络预算**: 150,000 (极限)
- **BBR 拥塞控制**: 已启用
- **源码编译**: GitHub 最新 Agave 版本

### 端口配置

- **8899**: HTTP RPC 端口
- **8900**: WebSocket 端口
- **10900**: gRPC 端口
- **8000-8025**: 验证者通信动态端口

### 技术支持

Telegram 群组: [https://t.me/fnzero_group](https://t.me/fnzero_group)
