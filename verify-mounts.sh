#!/usr/bin/env bash
#
# verify-mounts.sh - 验证 Solana 节点存储挂载配置
#
# 用途：
#   - 检查 accounts/ledger/snapshot 目录是否正确挂载
#   - 验证磁盘性能是否满足要求
#   - 检查空间使用情况和告警阈值
#
# 使用：
#   sudo bash verify-mounts.sh
#

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Solana 数据目录
ACCOUNTS="/root/sol/accounts"
LEDGER="/root/sol/ledger"
SNAPSHOT="/root/sol/snapshot"

# 告警阈值
WARN_USAGE=75      # 磁盘使用率告警（%）
CRITICAL_USAGE=90  # 磁盘使用率严重告警（%）

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    Solana 节点存储挂载配置验证${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# ============================================
# 1. 检查目录是否存在
# ============================================
echo -e "${BLUE}[1] 检查 Solana 数据目录${NC}"
echo "--------------------------------------------"

check_directory() {
    local dir="$1"
    local name="$2"

    if [[ -d "$dir" ]]; then
        echo -e "  ✓ ${GREEN}$name${NC}: $dir 存在"
        return 0
    else
        echo -e "  ✗ ${RED}$name${NC}: $dir 不存在"
        return 1
    fi
}

check_directory "$ACCOUNTS" "Accounts"
check_directory "$LEDGER" "Ledger"
check_directory "$SNAPSHOT" "Snapshot"
echo ""

# ============================================
# 2. 检查挂载点配置
# ============================================
echo -e "${BLUE}[2] 检查挂载点配置${NC}"
echo "--------------------------------------------"

check_mount() {
    local dir="$1"
    local name="$2"

    if [[ ! -d "$dir" ]]; then
        echo -e "  ⊘ ${YELLOW}$name${NC}: 目录不存在，跳过"
        return 0
    fi

    local mount_point=$(df -P "$dir" | tail -1 | awk '{print $6}')
    local device=$(df -P "$dir" | tail -1 | awk '{print $1}')
    local fstype=$(df -T "$dir" | tail -1 | awk '{print $2}')

    echo -e "  • ${name}:"
    echo -e "    - 路径: $dir"
    echo -e "    - 设备: $device"
    echo -e "    - 类型: $fstype"
    echo -e "    - 挂载点: $mount_point"

    # 判断是否独立挂载
    if [[ "$mount_point" == "$dir" ]]; then
        echo -e "    - 状态: ${GREEN}独立挂载${NC} ✓"
    else
        echo -e "    - 状态: ${YELLOW}在 $mount_point 分区上${NC}"
    fi
    echo ""
}

check_mount "$ACCOUNTS" "Accounts"
check_mount "$LEDGER" "Ledger"
check_mount "$SNAPSHOT" "Snapshot"

# ============================================
# 3. 检查磁盘空间使用
# ============================================
echo -e "${BLUE}[3] 检查磁盘空间使用${NC}"
echo "--------------------------------------------"

check_disk_usage() {
    local dir="$1"
    local name="$2"

    if [[ ! -d "$dir" ]]; then
        echo -e "  ⊘ ${YELLOW}$name${NC}: 目录不存在，跳过"
        return 0
    fi

    local usage=$(df -h "$dir" | tail -1 | awk '{print $5}' | sed 's/%//')
    local used=$(df -h "$dir" | tail -1 | awk '{print $3}')
    local avail=$(df -h "$dir" | tail -1 | awk '{print $4}')
    local size=$(df -h "$dir" | tail -1 | awk '{print $2}')

    echo -e "  • ${name}: $dir"
    echo -e "    - 总大小: $size"
    echo -e "    - 已使用: $used"
    echo -e "    - 可用: $avail"

    if (( usage >= CRITICAL_USAGE )); then
        echo -e "    - 使用率: ${RED}${usage}%${NC} 🚨 严重告警！"
    elif (( usage >= WARN_USAGE )); then
        echo -e "    - 使用率: ${YELLOW}${usage}%${NC} ⚠️  需要关注"
    else
        echo -e "    - 使用率: ${GREEN}${usage}%${NC} ✓"
    fi
    echo ""
}

check_disk_usage "$ACCOUNTS" "Accounts"
check_disk_usage "$LEDGER" "Ledger"
check_disk_usage "$SNAPSHOT" "Snapshot"

# ============================================
# 4. 检查 fstab 持久化配置
# ============================================
echo -e "${BLUE}[4] 检查 /etc/fstab 持久化配置${NC}"
echo "--------------------------------------------"

if [[ -f /etc/fstab ]]; then
    echo "  检查 accounts 挂载配置..."
    if grep -q "$ACCOUNTS" /etc/fstab 2>/dev/null; then
        echo -e "    ✓ ${GREEN}accounts 已在 fstab 中配置${NC}"
        grep "$ACCOUNTS" /etc/fstab | sed 's/^/      /'
    else
        echo -e "    ⚠️  ${YELLOW}accounts 未在 fstab 中（重启后可能丢失挂载）${NC}"
    fi
    echo ""

    echo "  检查 ledger 挂载配置..."
    if grep -q "$LEDGER" /etc/fstab 2>/dev/null; then
        echo -e "    ✓ ${GREEN}ledger 已在 fstab 中配置${NC}"
        grep "$LEDGER" /etc/fstab | sed 's/^/      /'
    else
        echo -e "    ⊘ ${YELLOW}ledger 未在 fstab 中（可能与系统盘共用）${NC}"
    fi
    echo ""

    echo "  检查 snapshot 挂载配置..."
    if grep -q "$SNAPSHOT" /etc/fstab 2>/dev/null; then
        echo -e "    ✓ ${GREEN}snapshot 已在 fstab 中配置${NC}"
        grep "$SNAPSHOT" /etc/fstab | sed 's/^/      /'
    else
        echo -e "    ⊘ ${YELLOW}snapshot 未在 fstab 中（可能与系统盘共用）${NC}"
    fi
else
    echo -e "  ${RED}/etc/fstab 不存在${NC}"
fi
echo ""

# ============================================
# 5. 检查磁盘设备信息
# ============================================
echo -e "${BLUE}[5] 检查 NVMe 磁盘设备信息${NC}"
echo "--------------------------------------------"

if command -v lsblk &>/dev/null; then
    echo "  当前磁盘布局："
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT | grep -E "NAME|nvme" | sed 's/^/    /'
else
    echo -e "  ${YELLOW}lsblk 命令不可用${NC}"
fi
echo ""

# ============================================
# 6. 检查实际数据大小
# ============================================
echo -e "${BLUE}[6] 检查 Solana 数据目录大小${NC}"
echo "--------------------------------------------"

check_dir_size() {
    local dir="$1"
    local name="$2"

    if [[ ! -d "$dir" ]]; then
        echo -e "  ⊘ ${YELLOW}$name${NC}: 目录不存在，跳过"
        return 0
    fi

    echo -e "  • 计算 ${name} 大小（可能需要几秒钟）..."
    local size=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    echo -e "    - $dir: ${GREEN}$size${NC}"
}

check_dir_size "$ACCOUNTS" "Accounts"
check_dir_size "$LEDGER" "Ledger"
check_dir_size "$SNAPSHOT" "Snapshot"
echo ""

# ============================================
# 7. 性能建议
# ============================================
echo -e "${BLUE}[7] 性能建议${NC}"
echo "--------------------------------------------"

# 检查 accounts 是否独立挂载
ACCOUNTS_MOUNT=$(df -P "$ACCOUNTS" 2>/dev/null | tail -1 | awk '{print $6}')
if [[ "$ACCOUNTS_MOUNT" == "$ACCOUNTS" ]]; then
    echo -e "  ✓ ${GREEN}Accounts 已独立挂载${NC} - 性能配置最优"
else
    echo -e "  ⚠️  ${YELLOW}Accounts 未独立挂载${NC}"
    echo -e "     建议：将 accounts 挂载到独立的 NVMe 磁盘以获得最佳性能"
    echo -e "     参考：MOUNT_STRATEGY.md"
fi
echo ""

# 检查 ledger 和 snapshot 是否在同一分区
LEDGER_MOUNT=$(df -P "$LEDGER" 2>/dev/null | tail -1 | awk '{print $6}')
SNAPSHOT_MOUNT=$(df -P "$SNAPSHOT" 2>/dev/null | tail -1 | awk '{print $6}')

if [[ "$LEDGER_MOUNT" == "$SNAPSHOT_MOUNT" ]]; then
    echo -e "  ✓ ${GREEN}Ledger 和 Snapshot 共享分区${NC} - 合理配置"
else
    echo -e "  ⊘ Ledger 和 Snapshot 在不同分区"
fi
echo ""

# ============================================
# 8. 总结和建议
# ============================================
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    验证总结${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

echo -e "${GREEN}✓ 推荐配置：${NC}"
echo -e "  • Accounts: 独立 NVMe 磁盘（最高性能）"
echo -e "  • Ledger: 系统盘或第二块磁盘（中等性能）"
echo -e "  • Snapshot: 与 Ledger 共享（低性能需求）"
echo ""

echo -e "${YELLOW}⚠️  监控建议：${NC}"
echo -e "  • 磁盘使用率 >75%: 开始清理或扩容规划"
echo -e "  • 磁盘使用率 >90%: 立即清理或扩容"
echo -e "  • 定期清理旧快照（保留 2-3 个最新）"
echo -e "  • 使用 --limit-ledger-size 限制 ledger 增长"
echo ""

echo -e "${BLUE}📚 参考文档：${NC}"
echo -e "  • 挂载策略: MOUNT_STRATEGY.md"
echo -e "  • 性能监控: bash performance-monitor.sh"
echo -e "  • 配置优化: OPTIMIZATION_GUIDE.md"
echo ""

echo -e "${GREEN}验证完成！${NC}"
