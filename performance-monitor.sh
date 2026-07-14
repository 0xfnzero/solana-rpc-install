#!/bin/bash
set -euo pipefail

# ============================================
# Solana RPC Node Performance Monitor
# ============================================
# Real-time monitoring and alerting for:
# - Memory usage and pressure
# - CPU utilization and throttling
# - Network bandwidth and latency
# - Disk I/O performance
# - Validator health metrics
# ============================================

LOGFILE=${LOGFILE:-/var/log/solana-performance.log}
VALIDATOR_LOG=${VALIDATOR_LOG:-/root/solana-rpc.log}
SERVICE_NAME=${SERVICE_NAME:-sol}
DIAGNOSTIC_DIR=${DIAGNOSTIC_DIR:-/var/log}
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEM=85
ALERT_THRESHOLD_DISK=90
CHECK_INTERVAL=60  # seconds

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

log_metric() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] METRIC: $*" | tee -a "$LOGFILE"
}

alert() {
    echo -e "${RED}[ALERT]${NC} $*" | tee -a "$LOGFILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOGFILE"
}

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

is_uint() {
    [[ ${1:-} =~ ^[0-9]+$ ]]
}

read_service_memory() {
    command -v systemctl >/dev/null 2>&1 || return 0

    local memory_current memory_peak memory_high memory_max control_group peak_file
    memory_current=$(systemctl show "$SERVICE_NAME" -p MemoryCurrent --value 2>/dev/null || true)
    memory_peak=$(systemctl show "$SERVICE_NAME" -p MemoryPeak --value 2>/dev/null || true)
    memory_high=$(systemctl show "$SERVICE_NAME" -p MemoryHigh --value 2>/dev/null || true)
    memory_max=$(systemctl show "$SERVICE_NAME" -p MemoryMax --value 2>/dev/null || true)

    # systemd 249 on Ubuntu 22.04 does not expose MemoryPeak, but cgroup v2 does.
    if ! is_uint "$memory_peak"; then
        control_group=$(systemctl show "$SERVICE_NAME" -p ControlGroup --value 2>/dev/null || true)
        peak_file="/sys/fs/cgroup${control_group}/memory.peak"
        if [[ -n "$control_group" && -r "$peak_file" ]]; then
            memory_peak=$(<"$peak_file")
        else
            memory_peak="unavailable"
        fi
    fi

    log_metric "CGROUP_MEMORY CURRENT=${memory_current:-unavailable} PEAK=$memory_peak HIGH=${memory_high:-unavailable} MAX=${memory_max:-unavailable}"
}

# Check if validator is running (Jito/Agave: agave-validator or solana-validator)
check_validator_running() {
    if pgrep -x agave-validator >/dev/null; then
        VALIDATOR_PID=$(pgrep -x agave-validator | head -n1)
        return 0
    elif pgrep -x solana-validator >/dev/null; then
        VALIDATOR_PID=$(pgrep -x solana-validator | head -n1)
        return 0
    else
        alert "Validator is NOT running!"
        return 1
    fi
}

# CPU metrics
check_cpu() {
    local cpu_usage cpu_int validator_cpu
    cpu_usage=$(LC_ALL=C top -bn2 -d 0.5 2>/dev/null | awk '/Cpu\(s\)/ {value=$2} END {print value}' || true)
    [[ $cpu_usage =~ ^[0-9]+([.][0-9]+)?$ ]] || cpu_usage=0
    cpu_int=${cpu_usage%.*}

    log_metric "CPU_USAGE=${cpu_usage}%"

    if [[ $cpu_int -gt $ALERT_THRESHOLD_CPU ]]; then
        alert "High CPU usage: ${cpu_usage}%"
    fi

    if check_validator_running; then
        validator_cpu=$(ps -p "$VALIDATOR_PID" -o %cpu= 2>/dev/null || echo "0")
        log_metric "VALIDATOR_CPU=${validator_cpu}%"
        echo -e "${BLUE}CPU:${NC} System=${cpu_usage}% Validator=${validator_cpu}%"
    fi
}

