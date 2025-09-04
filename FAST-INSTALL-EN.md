[中文](https://github.com/0xfnzero/solana-rpc-install/blob/main/README_CN.md) | [English](https://github.com/0xfnzero/solana-rpc-install/blob/main/README.md) | [Telegram](https://t.me/fnzero_group)

# Solana RPC Node Fast Install Guide

## Prerequisites

### Minimum System Requirements
* **CPU**: AMD Ryzen 9 9950X (recommended)
* **RAM**: At least 192 GB
* **Storage**: At least 3 NVMe drives (1T system + 2T accounts + 2T ledger)
* **OS**: Ubuntu 20.04/22.04

### Recommended Providers
* **TSW** is highly recommended as some providers may have significant performance differences even with the same configuration
* Network, disk, and RAM can all affect node stability and gRPC speed
* Some users in AMS3 region with 128 GB RAM experience OOM issues, so 192 GB RAM is recommended

## Three-Step Installation

### Step 1: Download System Optimization Script

```bash
# Download the system optimization script
wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/system-optimize.sh

# Make it executable
chmod +x system-optimize.sh
```

**What this script does:**
- Disables swap (comments out in fstab + swapoff -a)
- Optimizes sysctl.conf with westwood TCP, VM tuning, and file descriptor limits
- Sets CPU governor to performance mode
- Configures systemd and security limits for high file descriptor count
- Applies all changes immediately

### Step 2: Download Solana Installation Script

```bash
# Download the Solana installation script
wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.5/solana-install.sh

# Make it executable
chmod +x solana-install.sh
```

**What this script does:**
- Installs OpenSSL 1.1
- Creates necessary directories (/root/sol/accounts, /root/sol/ledger, /root/sol/snapshot, /root/sol/bin)
- Auto-detects and mounts data disks (prioritizes accounts → ledger → snapshot)
- Installs Solana CLI v2.3.6 and configures PATH
- Creates validator keypair
- Configures UFW firewall with required ports
- Creates validator.sh startup script and systemd service
- Downloads Yellowstone gRPC geyser and configuration
- Downloads management scripts (redo_node.sh, restart_node.sh, get_health.sh, catchup.sh)
- Automatically starts the node with snapshot download

### Step 3: Execute Scripts in Order

```bash
# First, run system optimization (requires root)
sudo ./system-optimize.sh

# Then, run Solana installation (requires root)
sudo ./solana-install.sh
```

**Important Notes:**
- Both scripts must be run as root (use `sudo`)
- Run them in the exact order shown above
- The system optimization script should be run first to prepare the system
- The Solana installation script will automatically start the node after completion

## Post-Installation

### Check Node Status
```bash
cd /root

# View logs
tail -f solana-rpc.log

# Check node health (should be ok after ~30 minutes)
./get_health.sh

# Monitor block synchronization progress
./catchup.sh
```

### Management Commands
```bash
# Restart the node (if it can't catch up with blocks)
sudo /root/restart_node.sh

# Or use systemctl
sudo systemctl restart sol

# Check service status
sudo systemctl status sol

# Enable auto-start on boot
sudo systemctl enable sol
```

### Port Configuration
The following ports will be automatically configured:
- **8899**: HTTP RPC port
- **8900**: WebSocket port  
- **10900**: gRPC port
- **8000-8020**: Dynamic ports for validator communication

## Troubleshooting

### If the node fails to start:
1. Check logs: `tail -f /root/solana-rpc.log`
2. Verify disk space: `df -h`
3. Check memory usage: `free -h`
4. Restart the node: `sudo /root/restart_node.sh`

### If the node can't catch up:
1. Monitor progress: `/root/catchup.sh`
2. Restart if needed: `sudo /root/restart_node.sh`
3. Check network connectivity to Solana entrypoints

### System Requirements Check:
```bash
# Check CPU governor
cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# Check file descriptor limits
ulimit -n

# Check swap status
swapon --show
```

## Support

For questions and support, join our Telegram group: [https://t.me/fnzero_group](https://t.me/fnzero_group)

---

**Note**: This fast install guide automates the entire process described in the detailed README. The scripts handle all system optimization, disk mounting, software installation, and configuration automatically.
