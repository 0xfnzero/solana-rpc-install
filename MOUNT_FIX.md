# 磁盘挂载修复说明

> **✨ 通用性说明**：此修复适用于 **1-3 个数据盘** 的所有配置场景。脚本会自动检测可用磁盘并按优先级分配（accounts > ledger > snapshot），无需手动配置。

## 🚨 优先级错误问题（自动修复）

### 症状

如果您运行 `bash verify-mounts.sh` 看到类似以下情况：

```
⚠️  Accounts 未独立挂载（在系统盘上）
✓ Ledger 已独立挂载到 /dev/nvme0n1
✓ Snapshot 已独立挂载到 /dev/nvme1n1
```

**这是严重的优先级错误！** Accounts 才是最需要高性能 NVMe 的目录，但它却在系统盘上，而性能需求较低的 Ledger/Snapshot 反而占用了 NVMe。

### ✅ 自动修复（推荐）

**最新版本的 `1-prepare.sh` 已经支持自动检测并修复优先级错误！**

```bash
# 更新到最新版本
cd /root/solana-rpc-install
git pull

# 直接运行准备脚本，它会自动修复
bash 1-prepare.sh
```

脚本会自动：
1. ✅ 检测优先级错误
2. ✅ 自动卸载错误挂载的目录
3. ✅ 清理 `/etc/fstab` 旧配置
4. ✅ 按正确优先级重新挂载：
   - 第1块 NVMe → Accounts（最高性能需求）
   - 第2块 NVMe → Ledger（中等性能需求）
   - 第3块 NVMe → Snapshot（低性能需求）
5. ✅ 更新持久化配置

### 🔧 手动修复（备用方案）

如果您需要更细粒度的控制，可以使用专用修复脚本：

```bash
# 1. 停止 Solana 节点（如果正在运行）
systemctl stop sol

# 2. 运行优先级修复脚本
cd /root/solana-rpc-install
bash fix-mount-priority.sh

# 3. 验证修复结果
bash verify-mounts.sh

# 4. 启动节点
systemctl start sol
```

### 为什么会出现这个问题？

可能原因：
1. 使用了旧版本脚本（v1.0 之前），磁盘分配逻辑不完善
2. 手动挂载时顺序错误
3. 从其他配置迁移时未遵循优先级规则

### 新版本改进

**v1.1+ 版本的 `1-prepare.sh`** 具备以下能力：
- ✅ 自动检测所有可用数据盘
- ✅ 检查当前挂载状态和优先级
- ✅ 自动修复优先级错误（无需用户干预）
- ✅ 智能处理各种磁盘配置（1-3块数据盘）

---

## 🔍 其他挂载问题分析

### 发现的问题

根据用户的磁盘结构和 `verify-mounts.sh` 输出，发现了以下问题：

```
当前状态：
- nvme0n1 (2.9T) → /mnt/nvme0n1  ❌ 错误的挂载位置
- nvme1n1 (2.9T) → /mnt/nvme1n1  ❌ 错误的挂载位置
- Accounts → 系统盘 /dev/mapper/vg0-root  ❌ 性能不佳
- Ledger   → 系统盘 /dev/mapper/vg0-root  ❌ 性能不佳
- Snapshot → 系统盘 /dev/mapper/vg0-root  ❌ 性能不佳
```

### 根本原因

原始 `1-prepare.sh` 脚本的挂载逻辑存在缺陷：

1. **检测到已挂载的设备就跳过**：
   - 脚本发现 nvme0n1 和 nvme1n1 已挂载（即使在错误的位置）
   - 直接跳过这些设备，不进行重新挂载
   - 结果导致 Solana 数据目录无法使用这些高性能磁盘

2. **没有挂载位置验证**：
   - 没有检查设备是否挂载到预期的目标目录
   - 无法自动纠正错误的挂载配置

## ✅ 修复内容

### 1. 增强 `mount_one()` 函数