# Memory metrics
check_memory() {
    local mem_total mem_used mem_available mem_percent
    local validator_mem validator_threads memory_pressure
    mem_total=$(free -m | awk 'NR==2{print $2}')
    mem_used=$(free -m | awk 'NR==2{print $3}')
    mem_available=$(free -m | awk 'NR==2{print $7}')
    mem_percent=$((mem_used * 100 / mem_total))

    log_metric "MEM_TOTAL=${mem_total}MB MEM_USED=${mem_used}MB MEM_AVAIL=${mem_available}MB MEM_PERCENT=${mem_percent}%"

    if [[ $mem_percent -gt $ALERT_THRESHOLD_MEM ]]; then
        alert "High memory usage: ${mem_percent}%"
    fi

    if check_validator_running; then
        validator_mem=$(ps -p "$VALIDATOR_PID" -o rss= 2>/dev/null | awk '{printf "%.2f", $1/1024/1024}')
        validator_threads=$(ps -p "$VALIDATOR_PID" -o nlwp= 2>/dev/null || echo "0")
        log_metric "VALIDATOR_MEM=${validator_mem}GB VALIDATOR_THREADS=${validator_threads}"
        echo -e "${BLUE}Memory:${NC} System=${mem_percent}% (${mem_used}/${mem_total}MB) Validator=${validator_mem}GB Threads=${validator_threads}"
    fi

    read_service_memory

    if [[ -r /proc/pressure/memory ]]; then
        memory_pressure=$(tr '\n' ' ' </proc/pressure/memory)
        log_metric "MEMORY_PRESSURE $memory_pressure"
        echo -e "${BLUE}Pressure:${NC} $memory_pressure"
    fi
}

# Disk I/O metrics
check_disk() {
    local path disk_usage disk_free
    declare -A checked_mounts=()

    for path in /root/sol /root/sol/accounts /root/sol/ledger /root/sol/snapshot; do
        [[ -d "$path" ]] || continue
        local mountpoint
        mountpoint=$(df -P "$path" | awk 'END {print $6}')
        [[ -n "${checked_mounts[$mountpoint]:-}" ]] && continue
        checked_mounts[$mountpoint]=1

        disk_usage=$(df -P "$path" | awk 'END {gsub(/%/, "", $5); print $5}')
        disk_free=$(df -hP "$path" | awk 'END {print $4}')
        log_metric "DISK_PATH=$path MOUNT=$mountpoint USAGE=${disk_usage}% FREE=$disk_free"
        echo -e "${BLUE}Disk:${NC} Path=$path Mount=$mountpoint Usage=${disk_usage}% Free=$disk_free"

        if [[ $disk_usage -gt $ALERT_THRESHOLD_DISK ]]; then
            alert "High disk usage on $mountpoint: ${disk_usage}%"
        fi
    done

    if [[ -d /root/sol/snapshot ]]; then
        local snapshot_size partial_count
        snapshot_size=$(du -sh /root/sol/snapshot 2>/dev/null | awk '{print $1}' || echo "unknown")
        partial_count=$(find /root/sol/snapshot -mindepth 1 -maxdepth 1 \
            \( -name 'tmp-*' -o -name '*.part' -o -name '*.tmp' -o -name '*.aria2' \) \
            2>/dev/null | wc -l)
        log_metric "SNAPSHOT_SIZE=$snapshot_size PARTIAL_FILES=$partial_count"
        if [[ $partial_count -gt 0 ]]; then
            warn "Snapshot directory contains $partial_count partial archive file(s)"
        fi
    fi

    # I/O stats
    if command -v iostat >/dev/null 2>&1; then
        local io_stats
        io_stats=$(iostat -x 1 2 | grep -E 'nvme|sd' | tail -n1 || true)
        [[ -n "$io_stats" ]] && log_metric "DISK_IO: $io_stats"
    fi
}

# Network metrics
check_network() {
    local net_iface rx_before tx_before rx_after tx_after rx_rate tx_rate conn_count
    net_iface=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}' || true)

    if [[ -n "$net_iface" ]]; then
        rx_before=$(<"/sys/class/net/$net_iface/statistics/rx_bytes")
        tx_before=$(<"/sys/class/net/$net_iface/statistics/tx_bytes")
        sleep 1
        rx_after=$(<"/sys/class/net/$net_iface/statistics/rx_bytes")
        tx_after=$(<"/sys/class/net/$net_iface/statistics/tx_bytes")

        rx_rate=$(( (rx_after - rx_before) / 1024 / 1024 ))
        tx_rate=$(( (tx_after - tx_before) / 1024 / 1024 ))

        log_metric "NET_RX=${rx_rate}MB/s NET_TX=${tx_rate}MB/s"
        echo -e "${BLUE}Network:${NC} RX=${rx_rate}MB/s TX=${tx_rate}MB/s"
    fi

    # Connection count
    conn_count=$(ss -Htan state established 2>/dev/null | wc -l || true)
    conn_count=${conn_count:-0}
    log_metric "NET_CONNECTIONS=${conn_count}"
}

