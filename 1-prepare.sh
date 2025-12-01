#!/bin/bash
set -euo pipefail

# ============================================
# 步骤1: 挂载磁盘 + 创建目录 + 系统优化
# ============================================

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BASE=${BASE:-/root/sol}
LEDGER="$BASE/ledger"
ACCOUNTS="$BASE/accounts"
SNAPSHOT="$BASE/snapshot"
BIN="$BASE/bin"
TOOLS="$BASE/tools"

if [[ $EUID -ne 0 ]]; then
  echo "[ERROR] 请用 root 执行：sudo bash $0" >&2
  exit 1
fi

echo "============================================"
echo "步骤 1: 环境准备"
echo "============================================"
echo ""

echo "==> 1) 创建目录 ..."
mkdir -p "$LEDGER" "$ACCOUNTS" "$SNAPSHOT" "$BIN" "$TOOLS"
echo "   ✓ 目录已创建"

# ---------- 自动判盘并挂载（优先：accounts -> ledger -> snapshot） ----------
echo ""
echo "==> 2) 自动检测磁盘并安全挂载（优先 accounts）..."
ROOT_SRC=$(findmnt -no SOURCE / || true)
ROOT_DISK=""
if [[ -n "${ROOT_SRC:-}" ]]; then
  ROOT_DISK=$(lsblk -no pkname "$ROOT_SRC" 2>/dev/null || true)
  [[ -n "$ROOT_DISK" ]] && ROOT_DISK="/dev/$ROOT_DISK"
fi
MAP_DISKS=($(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'))

is_mounted_dev() { findmnt -no TARGET "$1" &>/dev/null; }
has_fs() { blkid -o value -s TYPE "$1" &>/dev/null; }

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
    umount "$dev" || {
      echo "   ⚠️  无法卸载 $dev，可能正在使用。请手动检查并卸载后重新运行脚本"
      return 1
    }
    # 清理 fstab 中的旧配置
    if grep -q "$current_mount" /etc/fstab 2>/dev/null; then
      echo "   - 清理 fstab 中的旧挂载配置：$current_mount"
      sed -i "\|$current_mount|d" /etc/fstab
    fi
  fi

  # 如果没有文件系统，创建 ext4
  if ! has_fs "$dev"; then
    echo "   - 为 $dev 创建 ext4 文件系统（首次使用）"
    mkfs.ext4 -F "$dev"
  fi

  # 创建目标目录并挂载
  mkdir -p "$target"
  mount -o defaults "$dev" "$target"

  # 更新 fstab 配置（先清理旧配置，再添加新配置）
  if grep -qE "^${dev} " /etc/fstab 2>/dev/null; then
    echo "   - 更新 fstab 中的配置"
    sed -i "\|^${dev} |d" /etc/fstab
  fi
  echo "$dev $target ext4 defaults 0 0" >> /etc/fstab

  echo "   - ✅ 挂载完成：$dev -> $target"
}

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

echo "   候选数据设备：${CANDIDATES[*]:-"<无>"}"

# 检查当前挂载状态，验证优先级
echo ""
echo "==> 2.1) 检查当前 Solana 目录挂载状态..."
CURRENT_ACC_DEV=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $1}')
CURRENT_LED_DEV=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $1}')
CURRENT_SNAP_DEV=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $1}')

CURRENT_ACC_MOUNT=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $6}')
CURRENT_LED_MOUNT=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $6}')
CURRENT_SNAP_MOUNT=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $6}')

# 检测优先级错误
PRIORITY_ERROR=false
if [[ "$CURRENT_ACC_MOUNT" != "$ACCOUNTS" && "$CURRENT_LED_MOUNT" == "$LEDGER" ]]; then
    echo "   ⚠️  检测到优先级错误："
    echo "   - Accounts 未独立挂载（在 $CURRENT_ACC_MOUNT 上）"
    echo "   - Ledger 已独立挂载（$CURRENT_LED_DEV -> $LEDGER）"
    echo "   - 这违反了优先级规则：Accounts (最高) > Ledger (中等)"
    PRIORITY_ERROR=true
fi

if [[ "$CURRENT_ACC_MOUNT" != "$ACCOUNTS" && "$CURRENT_SNAP_MOUNT" == "$SNAPSHOT" ]]; then
    echo "   ⚠️  检测到优先级错误："
    echo "   - Accounts 未独立挂载（在 $CURRENT_ACC_MOUNT 上）"
    echo "   - Snapshot 已独立挂载（$CURRENT_SNAP_DEV -> $SNAPSHOT）"
    echo "   - 这违反了优先级规则：Accounts (最高) > Snapshot (最低)"
    PRIORITY_ERROR=true
fi

if $PRIORITY_ERROR; then
    echo ""
    echo "   ❌ 无法自动修复优先级错误（避免数据丢失风险）"
    echo ""
    echo "   📋 推荐修复步骤："
    echo "   1. 停止 Solana 节点（如果正在运行）：systemctl stop sol"
    echo "   2. 运行优先级修复脚本：bash $SCRIPT_DIR/fix-mount-priority.sh"
    echo "   3. 验证修复结果：bash $SCRIPT_DIR/verify-mounts.sh"
    echo ""
    echo "   或者手动调整（高级用户）："
    echo "   1. 卸载 ledger 和 snapshot"
    echo "   2. 重新按优先级挂载：accounts -> ledger -> snapshot"
    echo "   3. 更新 /etc/fstab 配置"
    echo ""
    exit 1
fi

echo "   ✓ 挂载优先级检查通过"
echo ""

# 分配设备
ASSIGNED_ACC=""; ASSIGNED_LED=""; ASSIGNED_SNAP=""
((${#CANDIDATES[@]}>0)) && ASSIGNED_ACC="${CANDIDATES[0]}"
((${#CANDIDATES[@]}>1)) && ASSIGNED_LED="${CANDIDATES[1]}"
((${#CANDIDATES[@]}>2)) && ASSIGNED_SNAP="${CANDIDATES[2]}"

[[ -n "$ASSIGNED_ACC"  ]] && mount_one "$ASSIGNED_ACC"  "$ACCOUNTS"  || echo "   - accounts 使用系统盘：$ACCOUNTS"
[[ -n "$ASSIGNED_LED"  ]] && mount_one "$ASSIGNED_LED"  "$LEDGER"    || echo "   - ledger  使用系统盘：$LEDGER"
[[ -n "$ASSIGNED_SNAP" ]] && mount_one "$ASSIGNED_SNAP" "$SNAPSHOT"  || echo "   - snapshot使用系统盘：$SNAPSHOT"

echo ""
echo "==> 3) 系统优化（极限网络性能）..."
if [[ -f "$SCRIPT_DIR/system-optimize.sh" ]]; then
  bash "$SCRIPT_DIR/system-optimize.sh"
else
  echo "   ⚠️  找不到 system-optimize.sh，跳过系统优化"
fi

echo ""
echo "============================================"
echo "✅ 步骤 1 完成!"
echo "============================================"
echo ""
echo "已完成:"
echo "  - 目录结构创建"
echo "  - 数据盘挂载（如有）"
echo "  - 系统参数优化"
echo ""
echo "下一步: bash /root/2-install-solana.sh"
echo ""
