# solana-rpc-install

[中文](https://github.com/0xfnzero/solana-rpc-install/blob/main/README_CN.md) | [English README](https://github.com/0xfnzero/solana-rpc-install/blob/main/README.md)

#### 建议最低配置:
* CPU: AMD Ryzen 9 9950X
* RAM: 至少 192 GB

#### 挂载磁盘
* 准备至少 3 个 NVMe 盘，一个系统盘(1T)，一个存账户数据(至少2T)，一个存账本数据(至少2T)。

### 1. 安装openssl1.1
```shell
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb

sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2.24_amd64.deb
```

### 2. 创建目录和挂载硬盘命令
```shell
sudo mkdir -p /root/sol/accounts
sudo mkdir -p /root/sol/ledger
sudo mkdir -p /root/sol/snapshot
sudo mkdir -p /root/sol/bin

sudo mkfs.ext4 /dev/nvme0n1
sudo mount /dev/nvme0n1 /root/sol/ledger

sudo mkfs.ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 /root/sol/accounts
```

### 3. 修改/etc/fstab配置，设置挂盘盘和关闭swap
```shell
vim /etc/fstab

# 增加下面两行
/dev/nvme0n1 /root/sol/ledger ext4 defaults 0 0
/dev/nvme1n1 /root/sol/accounts ext4 defaults 0 0

# 注释包含 none swap sw 0 0，并wq保存修改
UUID=xxxx-xxxx-xxxx-xxxx none swap sw 0 0

# 临时关闭swap
sudo swapoff -a
```

### 4. 将 cpu 设置为 performance 模式
```shell
apt install linux-tools-common linux-tools-$(uname -r)

cpupower frequency-info

cpupower frequency-set --governor performance

watch "grep 'cpu MHz' /proc/cpuinfo"
```

### 5. 下载安装solana客户端
```shell
sh -c "$(curl -sSfL https://release.anza.xyz/v2.2.16/install)"

vim /root/.bashrc
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
source /root/.bashrc

solana --version
```

### 6. 创建验证者私钥
```shell
cd /root/sol/bin
solana-keygen new -o validator-keypair.json
```

### 7. 系统调优

#### 修改/etc/sysctl.conf
```shell
vim /etc/sysctl.conf
# 添加下面的内容

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
# 重新加载配置生效
sysctl -p
```

#### 修改/etc/systemd/system.conf
```shell
vim /etc/systemd/system.conf
# 添加下面的内容

DefaultLimitNOFILE=1000000


# 重新加载配置
systemctl daemon-reload
```

#### 修改/etc/security/limits.conf
```shell
vim /etc/security/limits.conf
# 添加下面的内容

# Increase process file descriptor count limit
* - nofile 1000000

# 手动设置一下，不然需要重启机器
ulimit -n 1000000 
```

### 8. 开启防火墙
```shell
sudo ufw enable

sudo ufw allow 22
sudo ufw allow 8000:8020/tcp
sudo ufw allow 8000:8020/udp
sudo ufw allow 8899 # http 端口
sudo ufw allow 8900 # websocket 端口
sudo ufw allow 10900 # GRPC 端口

sudo ufw status
```

### 9. 创建启动脚本和服务
```shell
vim /root/sol/bin/validator.sh
# 添加下面的内容

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

#### 新增 /etc/systemd/system/sol.service
```shell
vim /etc/systemd/system/sol.service
# 添加下面的内容

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

# 重新加载服务配置
systemctl daemon-reload
```

### 10. 配置GRPC
```shell
# 安装解压缩包工具
sudo apt-get install bzip2

# 进入bin目录
cd /root/sol/bin

# 下载yellowstone-grpc压缩包
sudo wget https://github.com/rpcpool/yellowstone-grpc/releases/download/v7.0.0%2Bsolana.2.2.16/yellowstone-grpc-geyser-release22-x86_64-unknown-linux-gnu.tar.bz2

# 解压缩包
tar -xvjf yellowstone-grpc-geyser-release22-x86_64-unknown-linux-gnu.tar.bz2

# 下载yellowstone-config.json配置文件, 这里面配置的GRPC端口号是: 10900
sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/yellowstone-config.json
```

### 11. 用脚本启动RPC节点
```shell
  # 进入root目录
  cd /root

  # 下载必要的脚本
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/redo_node.sh
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/get_health.sh
  sudo wget https://github.com/0xfnzero/solana-rpc-install/releases/download/v1.3/catchup.sh

  # 赋予脚本可执行权限
  sudo chmod +x redo_node.sh
  sudo chmod +x get_health.sh
  sudo chmod +x catchup.sh

  # 自动下载快照，下载完成后启动RPC节点
  sudo ./redo_node.sh

  # 查看日志
  tail -f /root/solana-rpc.log
  
  # 查看节点状态(预计30分钟后状态会是ok)
  ./get_health.sh

  # 实时查看追块同步进度
  ./catchup.sh
```

### 12. 相关命令
```shell
# 系统服务相关命令
systemctl start sol
systemctl status sol
systemctl stop sol
systemctl restart sol
systemctl daemon-reload
```

#### Telegram group:
https://t.me/fnzero_group
