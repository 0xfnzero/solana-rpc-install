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
  if is_mounted_dev "$dev"; then
    echo "   - 已挂载：$dev -> $(findmnt -no TARGET "$dev")，跳过"; return 0
  fi
  if ! has_fs "$dev"; then
    echo "   - 为 $dev 创建 ext4 文件系统（首次使用）"; mkfs.ext4 -F "$dev"
  fi
  mkdir -p "$target"
  mount -o defaults "$dev" "$target"
  if ! grep -qE "^[^ ]+ +$target " /etc/fstab; then
    echo "$dev $target ext4 defaults 0 0" >> /etc/fstab
  fi
  echo "   - 挂载完成：$dev -> $target"
}

# 收集候选设备（排除系统盘；对有分区的磁盘选择最大未挂载分区）
CANDIDATES=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"
  [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]] && continue
  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))
  if ((${#parts[@]}==0)); then
    is_mounted_dev "$disk" || CANDIDATES+=("$disk")
  else
    best=""; best_size=0
    for p in "${parts[@]}"; do
      part="/dev/$p"; is_mounted_dev "$part" && continue
      size=$(lsblk -bno SIZE "$part")
      (( size > best_size )) && { best="$part"; best_size=$size; }
    done
    [[ -n "$best" ]] && CANDIDATES+=("$best")
  fi
done

echo "   候选数据设备：${CANDIDATES[*]:-"<无>"}"
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
