#!/bin/bash

set -e  # 遇到错误就退出

# 停止 sol 服务
echo "Stopping sol service..."
systemctl stop sol

rm -rf solana-rpc.log

# 定义要清空的目录列表
dirs=(
  "/root/sol/ledger"
  "/root/sol/accounts"
  "/root/sol/snapshot"
)

# 清空目录内容并确保目录存在
for dir in "${dirs[@]}"; do
  if [ -d "$dir" ]; then
    echo "Cleaning directory: $dir"
    rm -rf "$dir"/* "$dir"/.[!.]* "$dir"/..?* || true
  else
    echo "Creating directory: $dir"
    mkdir -p "$dir"
  fi
done

# 安装依赖
echo "Updating packages and installing dependencies..."
sudo apt-get update
sudo apt-get install -y python3-venv git

# 克隆或更新 solana-snapshot-finder 仓库
if [ ! -d "solana-snapshot-finder" ]; then
  echo "Cloning solana-snapshot-finder repository..."
  git clone https://github.com/0xfnzero/solana-snapshot-finder
else
  echo "Repository solana-snapshot-finder already exists, pulling latest changes..."
  cd solana-snapshot-finder
  git pull
  cd ..
fi

# 进入目录并创建虚拟环境
cd solana-snapshot-finder
if [ ! -d "venv" ]; then
  echo "Creating Python virtual environment..."
  python3 -m venv venv
fi

echo "Activating virtual environment and installing Python dependencies..."
source ./venv/bin/activate
pip3 install --upgrade pip
pip3 install -r requirements.txt

# 运行 snapshot finder
echo "Running snapshot-finder..."
python3 snapshot-finder.py --snapshot_path /root/sol/snapshot

# 重启 sol 服务
echo "Starting sol service..."
systemctl start sol

echo "Script completed successfully."
