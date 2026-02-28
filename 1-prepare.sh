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

# 收集所有系统盘（包含 /, /boot, /boot/efi 的磁盘）
SYSTEM_DISKS=()

# 检测根分区所在磁盘
for mount_point in "/" "/boot" "/boot/efi"; do
  src=$(findmnt -no SOURCE "$mount_point" 2>/dev/null || true)
  if [[ -n "$src" ]]; then
    # 获取磁盘名（可能是 /dev/nvme0n1p2, /dev/mapper/vg0-root 等）
    disk=$(lsblk -no pkname "$src" 2>/dev/null | head -1 || true)
    if [[ -n "$disk" ]]; then
      SYSTEM_DISKS+=("/dev/$disk")
    fi
  fi
done

# 去重
SYSTEM_DISKS=($(printf '%s\n' "${SYSTEM_DISKS[@]}" | sort -u))

if ((${#SYSTEM_DISKS[@]} > 0)); then
  echo "   检测到系统盘："
  for disk in "${SYSTEM_DISKS[@]}"; do
    echo "     - $disk"
  done
else
  echo "   ⚠️  未能检测到系统盘"
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

  # 检测或创建文件系统
  local fs_type=""
  if has_fs "$dev"; then
    # 检测现有文件系统类型
    fs_type=$(blkid -o value -s TYPE "$dev" 2>/dev/null || echo "")
    if [[ -n "$fs_type" ]]; then
      echo "   - 检测到现有文件系统：$fs_type，保留"
    else
      # 有文件系统但检测不到类型，使用 auto
      fs_type="auto"
      echo "   - 检测到文件系统但类型未知，使用 auto"
    fi
  else
    # 没有文件系统，创建 ext4
    echo "   - 为 $dev 创建 ext4 文件系统（首次使用）"
    mkfs.ext4 -F "$dev" >/dev/null 2>&1
    fs_type="ext4"
  fi

  # 创建目标目录并挂载
  mkdir -p "$target"
  mount "$dev" "$target" || {
    echo "   ⚠️  挂载失败：$dev -> $target"
    return 1
  }

  # 更新 fstab 配置（先清理设备的所有旧配置，再添加新配置）
  sed -i "\|^${dev} |d" /etc/fstab 2>/dev/null || true
  sed -i "\|^[^ ]* ${target} |d" /etc/fstab 2>/dev/null || true

  # 使用检测到的文件系统类型（xfs, ext4, 或 auto）
  echo "$dev $target $fs_type defaults 0 0" >> /etc/fstab

  echo "   - ✅ 挂载完成：$dev -> $target ($fs_type)"
}

# ---------- 步骤 2.1: 收集所有可用数据盘 ----------
echo "==> 2.1) 收集可用数据盘..."

# 辅助函数：严格检查是否为系统关键分区
is_system_partition() {
  local dev="$1"

  # 未挂载的分区不是系统分区
  if ! findmnt -no TARGET "$dev" &>/dev/null; then
    return 1
  fi

  local mount_point=$(findmnt -no TARGET "$dev" 2>/dev/null || echo "")

  # 严格匹配系统关键路径
  case "$mount_point" in
    "/"|\
    "/boot"|\
    "/boot/"*|\
    "/boot/efi"|\
    "/efi"|\
    "/efi/"*|\
    *"/swap"*|\
    "[SWAP]")
      return 0  # 是系统分区
      ;;
    *)
      return 1  # 不是系统分区
      ;;
  esac
}

AVAILABLE_DISKS=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"

  # 跳过所有系统盘
  is_sys_disk=false
  for sys_disk in "${SYSTEM_DISKS[@]}"; do
    if [[ "$disk" == "$sys_disk" ]]; then
      echo "   - 跳过系统盘：$disk"
      is_sys_disk=true
      break
    fi
  done
  [[ "$is_sys_disk" == true ]] && continue

  # 获取所有分区
  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))

  if ((${#parts[@]}==0)); then
    # 整盘无分区 - 检查是否被系统使用
    if is_system_partition "$disk"; then
      echo "   - 跳过系统盘：$disk (系统挂载：$(findmnt -no TARGET "$disk" 2>/dev/null))"
      continue
    fi

    size=$(lsblk -bno SIZE "$disk" 2>/dev/null | head -1 | tr -d '[:space:]')
    size_gb=$((size / 1024 / 1024 / 1024))
    AVAILABLE_DISKS+=("$disk")
    echo "   - 可用数据盘：$disk (整盘, ${size_gb}GB)"
  else
    # 有分区 - 选择最大的非系统分区
    echo "   - 扫描磁盘分区：$disk"
    best=""; best_size=0

    for p in "${parts[@]}"; do
      part="/dev/$p"

      # 检查是否为系统分区
      if is_system_partition "$part"; then
        mnt=$(findmnt -no TARGET "$part" 2>/dev/null || echo "未知")
        echo "     ✗ 跳过系统分区：$part -> $mnt"
        continue
      fi

      # 获取分区大小
      size=$(lsblk -bno SIZE "$part" 2>/dev/null | head -1 | tr -d '[:space:]')

      # 验证是否为有效数字
      if [[ -z "$size" ]] || [[ ! "$size" =~ ^[0-9]+$ ]]; then
        echo "     ✗ 跳过无效分区：$part (无法读取大小)"
        continue
      fi

      size_gb=$((size / 1024 / 1024 / 1024))
      echo "     ✓ 发现非系统分区：$part (${size_gb}GB)"

      # 选择最大的分区
      if (( size > best_size )); then
        best="$part"
        best_size=$size
      fi
    done

    if [[ -n "$best" ]]; then
      best_size_gb=$((best_size / 1024 / 1024 / 1024))
      AVAILABLE_DISKS+=("$best")
      echo "   - 可用数据盘：$best (最大非系统分区, ${best_size_gb}GB)"
    else
      echo "   - 跳过 $disk：所有分区均为系统分区"
    fi
  fi
done

if ((${#AVAILABLE_DISKS[@]}==0)); then
    echo "   ⚠️  未检测到可用数据盘，所有目录将使用系统盘"
else
    echo ""
    echo "   检测到 ${#AVAILABLE_DISKS[@]} 个可用数据盘"
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
