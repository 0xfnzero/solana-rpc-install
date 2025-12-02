#!/bin/bash
# 诊断挂载问题

BASE=${BASE:-/root/sol}
LEDGER="$BASE/ledger"
ACCOUNTS="$BASE/accounts"
SNAPSHOT="$BASE/snapshot"

echo "=========================================="
echo "磁盘挂载问题诊断"
echo "=========================================="
echo ""

echo "1. 检查当前挂载状态："
echo "----------------------------------------"
CURRENT_ACC_MOUNT=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $6}')
CURRENT_LED_MOUNT=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $6}')
CURRENT_SNAP_MOUNT=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $6}')

CURRENT_ACC_DEV=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $1}')
CURRENT_LED_DEV=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $1}')
CURRENT_SNAP_DEV=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $1}')

echo "Accounts:"
echo "  设备: $CURRENT_ACC_DEV"
echo "  挂载点: $CURRENT_ACC_MOUNT"
echo "  目标: $ACCOUNTS"
echo "  匹配: $([[ "$CURRENT_ACC_MOUNT" == "$ACCOUNTS" ]] && echo "是" || echo "否")"
echo ""

echo "Ledger:"
echo "  设备: $CURRENT_LED_DEV"
echo "  挂载点: $CURRENT_LED_MOUNT"
echo "  目标: $LEDGER"
echo "  匹配: $([[ "$CURRENT_LED_MOUNT" == "$LEDGER" ]] && echo "是" || echo "否")"
echo ""

echo "Snapshot:"
echo "  设备: $CURRENT_SNAP_DEV"
echo "  挂载点: $CURRENT_SNAP_MOUNT"
echo "  目标: $SNAPSHOT"
echo "  匹配: $([[ "$CURRENT_SNAP_MOUNT" == "$SNAPSHOT" ]] && echo "是" || echo "否")"
echo ""

echo "2. 检查优先级错误检测："
echo "----------------------------------------"
if [[ "$CURRENT_ACC_MOUNT" != "$ACCOUNTS" ]]; then
    echo "✓ Accounts 未独立挂载（在 $CURRENT_ACC_MOUNT）"
    if [[ "$CURRENT_LED_MOUNT" == "$LEDGER" ]]; then
        echo "✓ Ledger 已独立挂载 → 应该触发 NEED_FIX=true"
    elif [[ "$CURRENT_SNAP_MOUNT" == "$SNAPSHOT" ]]; then
        echo "✓ Snapshot 已独立挂载 → 应该触发 NEED_FIX=true"
    else
        echo "✗ Ledger 和 Snapshot 都未独立挂载 → NEED_FIX=false"
    fi
else
    echo "✗ Accounts 已独立挂载 → 无需修复"
fi
echo ""

echo "3. 检查系统盘："
echo "----------------------------------------"
ROOT_SRC=$(findmnt -no SOURCE / || true)
ROOT_DISK=""
if [[ -n "${ROOT_SRC:-}" ]]; then
  ROOT_DISK=$(lsblk -no pkname "$ROOT_SRC" 2>/dev/null || true)
  [[ -n "$ROOT_DISK" ]] && ROOT_DISK="/dev/$ROOT_DISK"
fi
echo "根分区源: $ROOT_SRC"
echo "系统盘: ${ROOT_DISK:-未检测到}"
echo ""

echo "4. 检查可用数据盘："
echo "----------------------------------------"
MAP_DISKS=($(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'))
echo "所有磁盘: ${MAP_DISKS[*]}"
echo ""

AVAILABLE_DISKS=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"
  echo "检查: $disk"

  if [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]]; then
      echo "  → 跳过（系统盘）"
      continue
  fi

  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))

  if ((${#parts[@]}==0)); then
    echo "  → 整盘无分区，加入候选"
    AVAILABLE_DISKS+=("$disk")
  else
    echo "  → 有 ${#parts[@]} 个分区"
    best=""; best_size=0
    for p in "${parts[@]}"; do
      part="/dev/$p"
      size=$(lsblk -bno SIZE "$part")
      echo "     分区: $part, 大小: $size"
      (( size > best_size )) && { best="$part"; best_size=$size; }
    done
    if [[ -n "$best" ]]; then
      echo "  → 选择最大分区: $best"
      AVAILABLE_DISKS+=("$best")
    fi
  fi
done

echo ""
echo "可用数据盘数量: ${#AVAILABLE_DISKS[@]}"
echo "可用数据盘列表: ${AVAILABLE_DISKS[*]:-无}"
echo ""

echo "5. 按优先级分配应该是："
echo "----------------------------------------"
if ((${#AVAILABLE_DISKS[@]} >= 1)); then
    echo "Accounts → ${AVAILABLE_DISKS[0]}"
fi
if ((${#AVAILABLE_DISKS[@]} >= 2)); then
    echo "Ledger   → ${AVAILABLE_DISKS[1]}"
else
    echo "Ledger   → 系统盘"
fi
if ((${#AVAILABLE_DISKS[@]} >= 3)); then
    echo "Snapshot → ${AVAILABLE_DISKS[2]}"
else
    echo "Snapshot → 系统盘"
fi
echo ""

echo "6. 检查设备当前挂载状态："
echo "----------------------------------------"
for disk in "${AVAILABLE_DISKS[@]}"; do
    if findmnt -no TARGET "$disk" &>/dev/null; then
        current=$(findmnt -no TARGET "$disk")
        echo "$disk → $current (已挂载)"
    else
        echo "$disk → 未挂载"
    fi
done
echo ""

echo "=========================================="
echo "诊断完成"
echo "=========================================="
echo ""
echo "请将以上输出发送给技术支持"