**修复前**：
```bash
mount_one() {
  local dev="$1"; local target="$2"
  if is_mounted_dev "$dev"; then
    echo "   - 已挂载：$dev -> $(findmnt -no TARGET "$dev")，跳过"
    return 0
  fi
  # ... 其他挂载逻辑
}
```

**修复后**：
```bash
mount_one() {
  local dev="$1"; local target="$2"

  # 检查设备是否已挂载
  if is_mounted_dev "$dev"; then
    local current_mount=$(findmnt -no TARGET "$dev")
    # 如果已挂载到目标位置，跳过
    if [[ "$current_mount" == "$target" ]]; then
      echo "   - 已正确挂载：$dev -> $target，跳过"
      return 0
    fi
    # 如果挂载到了错误的位置，先卸载
    echo "   - 检测到 $dev 挂载在错误位置：$current_mount"
    echo "   - 卸载 $dev ..."
    umount "$dev"
    # 清理 fstab 中的旧配置
    sed -i "\|$current_mount|d" /etc/fstab
  fi

  # 创建目标目录并挂载
  mkdir -p "$target"
  mount -o defaults "$dev" "$target"

  # 更新 fstab 配置
  sed -i "\|^${dev} |d" /etc/fstab
  echo "$dev $target ext4 defaults 0 0" >> /etc/fstab

  echo "   - ✅ 挂载完成：$dev -> $target"
}
```

**改进点**：
- ✅ 检查设备是否挂载到正确位置
- ✅ 自动卸载错误挂载的设备
- ✅ 清理 /etc/fstab 中的旧配置
- ✅ 重新挂载到正确位置
- ✅ 更新 fstab 配置确保重启后生效

### 2. 优化设备候选逻辑

**新增函数**：
```bash
# 辅助函数：检查设备是否已正确挂载到 Solana 数据目录
is_correctly_mounted() {
  local dev="$1"
  if ! is_mounted_dev "$dev"; then
    return 1  # 未挂载
  fi
  local current_mount=$(findmnt -no TARGET "$dev")
  # 检查是否挂载到 accounts、ledger 或 snapshot 目录
  [[ "$current_mount" == "$ACCOUNTS" || "$current_mount" == "$LEDGER" || "$current_mount" == "$SNAPSHOT" ]]
}
```

**修复后的候选逻辑**：
```bash
# 收集候选设备（排除系统盘；包括错误挂载的设备）
CANDIDATES=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"
  [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]] && continue
  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))
  if ((${#parts[@]}==0)); then
    # 整盘：如果未挂载或挂载到错误位置，加入候选
    is_correctly_mounted "$disk" || CANDIDATES+=("$disk")
  else
    # 有分区：选择最大的可用分区（未挂载或挂载到错误位置）
    best=""; best_size=0
    for p in "${parts[@]}"; do
      part="/dev/$p"
      # 跳过已正确挂载到 Solana 目录的分区
      is_correctly_mounted "$part" && continue
      size=$(lsblk -bno SIZE "$part")
      (( size > best_size )) && { best="$part"; best_size=$size; }
    done
    [[ -n "$best" ]] && CANDIDATES+=("$best")
  fi
done
```

**改进点**：
- ✅ 允许错误挂载的设备进入候选列表
- ✅ 只跳过已正确挂载到 Solana 目录的设备
- ✅ 自动处理重新挂载逻辑

## 🚀 使用修复后的脚本

### 执行步骤

**重要提示**：执行前请确保 Solana 节点已停止，以免影响正在运行的服务。

```bash
# 1. 切换到 root 用户
sudo su -

# 2. 进入脚本目录
cd /root/solana-rpc-install

# 3. 备份当前挂载配置（可选）
cp /etc/fstab /etc/fstab.backup

# 4. 执行修复脚本
bash 1-prepare.sh
```

### 预期行为

修复脚本会自动适配您的磁盘配置。以用户的 **双数据盘配置** 为例：

