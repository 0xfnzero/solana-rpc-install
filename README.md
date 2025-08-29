# solana-rpc-install

[中文](https://github.com/0xfnzero/solana-rpc-install/blob/main/README_CN.md) | [English](https://github.com/0xfnzero/solana-rpc-install/blob/main/README.md) | [Telegram](https://t.me/fnzero_group)

Solana node installation tutorial. By optimizing Ubuntu system parameters, the Solana node can run on more affordable servers while maintaining good performance and block synchronization speed.

#### Recommended Minimum Configuration:

* CPU: AMD Ryzen 9 9950X
* RAM: At least 192 GB
* It’s recommended to prioritize choosing a TSW provider, as some providers may have significant performance differences even with the same configuration. Network, disk, and RAM can all affect node stability and gRPC speed.
* Although my TSW 9950X in the NY region with 128 GB RAM runs normally, some users in the AMS3 region with 128 GB RAM experience OOM after running for a while. Therefore, it’s recommended to have at least 192 GB of RAM.
* However, my InterServer 9950X in the NY region with 192 GB RAM still encounters OOM every day.


#### Mount Disks

* It is recommended to prepare 3 NVMe disks: one system disk (1T), one for storing account data (at least 2T), and one for storing ledger data (at least 2T).
* If there are only 2 NVMe drives, the system disk will store the ledger data. In step 4 below (mounting directories), the ledger directory will be excluded from mounting.


### 1. Install OpenSSL 1.1

```shell
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb

sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb
```

### 2. Create Directories

```shell
sudo mkdir -p /root/sol/accounts
sudo mkdir -p /root/sol/ledger
sudo mkdir -p /root/sol/snapshot
sudo mkdir -p /root/sol/bin
```

### 3. View Disk Information

```shell
# Run the following command to check disks:
lsblk

# For example, output like the following means there are only two disks:
NAME        MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
nvme1n1     259:0    0  1.7T  0 disk
├─nvme1n1p1 259:2    0  512M  0 part /boot/efi
└─nvme1n1p2 259:3    0  1.7T  0 part /
nvme0n1     259:1    0  1.7T  0 disk

# nvme1n1 is the system disk because it contains /boot/efi
# nvme0n1 can be used to mount the accounts directory
# If nvme2n1 exists, it can be used to mount the ledger directory
```

### 4. Mount Directories

```shell
sudo mkfs.ext4 /dev/nvme0n1
sudo mount /dev/nvme0n1 /root/sol/accounts

# If you only have two disks, ignore the following two commands
sudo mkfs.ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 /root/sol/ledger
```

### 5. Modify /etc/fstab Configuration to Set Mount Points and Disable Swap

```shell
vim /etc/fstab

# Add the following lines
/dev/nvme0n1 /root/sol/accounts ext4 defaults 0 0
# If you only have two disks, ignore the following line
/dev/nvme1n1 /root/sol/ledger ext4 defaults 0 0

# Comment out the line containing none swap sw 0 0, then save and exit
UUID=xxxx-xxxx-xxxx-xxxx none swap sw 0 0

# Temporarily disable swap
sudo swapoff -a
```

### 6. Set CPU to Performance Mode

```shell
apt install linux-tools-common linux-tools-$(uname -r)

cpupower frequency-info

cpupower frequency-set --governor performance

watch "grep 'cpu MHz' /proc/cpuinfo"
```

### 7. Download and Install Solana CLI

```shell
sh -c "$(curl -sSfL https://release.anza.xyz/v2.3.6/install)"

vim /root/.bashrc
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
source /root/.bashrc

solana --version
```

### 8. Create Validator Keypair

```shell
cd /root/sol/bin
solana-keygen new -o validator-keypair.json
```

### 9. System Optimization

#### Modify /etc/sysctl.conf

```shell
vim /etc/sysctl.conf
# Add the following content

# TCP Buffer Sizes (10k min, 87.38k default, 12M max)
net.ipv4.tcp_rmem=10240 87380 12582912
net.ipv4.tcp_wmem=10240 87380 12582912

# TCP Optimization
net.ipv4.tcp_congestion_control=westwood
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_timestamps=0
net.ipv4.tcp_sack=1
net.ipv4.tcp_low_latency=1
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_moderate_rcvbuf=1

# Kernel Optimization
kernel.timer_migration=0
kernel.hung_task_timeout_secs=30
kernel.pid_max=49152

# Virtual Memory Tuning
vm.swappiness=30
vm.max_map_count=2000000
vm.stat_interval=10
vm.dirty_ratio=40
vm.dirty_background_ratio=10
vm.min_free_kbytes=3000000
vm.dirty_expire_centisecs=36000
vm.dirty_writeback_centisecs=3000
vm.dirtytime_expire_seconds=43200

# Solana Specific Tuning
net.core.rmem_max=134217728
net.core.rmem_default=134217728
net.core.wmem_max=134217728
net.core.wmem_default=134217728

# Increase number of allowed open file descriptors
fs.nr_open = 1000000
```

```shell
# Reload configuration
sysctl -p
```

#### Modify /etc/systemd/system.conf

```shell
vim /etc/systemd/system.conf
# Add the following content

DefaultLimitNOFILE=1000000

# Reload service configuration
systemctl daemon-reload
```

#### Modify /etc/security/limits.conf

```shell
vim /etc/security/limits.conf
# Add the following content

# Increase process file descriptor count limit
* - nofile 1000000

# Set manually, otherwise reboot is required
ulimit -n 1000000
```

### 10. Enable Firewall

```shell
sudo ufw enable

sudo ufw allow 22
sudo ufw allow 8000:8020/tcp
sudo ufw allow 8000:8020/udp
sudo ufw allow 8899 # HTTP port
sudo ufw allow 8900 # WebSocket port
sudo ufw allow 10900 # GRPC port

sudo ufw status
```

### 11. Create Startup Script and Service

```shell
vim /root/sol/bin/validator.sh
# Add the following content

#!/bin/bash

RUST_LOG=warn agave-validator \
 --geyser-plugin-config /root/sol/bin/yellowstone-config.json \
 --ledger /root/sol/ledger \
 --accounts /root/sol/accounts \
 --identity /root/sol/bin/validator-keypair.json \
 --snapshots /root/sol/snapshot \
 --log /root/solana-rpc.log \
 --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint4.mainnet-beta.solana.com:8001 \
 --entrypoint entrypoint5.mainnet-beta.solana.com:8001 \
 --known-validator Certusm1sa411sMpV9FPqU5dXAYhmmhygvxJ23S6hJ24 \
 --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
 --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
 --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
 --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
 --known-validator CakcnaRDHka2gXyfbEd2d3xsvkJkqsLw2akB3zsN1D2S \
 --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
 --only-known-rpc \
 --disable-banking-trace \
 --rpc-bind-address 0.0.0.0 \
 --rpc-port 8899 \
 --full-rpc-api \
 --private-rpc \
 --no-voting \
 --dynamic-port-range 8000-8020 \
 --wal-recovery-mode skip_any_corrupted_record \
 --limit-ledger-size 60000000 \
 --no-port-check \
 --no-snapshot-fetch \
 --account-index-include-key AddressLookupTab1e1111111111111111111111111 \
 --account-index program-id \
 --rpc-bigtable-timeout 300 \
 --full-snapshot-interval-slots 1577880000 \
 --incremental-snapshot-interval-slots 788940000 \
 --incremental-snapshot-archive-path /root/sol/snapshot

chmod +x /root/sol/bin/validator.sh
```

#### Add /etc/systemd/system/sol.service

```shell
vim /etc/systemd/system/sol.service
# Add the following content

[Unit]
Description=Solana Validator
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=root
LimitNOFILE=1000000
LogRateLimitIntervalSec=0
Environment="PATH=/bin:/usr/bin:/root/.local/share/solana/install/active_release/bin"
ExecStart=/root/sol/bin/validator.sh

[Install]
WantedBy=multi-user.target

# Reload service configuration
systemctl daemon-reload
```

### 12. Configure GRPC

```shell
# Install unzip tool
sudo apt-get install bzip2

# Enter bin directory
cd /root/sol/bin

# Download yellowstone-grpc archive
sudo wget https://github.com/rpcpool/yellowstone-grpc/releases/download/v8.0.0%2Bsolana.2.3.6/yellowstone-grpc-geyser-release22-x86_64-unknown-linux-gnu.tar.bz2

# Extract archive
tar -xvjf yellowstone-grpc-geyser-release22-x86_64-unknown-linux-gnu.tar.bz2

# Download yellowstone-config.json, GRPC port configured here: 10900
sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/yellowstone-config.json
```

### 13. Start RPC Node Using Script

```shell
  # Enter root directory
  cd /root

  # Download necessary scripts
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.4/redo_node.sh
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/restart_node.sh
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/get_health.sh
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/catchup.sh

  # Grant execute permission to scripts
  sudo chmod +x *.sh

  # Automatically download snapshot and start RPC node after download
  sudo ./redo_node.sh

  # View logs
  tail -f /root/solana-rpc.log
  
  # Check node status (expected to be ok after ~30 minutes)
  ./get_health.sh

  # Real-time block synchronization progress
  ./catchup.sh

  # Restart the node. If it can't catch up with the blocks, you can restart it again.
  sudo ./restart_node.sh
```

### 14. Related Commands

```shell
# System service commands
systemctl start sol
systemctl status sol
systemctl stop sol
systemctl restart sol
systemctl daemon-reload
```

#### Telegram group:

[https://t.me/fnzero\_group](https://t.me/fnzero_group)
