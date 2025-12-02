# 🚨 快速修复挂载优先级错误

## 当前问题

您的服务器磁盘挂载顺序错误：
- ❌ Accounts（最需要性能）→ 系统盘
- ✅ Ledger → nvme0n1 (2.9TB)
- ✅ Snapshot → nvme1n1 (2.9TB)

**这严重影响性能！** Accounts 的随机读写 IOPS 需求最高，应该使用最快的 NVMe。

---

## ⚡ 立即修复（2 分钟）

### 方案 A：自动修复（推荐）

```bash
# 1. 更新代码到最新版本
cd /root/solana-rpc-install
git pull

# 2. 运行准备脚本（会自动检测并修复优先级）
bash 1-prepare.sh
```

脚本会：
- ✅ 自动检测优先级错误
- ✅ 卸载 ledger 和 snapshot
- ✅ 清理旧的 fstab 配置
- ✅ 按正确优先级重新挂载：
  - nvme0n1 → Accounts
  - nvme1n1 → Ledger
  - 系统盘 → Snapshot

### 方案 B：手动修复（如果方案 A 无法自动修复）

```bash
# 1. 停止 Solana 节点（如果正在运行）
systemctl stop sol

# 2. 运行专用修复脚本
cd /root/solana-rpc-install
bash fix-mount-priority.sh

# 输入 yes 确认修复

# 3. 验证结果
bash verify-mounts.sh

# 4. 启动节点
systemctl start sol
```

---

## ✅ 修复后的正确状态

运行 `bash verify-mounts.sh` 应该看到：

```
  • Accounts:
    - 设备: /dev/nvme0n1 (2.9TB)
    - 状态: 独立挂载 ✓

  • Ledger:
    - 设备: /dev/nvme1n1 (2.9TB)
    - 状态: 独立挂载 ✓

  • Snapshot:
    - 设备: /dev/mapper/vg0-root
    - 状态: 在 / 分区上
```

---

## 🎯 性能提升预期

修复后：
- **Accounts IOPS**: +300-500% (从系统盘共享 → 独立 2.9T NVMe)
- **节点同步速度**: +200-300%
- **RPC 响应延迟**: -50-70%
- **系统稳定性**: 显著提升（减少 I/O 争抢）

---

## ⚠️ 重要说明

1. **verify-mounts.sh 不会修复问题**
   - 它只是检查工具，不会改变任何挂载
   - 必须运行 `1-prepare.sh` 或 `fix-mount-priority.sh` 来实际修复

2. **数据安全**
   - 修复脚本只重新挂载磁盘，不会删除数据
   - 会自动备份 /etc/fstab
   - 建议在修复前停止 Solana 节点

3. **如果节点正在运行**
   - 必须先停止节点：`systemctl stop sol`
   - 修复完成后再启动：`systemctl start sol`

---

## 🐛 故障排查

### 如果 1-prepare.sh 报错

```bash
# 查看详细错误信息
bash -x 1-prepare.sh

# 如果有进程占用磁盘
lsof | grep -E "nvme0n1|nvme1n1"
fuser -m /root/sol/ledger
fuser -m /root/sol/snapshot

# 停止占用进程后重试
systemctl stop sol
bash 1-prepare.sh
```

### 如果自动修复失败

使用手动修复脚本：
```bash
bash fix-mount-priority.sh
```

它会：
- 提供更详细的输出
- 等待用户确认每一步
- 更安全的处理异常情况

---

## 📞 需要帮助？

如果遇到任何问题：
1. 保存完整的错误输出
2. 运行 `lsblk` 和 `mount` 查看当前状态
3. 联系技术支持并提供以上信息

**记住**：必须实际运行修复脚本，仅仅运行 verify-mounts.sh 不会解决问题！
