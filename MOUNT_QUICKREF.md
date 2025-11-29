# 挂载配置快速参考

## ✅ 你的当前配置（已优化）

```
nvme1n1     → /root/sol/accounts    [独立磁盘，高性能] ✓
nvme0n1p2   → /root/sol/ledger      [系统盘，空间充足] ✓
              /root/sol/snapshot    [系统盘，空间充足] ✓
```

**结论：你的挂载方案已经是最优配置，无需修改！**

## 🎯 为什么这是最优方案

| 目录 | 挂载位置 | 原因 |
|------|---------|------|
| `accounts` | nvme1n1 独立磁盘 | 最需要性能，独享 IOPS |
| `ledger` | 系统盘 | 大小可控（50GB limit），系统盘够用 |
| `snapshot` | 系统盘 | 周期性使用，不需要极高性能 |

## 📊 空间使用情况

```bash
# 当前使用
nvme1n1:    424GB / 1.7TB  (26% used)  - accounts
nvme0n1p2:  372GB / 1.7TB  (23% used)  - 系统 + ledger + snapshot

# 空间充足，无需担心
```

## 🔧 验证命令

```bash
# 在服务器上运行
sudo bash verify-mounts.sh

# 快速检查
df -h /root/sol/accounts /root/sol/ledger /root/sol/snapshot
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep nvme
```

## 📈 何时需要扩展

**只有在以下情况才需要添加第二块数据盘：**

1. **Accounts 磁盘空间不足**（>80% 使用率）
   - 添加更大的 NVMe 替换 nvme1n1

2. **系统盘空间不足**（>85% 使用率）
   - 添加第二块 NVMe 用于 ledger + snapshot

3. **I/O 瓶颈**（极少见）
   - 监控显示 ledger 写入影响系统性能
   - 添加第二块 NVMe 专用于 ledger

## 🚀 性能优化建议

**当前配置已经很好，但可以进一步优化：**

```bash
# 1. 限制 ledger 大小（已在脚本中配置）
--limit-ledger-size 50000000  # 50GB

# 2. 限制快照数量（已在脚本中配置）
--maximum-full-snapshots-to-retain 2-3

# 3. 定期清理旧快照
cd /root/sol/snapshot
ls -lht *.tar.bz2  # 查看快照文件
rm -f old-*.tar.bz2  # 删除旧快照
```

## 📝 配置文件

- **详细文档**: `MOUNT_STRATEGY.md`
- **验证脚本**: `verify-mounts.sh`
- **挂载脚本**: `1-prepare.sh`

## ⚠️  重要提醒

✅ **DO**:
- 保持当前配置不变
- 监控磁盘空间（每周检查一次）
- 定期清理旧快照

❌ **DON'T**:
- 不要移动 accounts 到系统盘（性能会大幅下降）
- 不要禁用 ledger 大小限制
- 不要在生产环境随意改挂载点

---

**总结：你的配置已经是最佳实践，继续使用即可！**
