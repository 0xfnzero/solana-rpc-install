sudo mkdir -p /root/sol/accounts
sudo mkdir -p /root/sol/ledger
sudo mkdir -p /root/sol/snapshot

sudo mkfs.ext4 /dev/nvme0n1
sudo mount /dev/nvme0n1 /root/sol/ledger

sudo mkfs.ext4 /dev/nvme1n1
sudo mount /dev/nvme1n1 /root/sol/accounts
