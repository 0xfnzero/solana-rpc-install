#!/bin/bash

set -e  # 遇到错误就退出

SNAPSHOT_DIR="/root/sol/snapshot"

validate_snapshot_download() {
  local snapshot_dir="$1"

  shopt -s nullglob
  local full_snapshots=(
    "$snapshot_dir"/snapshot-*.tar.zst
    "$snapshot_dir"/snapshot-*.tar.bz2
    "$snapshot_dir"/snapshot-*.tar
  )
  local incremental_snapshots=(
    "$snapshot_dir"/incremental-snapshot-*.tar.zst
    "$snapshot_dir"/incremental-snapshot-*.tar.bz2
    "$snapshot_dir"/incremental-snapshot-*.tar
  )
  local partial_files=(
    "$snapshot_dir"/tmp-*
    "$snapshot_dir"/*.part
    "$snapshot_dir"/*.tmp
    "$snapshot_dir"/*.aria2
  )
  shopt -u nullglob

  if ((${#full_snapshots[@]} == 0)); then
    echo "ERROR: No full snapshot file found in $snapshot_dir"
    return 1
  fi

  if ((${#partial_files[@]} > 0)); then
    echo "ERROR: Partial snapshot download files remain:"
    printf '  %s\n' "${partial_files[@]}"
    return 1
  fi

  local file
  for file in "${full_snapshots[@]}" "${incremental_snapshots[@]}"; do
    if [[ ! -s "$file" ]]; then
      echo "ERROR: Snapshot file is empty or unreadable: $file"
      return 1
    fi
  done

  echo "Snapshot files verified:"
  printf '  %s\n' "${full_snapshots[@]}"
  if ((${#incremental_snapshots[@]} > 0)); then
    printf '  %s\n' "${incremental_snapshots[@]}"
  fi
}

# 停止 sol 服务
echo "Stopping sol service..."
systemctl stop sol

rm -rf solana-rpc.log

# 定义要清空的目录列表
dirs=(
  "/root/sol/ledger"
  "/root/sol/accounts"
  "$SNAPSHOT_DIR"
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
set +e
python3 snapshot-finder.py --snapshot_path "$SNAPSHOT_DIR"
snapshot_finder_status=$?
set -e

if [[ $snapshot_finder_status -ne 0 ]]; then
  echo "snapshot-finder exited with status $snapshot_finder_status; verifying downloaded snapshot files..."
fi

validate_snapshot_download "$SNAPSHOT_DIR"

# 重启 sol 服务
echo "Starting sol service..."
systemctl start sol

echo "Script completed successfully."
