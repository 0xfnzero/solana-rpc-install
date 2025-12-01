#!/bin/bash
set -euo pipefail

# ============================================
# 强制按优先级重新分配磁盘挂载
# 用途：修复挂载优先级错误的问题
# ============================================

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE=${BASE:-/root/sol}
LEDGER="$BASE/ledger"
ACCOUNTS="$BASE/accounts"
SNAPSHOT="$BASE/snapshot"

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERROR] 请用 root 执行：sudo bash $0${NC}" >&2
  exit 1
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}强制按优先级重新分配磁盘挂载${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

echo -e "${YELLOW}⚠️  警告：此脚本将重新调整所有 Solana 数据目录的挂载${NC}"
echo -e "${YELLOW}   确保 Solana 节点已停止！${NC}"
echo ""

# 检查 Solana 服务是否在运行
if systemctl is-active --quiet sol 2>/dev/null; then
    echo -e "${RED}❌ 错误：Solana 节点正在运行！${NC}"
    echo -e "${RED}   请先停止节点：systemctl stop sol${NC}"
    exit 1
fi

read -p "确认继续？(yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "操作已取消"
    exit 0
fi

echo ""
echo -e "${BLUE}==> 1) 检测当前挂载状态...${NC}"
# 显示当前挂载
echo "   当前 Solana 目录挂载："
df -h "$ACCOUNTS" "$LEDGER" "$SNAPSHOT" 2>/dev/null | grep -v "Filesystem" | awk '{printf "   - %-20s %s\n", $6, $1}' || true

echo ""
echo -e "${BLUE}==> 2) 卸载所有 Solana 数据目录...${NC}"
# 卸载所有可能的挂载（从子目录开始）
for dir in "$SNAPSHOT" "$LEDGER" "$ACCOUNTS"; do
    if mountpoint -q "$dir" 2>/dev/null; then
        echo "   - 卸载：$dir"
        umount "$dir" || {
            echo -e "${RED}   ⚠️  无法卸载 $dir，可能有进程正在使用${NC}"
            echo "   正在使用的进程："
            lsof 2>/dev/null | grep "$dir" | head -5 || fuser -m "$dir" 2>/dev/null || true
            exit 1
        }
    else
        echo "   - 跳过（未挂载）：$dir"
    fi
done

echo ""
echo -e "${BLUE}==> 3) 清理 /etc/fstab 中的旧配置...${NC}"
# 备份 fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
echo "   - 备份 fstab 完成"

# 清理 Solana 相关挂载
sed -i "\|$ACCOUNTS|d" /etc/fstab
sed -i "\|$LEDGER|d" /etc/fstab
sed -i "\|$SNAPSHOT|d" /etc/fstab
echo "   - 清理旧配置完成"

echo ""
echo -e "${BLUE}==> 4) 检测可用数据盘...${NC}"
# 获取系统盘
ROOT_SRC=$(findmnt -no SOURCE / || true)
ROOT_DISK=""
if [[ -n "${ROOT_SRC:-}" ]]; then
  ROOT_DISK=$(lsblk -no pkname "$ROOT_SRC" 2>/dev/null || true)
  [[ -n "$ROOT_DISK" ]] && ROOT_DISK="/dev/$ROOT_DISK"
fi

echo "   系统盘：${ROOT_DISK:-未检测到}"

# 获取所有磁盘
MAP_DISKS=($(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}'))

is_mounted_dev() { findmnt -no TARGET "$1" &>/dev/null; }
has_fs() { blkid -o value -s TYPE "$1" &>/dev/null; }

# 收集所有可用的数据盘（整盘，非系统盘）
AVAILABLE_DISKS=()
for d in "${MAP_DISKS[@]}"; do
  disk="/dev/$d"
  # 跳过系统盘
  [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]] && continue

  # 检查是否有分区
  parts=($(lsblk -n -o NAME,TYPE "$disk" | awk '$2=="part"{gsub(/^[├─└│ ]*/, "", $1); print $1}'))

  if ((${#parts[@]}==0)); then
    # 整盘无分区，直接使用
    AVAILABLE_DISKS+=("$disk")
    echo "   - 可用数据盘：$disk (整盘)"
  else
    echo "   - 跳过 $disk (有分区，请手动处理或使用最大分区)"
  fi
done

if ((${#AVAILABLE_DISKS[@]}==0)); then
    echo -e "${YELLOW}   ⚠️  未检测到可用的整盘数据盘${NC}"
    echo "   建议：检查磁盘是否有分区，或使用 1-prepare.sh 自动处理"
    exit 0
fi

echo ""
echo -e "${BLUE}==> 5) 按优先级分配磁盘...${NC}"
echo -e "${YELLOW}   优先级：Accounts (最高) > Ledger (中等) > Snapshot (最低)${NC}"
echo ""

mount_to_target() {
    local dev="$1"
    local target="$2"
    local label="$3"

    # 检查是否有文件系统
    if ! has_fs "$dev"; then
        echo "   - [$label] 创建 ext4 文件系统：$dev"
        mkfs.ext4 -F "$dev" >/dev/null 2>&1
    else
        local fstype=$(blkid -o value -s TYPE "$dev")
        echo "   - [$label] 检测到现有文件系统：$fstype"
    fi

    # 创建目标目录
    mkdir -p "$target"

    # 挂载
    echo "   - [$label] 挂载：$dev -> $target"
    mount "$dev" "$target"

    # 添加到 fstab
    echo "$dev $target ext4 defaults 0 0" >> /etc/fstab
    echo -e "   - [$label] ${GREEN}✓ 完成${NC}"
    echo ""
}

# 按优先级分配
if ((${#AVAILABLE_DISKS[@]} >= 1)); then
    mount_to_target "${AVAILABLE_DISKS[0]}" "$ACCOUNTS" "Accounts (第1优先级)"
fi

if ((${#AVAILABLE_DISKS[@]} >= 2)); then
    mount_to_target "${AVAILABLE_DISKS[1]}" "$LEDGER" "Ledger (第2优先级)"
else
    echo "   - [Ledger] 使用系统盘：$LEDGER"
fi

if ((${#AVAILABLE_DISKS[@]} >= 3)); then
    mount_to_target "${AVAILABLE_DISKS[2]}" "$SNAPSHOT" "Snapshot (第3优先级)"
else
    echo "   - [Snapshot] 使用系统盘：$SNAPSHOT"
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}✅ 磁盘重新分配完成！${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "挂载配置："
df -h "$ACCOUNTS" "$LEDGER" "$SNAPSHOT" 2>/dev/null | grep -v "Filesystem" | while read line; do
    echo "  $line"
done

echo ""
echo -e "${BLUE}下一步：${NC}"
echo "  1. 运行验证：bash verify-mounts.sh"
echo "  2. 启动节点：systemctl start sol"
echo ""
