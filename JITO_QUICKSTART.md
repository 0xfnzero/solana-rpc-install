# Jito Solana 快速安装指南

## 🚀 一键安装 (推荐)

```bash
# 1. 系统准备 (5 分钟)
sudo bash 1-prepare.sh

# 2. 安装 Jito Solana (2-3 分钟)
sudo bash 2-install-solana-jito.sh
# 提示时输入版本号: v3.0.11

# 3. 下载快照并启动 (30-60 分钟)
bash 3-start.sh
```

## 📋 详细步骤

### 步骤 1: 克隆项目 (1 分钟)

```bash
cd ~
git clone <your-repo-url> solana-rpc-install
cd solana-rpc-install
```

### 步骤 2: 系统准备 (5 分钟)

```bash
sudo bash 1-prepare.sh
```

**这一步会做什么**:
- 创建数据目录 (/root/sol/accounts, ledger, snapshot)
- 自动检测并挂载额外磁盘 (accounts 优先)
- 优化系统内核参数
- 配置网络和内存设置

**预期输出**:
```
==> 1) 创建 Solana 工作目录...
   ✓ 目录已创建

==> 2) 自动检测磁盘并安全挂载（优先 accounts）...
   候选数据设备：/dev/nvme1n1
   - 挂载完成：/dev/nvme1n1 -> /root/sol/accounts

==> 3) 优化系统内核参数...
   ✓ 系统优化完成
```

### 步骤 3: 安装 Jito Solana (2-3 分钟)

```bash
sudo bash 2-install-solana-jito.sh
```

**交互式版本选择**:
```
请输入 Jito Solana 版本号 (例如 v3.0.11, v3.0.10): v3.0.11
```

**如何选择版本**:
1. 访问 https://github.com/jito-foundation/jito-solana/releases
2. 选择最新的稳定版本 (通常是最新的非 RC 版本)
3. 输入版本号，格式为 `vX.Y.Z`

**这一步会做什么**:
- 验证版本是否存在
- 下载 Jito 预编译包 (~400MB)
- 解压并安装到 /usr/local/solana
- 配置 PATH 环境变量 (持久化)
- 生成验证器密钥对
- 配置防火墙
- 安装 Yellowstone gRPC 插件
- 配置 systemd 服务

**预期输出**:
```
==> 0) 验证 Jito Solana 版本 ...
✓ 版本 v3.0.11-jito 验证成功，继续安装流程...

==> 2) 下载 Jito Solana 预编译版本 (v3.0.11-jito) ...
   - 下载 Jito Solana 预编译包...
   ✓ 下载完成

==> 3) 解压 Jito Solana 预编译包 ...
   ✓ 解压完成

==> 4) 安装 Jito Solana 到 /usr/local/solana ...
   ✓ 安装完成

==> 5) 配置 PATH 环境变量 (持久化) ...
   环境变量已添加到：
     - /root/.bashrc (root 用户)
     - /etc/profile.d/solana.sh (所有用户登录时)
     - /etc/environment (系统级别)

==> 6) 验证 Jito Solana 安装 ...
   - Solana 版本信息:
solana-cli 3.0.11 (src:...; feat:...)

✅ 步骤 2 完成: Jito Solana 安装完成!
```

### 步骤 4: 验证安装 (1 分钟)

```bash
# 验证环境配置

# 1. 检查 PATH
echo $PATH
# 应包含: /usr/local/solana/bin

# 2. 检查 solana 命令
which solana
# 应输出: /usr/local/solana/bin/solana

# 3. 检查版本
solana --version
# 应输出: solana-cli 3.0.11 (src:...; feat:...)

# 4. 检查挂载
df -h /root/sol/accounts
# 应看到独立的 NVMe 挂载
```

### 步骤 5: 下载快照并启动 (30-60 分钟)

```bash
cd ~/solana-rpc-install
bash 3-start.sh
```

**这一步会做什么**:
1. 下载最新快照 (约 30-45 分钟，取决于网络)
2. 验证快照完整性
3. 启动验证器
4. 开始同步区块链

**监控启动过程**:
```bash
# 查看服务状态
sudo systemctl status sol

# 查看实时日志
journalctl -u sol -f

# 检查同步进度
bash /root/catchup.sh
```

## 🔍 验证节点运行

### 检查服务状态

```bash
# 服务是否运行
sudo systemctl status sol

# 预期输出
● sol.service - Solana Validator
     Loaded: loaded (/etc/systemd/system/sol.service; enabled)
     Active: active (running) since ...
```

### 检查同步进度

```bash
bash /root/catchup.sh
```

**预期输出**:
```
Identity: <your-validator-pubkey>
Slot: 123456789
Behind: 0 slots
Health: ok
```

### 检查日志

```bash
# 实时日志
journalctl -u sol -f

# 最近 100 行
journalctl -u sol -n 100

# 查找错误
journalctl -u sol | grep -i error
```

## 📊 性能监控

```bash
# 查看性能快照
bash /root/performance-monitor.sh snapshot

# 持续监控 (每 5 秒更新)
bash /root/performance-monitor.sh monitor
```

