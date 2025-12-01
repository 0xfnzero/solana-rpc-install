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

# ---------- 步骤 2.1: 收集所有可用数据盘 ----------
echo "==> 2.1) 收集可用数据盘..."
AVAILABLE_DISKS=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"
  [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]] && continue
  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))
  if ((${#parts[@]}==0)); then
    # 整盘无分区
    AVAILABLE_DISKS+=("$disk")
    echo "   - 可用数据盘：$disk (整盘)"
  else
    # 有分区，选择最大分区
    best=""; best_size=0
    for p in "${parts[@]}"; do
      part="/dev/$p"
      size=$(lsblk -bno SIZE "$part")
      (( size > best_size )) && { best="$part"; best_size=$size; }
    done
    if [[ -n "$best" ]]; then
      AVAILABLE_DISKS+=("$best")
      echo "   - 可用数据盘：$best (最大分区)"
    fi
  fi
done

if ((${#AVAILABLE_DISKS[@]}==0)); then
    echo "   - 未检测到可用数据盘，所有目录将使用系统盘"
fi

echo ""
echo "==> 2.2) 检查当前挂载状态..."
CURRENT_ACC_MOUNT=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $6}')
CURRENT_LED_MOUNT=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $6}')
CURRENT_SNAP_MOUNT=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $6}')

CURRENT_ACC_DEV=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $1}')
CURRENT_LED_DEV=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $1}')
CURRENT_SNAP_DEV=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $1}')

echo "   当前状态："
echo "   - Accounts: ${CURRENT_ACC_DEV} -> ${CURRENT_ACC_MOUNT}"
echo "   - Ledger:   ${CURRENT_LED_DEV} -> ${CURRENT_LED_MOUNT}"
echo "   - Snapshot: ${CURRENT_SNAP_DEV} -> ${CURRENT_SNAP_MOUNT}"

# ---------- 步骤 2.3: 检测并修复优先级错误 ----------
echo ""
echo "==> 2.3) 检测挂载优先级..."
NEED_FIX=false

# 检测优先级错误：accounts 未独立挂载，但 ledger 或 snapshot 独立挂载了
if [[ "$CURRENT_ACC_MOUNT" != "$ACCOUNTS" ]]; then
    if [[ "$CURRENT_LED_MOUNT" == "$LEDGER" ]] || [[ "$CURRENT_SNAP_MOUNT" == "$SNAPSHOT" ]]; then
        echo "   ⚠️  检测到优先级错误："
        echo "   - Accounts 应该优先获得数据盘（性能需求最高）"
        echo "   - 当前 Accounts 在系统盘上，而低优先级目录占用了数据盘"
        NEED_FIX=true
    fi
fi

if $NEED_FIX && ((${#AVAILABLE_DISKS[@]}>0)); then
    echo ""
    echo "   🔧 自动修复优先级..."

    # 卸载所有 Solana 数据目录（从子目录开始，避免嵌套问题）
    for dir in "$SNAPSHOT" "$LEDGER" "$ACCOUNTS"; do
        if mountpoint -q "$dir" 2>/dev/null; then
            echo "   - 卸载：$dir"
            umount "$dir" || {
                echo "   ⚠️  无法卸载 $dir，可能有进程正在使用"
                echo "   请先停止相关服务后重新运行脚本"
                exit 1
            }
        fi
    done

    # 清理 fstab 中的旧配置
    echo "   - 清理 /etc/fstab 旧配置"
    sed -i "\|$ACCOUNTS|d" /etc/fstab 2>/dev/null || true
    sed -i "\|$LEDGER|d" /etc/fstab 2>/dev/null || true
    sed -i "\|$SNAPSHOT|d" /etc/fstab 2>/dev/null || true

    echo "   ✓ 优先级错误已清理，准备重新挂载"
    echo ""
fi

# ---------- 步骤 2.4: 按优先级挂载 ----------
echo "==> 2.4) 按优先级挂载数据盘..."
echo "   优先级：Accounts (最高) > Ledger (中等) > Snapshot (最低)"
echo ""

# 优先级 1: Accounts
if ((${#AVAILABLE_DISKS[@]} >= 1)); then
    mount_one "${AVAILABLE_DISKS[0]}" "$ACCOUNTS" || echo "   ⚠️  挂载 accounts 失败"
else
    echo "   - Accounts: 使用系统盘（无可用数据盘）"
fi

# 优先级 2: Ledger
if ((${#AVAILABLE_DISKS[@]} >= 2)); then
    mount_one "${AVAILABLE_DISKS[1]}" "$LEDGER" || echo "   ⚠️  挂载 ledger 失败"
else
    echo "   - Ledger: 使用系统盘"
fi

# 优先级 3: Snapshot
if ((${#AVAILABLE_DISKS[@]} >= 3)); then
    mount_one "${AVAILABLE_DISKS[2]}" "$SNAPSHOT" || echo "   ⚠️  挂载 snapshot 失败"
else
    echo "   - Snapshot: 使用系统盘"
fi

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