# Validator health
check_validator_health() {
    if ! check_validator_running; then
        return 1
    fi

    local slot_height catchup health fd_count fd_limit fd_percent

    # Check slot height
    slot_height=$(solana slot 2>/dev/null || echo "ERROR")
    log_metric "SLOT_HEIGHT=${slot_height}"

    # Check catchup status
    catchup=$(solana catchup --our-localhost 2>/dev/null | grep "Slot" || echo "Unknown")
    log_metric "CATCHUP=${catchup}"

    # Check health
    health=$(curl -sS --max-time 5 -X POST http://localhost:8899 \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' 2>/dev/null | \
        grep -o '"result":"[^"]*"' || echo "Unknown")
    log_metric "HEALTH=${health}"

    echo -e "${BLUE}Validator:${NC} Slot=${slot_height} Health=${health}"

    # File descriptor usage
    fd_count=$(find "/proc/$VALIDATOR_PID/fd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    fd_limit=$(awk '/Max open files/ {print $4}' "/proc/$VALIDATOR_PID/limits")
    fd_percent=$((fd_count * 100 / fd_limit))
    log_metric "FD_USAGE=${fd_count}/${fd_limit} (${fd_percent}%)"

    if [[ $fd_percent -gt 80 ]]; then
        warn "High file descriptor usage: ${fd_percent}%"
    fi
}

# System performance issues
check_performance_issues() {
    # Check for OOM kills
    if dmesg -T | tail -n 100 | grep -qi "out of memory"; then
        alert "OOM killer detected in recent logs!"
    fi

    if command -v journalctl >/dev/null 2>&1 && \
       journalctl -u "$SERVICE_NAME" --since "1 hour ago" --no-pager 2>/dev/null | \
       grep -Eqi 'oom-kill|out of memory|memory cgroup out of memory'; then
        alert "Validator service reported an OOM event in the last hour!"
    fi

    # Check for CPU throttling
    if dmesg -T | tail -n 100 | grep -qi "cpu.*throttl"; then
        warn "CPU throttling detected!"
    fi

    # Check load average
    local load_avg cpu_cores load_normalized
    load_avg=$(awk '{print $1}' /proc/loadavg)
    cpu_cores=$(nproc)
    load_normalized=$(awk -v load="$load_avg" -v cores="$cpu_cores" 'BEGIN {printf "%.2f", load / cores}')

    log_metric "LOAD_AVG=${load_avg} LOAD_NORMALIZED=${load_normalized}"

    if awk -v value="$load_normalized" 'BEGIN {exit !(value > 0.8)}'; then
        warn "High normalized load average: ${load_normalized}"
    fi
}

# Performance snapshot
performance_snapshot() {
    echo "========================================="
    echo "Solana Performance Monitor"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================="

    check_cpu || warn "CPU metric collection failed"
    check_memory || warn "Memory metric collection failed"
    check_disk || warn "Disk metric collection failed"
    check_network || warn "Network metric collection failed"
    check_validator_health || true
    check_performance_issues || warn "System issue collection failed"

    echo "========================================="
}

# Continuous monitoring mode
continuous_monitor() {
    log "Starting continuous performance monitoring (interval: ${CHECK_INTERVAL}s)"

    while true; do
        performance_snapshot
        sleep $CHECK_INTERVAL
    done
}

diagnostic_report() {
    local report_file
    mkdir -p "$DIAGNOSTIC_DIR"
    report_file="$DIAGNOSTIC_DIR/solana-diagnostic-$(date '+%Y%m%d-%H%M%S').log"

    {
        echo "========================================="
        echo "Solana RPC Diagnostic Report"
        echo "Time: $(date --iso-8601=seconds 2>/dev/null || date)"
        echo "Host: $(hostname)"
        echo "Kernel: $(uname -a)"
        echo "Report: $report_file"
        echo "========================================="

        echo
        echo "### Service state"
        systemctl status "$SERVICE_NAME" --no-pager -l 2>&1 || true
        systemctl show "$SERVICE_NAME" \
            -p ActiveState -p SubState -p Result -p ExecMainCode -p ExecMainStatus \
            -p NRestarts -p MemoryCurrent -p MemoryHigh -p MemoryMax \
            -p CPUUsageNSec 2>&1 || true
        read_service_memory

        echo
        echo "### Validator process"
        if check_validator_running; then
            ps -p "$VALIDATOR_PID" -o pid,ppid,lstart,etime,%cpu,%mem,rss,vsz,nlwp,stat,cmd
            echo "Open files: $(find "/proc/$VALIDATOR_PID/fd" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)"
            echo "Limits:"
            cat "/proc/$VALIDATOR_PID/limits" 2>/dev/null || true
        fi

        echo
        echo "### Memory and pressure"
        free -h
        swapon --show 2>/dev/null || true
        cat /proc/pressure/memory 2>/dev/null || true

        echo
        echo "### Filesystems"
        df -hT /root/sol /root/sol/accounts /root/sol/ledger /root/sol/snapshot 2>&1 || true
        findmnt -T /root/sol/accounts 2>/dev/null || true
        findmnt -T /root/sol/ledger 2>/dev/null || true
        findmnt -T /root/sol/snapshot 2>/dev/null || true

        echo
        echo "### Snapshot directory"
        du -sh /root/sol/snapshot 2>/dev/null || true
        find /root/sol/snapshot -mindepth 1 -maxdepth 1 -printf '%y %TY-%Tm-%Td %TH:%TM %12s %f\n' \
            2>/dev/null | sort || true

        echo
        echo "### Disk I/O"
        if command -v iostat >/dev/null 2>&1; then
            iostat -xz 1 2 2>&1 || true
        else
            echo "iostat is unavailable; install the sysstat package"
        fi

        echo
        echo "### Recent service journal (last 300 lines)"
        journalctl -u "$SERVICE_NAME" -n 300 --no-pager -o short-iso-precise 2>&1 || true

        echo
        echo "### Recent validator warnings/errors"
        if [[ -r "$VALIDATOR_LOG" ]]; then
            tail -n 3000 "$VALIDATOR_LOG" | \
                grep -Ei 'warn|error|fatal|panic|oom|snapshot|behind|halt|corrupt|shred|health' | \
                tail -n 300 || true
        else
            echo "Validator log is not readable: $VALIDATOR_LOG"
        fi

        echo
        echo "### Recent kernel warnings"
        journalctl -k --since "24 hours ago" --no-pager -o short-iso-precise 2>/dev/null | \
            grep -Ei 'oom|out of memory|nvme|i/o error|filesystem|ext4|xfs|thermal|throttl' | \
            tail -n 300 || true

        echo
        echo "========================================="
        echo "Diagnostic report complete: $report_file"
        echo "========================================="
    } | tee "$report_file"
}

follow_service_logs() {
    echo "Recent $SERVICE_NAME.service startup logs:"
    journalctl -u "$SERVICE_NAME" -n 50 --no-pager -o short-iso-precise 2>/dev/null || true
    echo
    echo "Following validator log $VALIDATOR_LOG (Ctrl-C to stop)..."
    tail -n 100 -F "$VALIDATOR_LOG"
}

follow_journal() {
    echo "Following $SERVICE_NAME.service journal (Ctrl-C to stop)..."
    journalctl -u "$SERVICE_NAME" -n 100 -f -o short-iso-precise
}

# Main
case "${1:-snapshot}" in
    snapshot)
        performance_snapshot
        ;;
    monitor)
        continuous_monitor
        ;;
    diagnose)
        diagnostic_report
        ;;
    logs)
        follow_service_logs
        ;;
    journal)
        follow_journal
        ;;
    *)
        echo "Usage: $0 {snapshot|monitor|diagnose|logs|journal}"
        echo "  snapshot - Single performance check"
        echo "  monitor  - Continuous monitoring, print and append metrics to $LOGFILE"
        echo "  diagnose - Print and save a complete diagnostic report"
        echo "  logs     - Follow the validator runtime log"
        echo "  journal  - Follow systemd startup/restart logs"
        exit 1
        ;;
esac