## 🔧 常用命令

### 服务管理

```bash
# 启动
sudo systemctl start sol

# 停止
sudo systemctl stop sol

# 重启
sudo systemctl restart sol

# 查看状态
sudo systemctl status sol

# 查看日志
journalctl -u sol -f
```

### 节点管理

```bash
# 重新下载快照并重启 (清除所有数据)
bash /root/redo_node.sh

# 重启节点 (保留 contact-info)
bash /root/restart_node.sh

# 检查健康状态
bash /root/get_health.sh

# 检查同步进度
bash /root/catchup.sh
```

### 磁盘管理

```bash
# 检查挂载状态
bash verify-mounts.sh

# 查看磁盘使用
df -h /root/sol/*

# 查看数据目录大小
du -sh /root/sol/accounts
du -sh /root/sol/ledger
du -sh /root/sol/snapshot
```

## 📝 配置文件位置

### Solana 安装

```
/usr/local/solana/           # Solana 安装目录
├── bin/                     # 可执行文件
│   ├── solana
│   ├── solana-validator
│   └── ...
└── version.yml              # 版本信息
```

### 数据目录

```
/root/sol/
├── accounts/                # 账户数据库 (独立 NVMe)
├── ledger/                  # 区块链账本
├── snapshot/                # 快照文件
├── bin/                     # 验证器配置脚本
│   ├── validator.sh         # 默认配置
│   ├── validator-128g.sh    # 128GB RAM 配置
│   ├── validator-256g.sh    # 256GB RAM 配置
│   ├── validator-512g.sh    # 512GB RAM 配置
│   └── yellowstone-config.json
└── tools/                   # 辅助工具
```

### 环境变量配置

```
/root/.bashrc                # Root 用户环境
/etc/profile.d/solana.sh     # 系统级别 (所有用户)
/etc/environment             # 系统环境变量
```

### systemd 服务

```
/etc/systemd/system/sol.service
```

## ⚠️ 常见问题

### Q: 提示 "solana: command not found"

**A**: PATH 未生效，执行：
```bash
source /etc/profile.d/solana.sh
# 或
source /root/.bashrc
# 或重新登录
exit && ssh root@your-server
```

### Q: 下载快照很慢

**A**: 使用不同的快照源：
```bash
# 编辑 3-start.sh
# 查找 RPC_SNAPSHOTS 变量
# 尝试不同的快照提供商
```

### Q: 节点无法同步

**A**: 检查：
```bash
# 1. 检查防火墙
sudo ufw status

# 2. 检查磁盘空间
df -h

# 3. 检查日志错误
journalctl -u sol | grep -i error

# 4. 检查网络连接
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
  http://localhost:8899
```

### Q: 内存不足

**A**: 添加 swap 空间：
```bash
# 添加 128GB swap
sudo bash /root/add-swap-128g.sh

# 移除 swap
sudo bash /root/remove-swap.sh
```

### Q: 如何升级版本

**A**: 重新运行安装脚本：
```bash
# 停止服务
sudo systemctl stop sol

# 重新安装
sudo bash 2-install-solana-jito.sh
# 输入新版本号

# 启动服务
sudo systemctl start sol
```

## 📈 优化建议

### 1. 硬件优化

- ✅ 使用 NVMe SSD (accounts 独立挂载)
- ✅ 至少 256GB RAM (推荐 512GB)
- ✅ 16+ CPU 核心
- ✅ 10Gbps 网络

### 2. 系统优化

- ✅ 已在 `1-prepare.sh` 中自动配置
- ✅ 内核参数优化
- ✅ 网络参数优化
- ✅ 文件描述符限制

### 3. Solana 配置优化

- ✅ 已在 `validator-*.sh` 中配置
- ✅ 根据内存自动选择配置
- ✅ RPC 性能优化
- ✅ Yellowstone gRPC 低延迟配置

## 🎯 下一步

### 配置 RPC 访问

```bash
# 1. 测试本地 RPC
curl -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' \
  http://localhost:8899

# 2. 配置反向代理 (Nginx)
# 参考项目中的 nginx 配置示例

# 3. 配置 SSL 证书
# 使用 Let's Encrypt certbot
```

### 监控和告警

```bash
# 1. 设置 cron 定时监控
crontab -e

# 添加:
*/5 * * * * /root/performance-monitor.sh snapshot >> /var/log/solana-perf.log

# 2. 配置磁盘空间告警
# 当使用率 >80% 时发送通知
```

### 备份重要文件

```bash
# 备份验证器密钥
cp /root/sol/bin/validator-keypair.json ~/validator-keypair.backup.json

# 备份配置文件
tar -czf ~/solana-config-backup.tar.gz \
  /root/sol/bin/*.sh \
  /etc/systemd/system/sol.service
```

## 📚 更多资源

- **详细对比**: `JITO_VS_SOURCE.md`
- **挂载策略**: `MOUNT_STRATEGY.md`
- **优化指南**: `OPTIMIZATION_GUIDE.md`
- **部署文档**: `DEPLOY.md`

---

**祝你的 Solana RPC 节点运行顺利！** 🚀