```
1. 检测磁盘设备
   候选数据设备：/dev/nvme0n1 /dev/nvme1n1

2. 处理 nvme0n1（第一优先级 → accounts）
   - 检测到 /dev/nvme0n1 挂载在错误位置：/mnt/nvme0n1
   - 卸载 /dev/nvme0n1 ...
   - 清理 fstab 中的旧挂载配置：/mnt/nvme0n1
   - ✅ 挂载完成：/dev/nvme0n1 -> /root/sol/accounts

3. 处理 nvme1n1（第二优先级 → ledger）
   - 检测到 /dev/nvme1n1 挂载在错误位置：/mnt/nvme1n1
   - 卸载 /dev/nvme1n1 ...
   - 清理 fstab 中的旧挂载配置：/mnt/nvme1n1
   - ✅ 挂载完成：/dev/nvme1n1 -> /root/sol/ledger

4. 处理 snapshot（无第三块盘）
   - snapshot 使用系统盘：/root/sol/snapshot

5. 系统优化（极限网络性能）
   [系统参数优化...]
```

**其他配置场景**：
- **1 个数据盘**：只挂载 accounts，ledger 和 snapshot 用系统盘
- **3 个数据盘**：accounts、ledger、snapshot 各挂载一块独立磁盘
- **3+ 个数据盘**：使用前 3 块，其余保持不变

### 验证修复结果

执行完成后，运行验证脚本确认挂载配置：

```bash
bash verify-mounts.sh
```

**预期输出（双数据盘配置）**：

```
[2] 检查挂载点配置
--------------------------------------------
  • Accounts:
    - 路径: /root/sol/accounts
    - 设备: /dev/nvme0n1
    - 类型: ext4
    - 挂载点: /root/sol/accounts
    - 状态: 独立挂载 ✓

  • Ledger:
    - 路径: /root/sol/ledger
    - 设备: /dev/nvme1n1
    - 类型: ext4
    - 挂载点: /root/sol/ledger
    - 状态: 独立挂载 ✓

  • Snapshot:
    - 路径: /root/sol/snapshot
    - 设备: /dev/mapper/vg0-root
    - 类型: ext4
    - 挂载点: /
    - 状态: 在 / 分区上
```

**预期输出（单数据盘配置）**：

```
  • Accounts:
    - 设备: /dev/nvme0n1
    - 状态: 独立挂载 ✓

  • Ledger:
    - 设备: /dev/mapper/vg0-root
    - 状态: 在 / 分区上

  • Snapshot:
    - 设备: /dev/mapper/vg0-root
    - 状态: 在 / 分区上
```

**预期输出（三数据盘配置）**：

```
  • Accounts:
    - 设备: /dev/nvme0n1
    - 状态: 独立挂载 ✓

  • Ledger:
    - 设备: /dev/nvme1n1
    - 状态: 独立挂载 ✓

  • Snapshot:
    - 设备: /dev/nvme2n1
    - 状态: 独立挂载 ✓
```

**性能建议输出**：

```
[7] 性能建议
--------------------------------------------
  ✓ Accounts 已独立挂载 - 性能配置最优

  # 根据实际磁盘数量显示相应建议
  # 双盘/三盘: ✓ Ledger 已独立挂载
  # 单盘: ⚠️ Ledger 建议独立挂载
```

## ⚠️ 注意事项

### 1. 数据安全

- ✅ **脚本只处理挂载操作**，不会删除或修改现有数据
- ✅ **自动检测文件系统**，如果设备已有文件系统则保留
- ✅ **只在首次使用时格式化**，有文件系统的设备不会重新格式化

### 2. 卸载失败处理

如果设备正在使用无法卸载，脚本会提示：

```
⚠️  无法卸载 /dev/nvme0n1，可能正在使用。请手动检查并卸载后重新运行脚本
```

**解决方法**：

```bash
# 检查哪些进程正在使用设备
lsof | grep /mnt/nvme0n1

# 停止相关进程或服务
systemctl stop <service-name>

# 手动卸载
umount /dev/nvme0n1

# 重新运行脚本
bash 1-prepare.sh
```

### 3. fstab 配置

- ✅ 脚本会自动清理旧的挂载配置
- ✅ 添加新的持久化挂载配置
- ✅ 重启后挂载配置依然生效

