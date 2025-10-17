[中文](https://github.com/0xfnzero/solana-rpc-install/blob/main/README_CN.md) | [English](https://github.com/0xfnzero/solana-rpc-install/blob/main/README.md) | [Telegram](https://t.me/fnzero_group) | [Discord](https://discord.gg/ckf5UHxz)

# Solana RPC 节点快速安装指南

## 系统要求

### 最低配置要求
* **CPU**: AMD Ryzen 9 9950X (推荐)
* **内存**: 至少 192 GB
* **存储**: 至少 3 个 NVMe 硬盘 (1T系统盘 + 2T账户数据 + 2T账本数据)
* **系统**: Ubuntu 20.04/22.04

### 推荐服务商
* **TSW** 强烈推荐，因为有些服务商即使配置相同，性能差异也很大
* 网络、硬盘、内存都会影响节点稳定性和 gRPC 速度
* 有些用户在 AMS3 区域使用 128 GB 内存会出现 OOM 问题，所以建议至少 192 GB 内存

## 三步安装流程

### 第一步：下载系统优化脚本

```bash
# 下载系统优化脚本
wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.6/system-optimize.sh

# 赋予执行权限
chmod +x system-optimize.sh
```

**此脚本功能：**
- 关闭 swap (注释 fstab 中的 swap 行 + swapoff -a)
- 优化 sysctl.conf，配置 westwood TCP、VM 调优和文件描述符限制
- 设置 CPU 为 performance 模式
- 配置 systemd 和安全限制，提高文件描述符数量
- 立即应用所有更改

### 第二步：下载 Solana 安装脚本

```bash
# 下载 Solana 安装脚本
wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.6/solana-install.sh

# 赋予执行权限
chmod +x solana-install.sh
```

**此脚本功能：**
- 安装 OpenSSL 1.1
- 创建必要目录 (/root/sol/accounts, /root/sol/ledger, /root/sol/snapshot, /root/sol/bin)
- 自动检测并挂载数据硬盘 (优先顺序：accounts → ledger → snapshot)
- 安装 Solana CLI v2.3.6 并配置 PATH
- 创建验证者密钥对
- 配置 UFW 防火墙，开放必要端口
- 创建 validator.sh 启动脚本和 systemd 服务
- 下载 Yellowstone gRPC geyser 和配置文件
- 下载管理脚本 (redo_node.sh, restart_node.sh, get_health.sh, catchup.sh)
- 自动启动节点并下载快照

### 第三步：按顺序执行脚本

```bash
# 首先运行系统优化 (需要 root 权限)
sudo ./system-optimize.sh

# 然后运行 Solana 安装 (需要 root 权限)
sudo ./solana-install.sh
```

**重要提示：**
- 两个脚本都必须以 root 权限运行 (使用 `sudo`)
- 必须按照上述顺序执行
- 系统优化脚本应该首先运行，为系统做准备
- Solana 安装脚本完成后会自动启动节点

## 安装后操作

### 检查节点状态
```bash
# 查看日志
tail -f /root/solana-rpc.log

# 检查节点健康状态 (约30分钟后应该显示 ok)
./get_health.sh

# 监控区块同步进度
./catchup.sh
```

### 管理命令
```bash
# 重启节点 (如果无法追上区块)
sudo /root/restart_node.sh

# 或使用 systemctl
sudo systemctl restart sol

# 检查服务状态
sudo systemctl status sol

# 设置开机自启
sudo systemctl enable sol
```

### 端口配置
以下端口会自动配置：
- **8899**: HTTP RPC 端口
- **8900**: WebSocket 端口  
- **10900**: gRPC 端口
- **8000-8020**: 验证者通信动态端口

## 故障排除

### 如果节点启动失败：
1. 检查日志：`tail -f /root/solana-rpc.log`
2. 验证磁盘空间：`df -h`
3. 检查内存使用：`free -h`
4. 重启节点：`sudo /root/restart_node.sh`

### 如果节点无法追上区块：
1. 监控进度：`/root/catchup.sh`
2. 如需要则重启：`sudo /root/restart_node.sh`
3. 检查与 Solana 入口点的网络连接

### 系统要求检查：
```bash
# 检查 CPU 模式
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# 检查文件描述符限制
ulimit -n

# 检查 swap 状态
swapon --show
```

## 支持

如有问题需要支持，请加入我们的 Telegram 群组：[https://t.me/fnzero_group](https://t.me/fnzero_group)

---

**注意**：此快速安装指南自动化了详细 README 中描述的整个流程。脚本会自动处理所有系统优化、硬盘挂载、软件安装和配置。
