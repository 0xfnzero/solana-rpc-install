#!/bin/bash

set -e  # 脚本有报错就终止

# 开启 UFW（如果没启用）
ufw enable

sudo ufw allow 22
sudo ufw allow 8000:8020/tcp
sudo ufw allow 8000:8020/udp
sudo ufw allow 8899 # http 端口
sudo ufw allow 8900 # websocket 端口