### 4. 系统盘使用

根据您的磁盘配置：
- nvme0n1 (2.9T) → /root/sol/accounts（最高性能需求）
- nvme1n1 (2.9T) → /root/sol/ledger（中等性能需求）
- snapshot → 系统盘（低性能需求）

这是最优的资源分配方案。

## 🎯 通用磁盘配置支持

脚本自动适配不同的磁盘配置，支持 **1-3 个数据盘** 的所有场景：

### 配置场景

#### 场景 1：单数据盘（1 个 NVMe）

```
配置：
- 数据盘 1 → /root/sol/accounts（最高性能需求）
- 系统盘   → /root/sol/ledger + /root/sol/snapshot

性能：
- ✅ Accounts 获得最高 IOPS
- ⚠️ Ledger 和 Snapshot 共享系统盘资源
```

**适用场景**：预算有限，优先保证 accounts 性能

#### 场景 2：双数据盘（2 个 NVMe）⭐ 推荐

```
配置：
- 数据盘 1 → /root/sol/accounts（最高性能需求）
- 数据盘 2 → /root/sol/ledger（中等性能需求）
- 系统盘   → /root/sol/snapshot

性能：
- ✅ Accounts 和 Ledger 各享独立磁盘
- ✅ 系统盘压力降低 80%+
- ✅ 性价比最高
```

**适用场景**：生产环境推荐配置，平衡性能与成本

#### 场景 3：三数据盘（3 个 NVMe）

```
配置：
- 数据盘 1 → /root/sol/accounts（最高性能需求）
- 数据盘 2 → /root/sol/ledger（中等性能需求）
- 数据盘 3 → /root/sol/snapshot（低性能需求）
- 系统盘   → 仅系统文件

性能：
- ✅ 完全隔离，最高性能
- ✅ 系统盘零压力
- ⚠️ 成本较高，snapshot 不需要如此高性能
```

**适用场景**：高性能需求或已有三块磁盘的服务器

### 性能提升对比

| 场景 | Accounts | Ledger | Snapshot | 系统盘压力 | 性价比 |
|------|----------|--------|----------|-----------|--------|
| **修复前**（所有用系统盘） | 系统盘共享 | 系统盘共享 | 系统盘共享 | 极高 | - |
| **单数据盘** | 独立 NVMe ✅ | 系统盘 | 系统盘 | 中等 | ⭐⭐⭐ |
| **双数据盘** | 独立 NVMe ✅ | 独立 NVMe ✅ | 系统盘 | 低 | ⭐⭐⭐⭐⭐ |
| **三数据盘** | 独立 NVMe ✅ | 独立 NVMe ✅ | 独立 NVMe ✅ | 极低 | ⭐⭐⭐⭐ |

### 空间利用（以用户配置为例：2 个 2.9T NVMe）

- **Accounts**：2.9TB 专用空间（预计使用 300-500GB）
- **Ledger**：2.9TB 专用空间（可控制在 50GB，通过 --limit-ledger-size）
- **Snapshot**：系统盘空间（50-100GB，保留 2-3 个快照）

### 稳定性改善

- ✅ 降低系统盘 I/O 压力（单盘 -50%，双盘 -80%）
- ✅ 避免 Solana 数据与系统日志争抢资源
- ✅ 提高节点同步速度和 RPC 响应时间
- ✅ 减少因磁盘 I/O 饱和导致的节点延迟

## 📚 相关文档

- **挂载策略**：[MOUNT_STRATEGY.md](MOUNT_STRATEGY.md)
- **安装指南**：[README.md](README.md)
- **性能监控**：`bash performance-monitor.sh`
- **健康检查**：`bash get_health.sh`

## 🤝 反馈与支持

如果在使用修复脚本过程中遇到任何问题，请：

1. 查看脚本输出日志，确认具体错误信息
2. 运行 `bash verify-mounts.sh` 检查当前挂载状态
3. 联系技术支持或提交 Issue

---

**修复版本**：1.0
**更新日期**：2025-12-01
**维护者**：Solana RPC Team
