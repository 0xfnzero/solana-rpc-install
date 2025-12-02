#!/bin/bash
# TCP 极限优化脚本 - 进一步降低 gRPC 延迟

echo "==> 应用 TCP 极限优化配置..."

# 增大 TCP buffer sizes
sudo sysctl -w net.core.rmem_max=1073741824  # 1GB 接收缓冲
sudo sysctl -w net.core.wmem_max=1073741824  # 1GB 发送缓冲
sudo sysctl -w net.ipv4.tcp_rmem="4096 87380 1073741824"
sudo sysctl -w net.ipv4.tcp_wmem="4096 65536 1073741824"

# 启用 TCP Fast Open (减少握手延迟)
sudo sysctl -w net.ipv4.tcp_fastopen=3

# 优化 TCP 窗口缩放
sudo sysctl -w net.ipv4.tcp_window_scaling=1

# 减少 TIME_WAIT 连接数
sudo sysctl -w net.ipv4.tcp_tw_reuse=1

# 优化 TCP 拥塞控制（使用 BBR）
sudo sysctl -w net.core.default_qdisc=fq
sudo sysctl -w net.ipv4.tcp_congestion_control=bbr

# 增加连接队列大小
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535

# 持久化配置
cat >> /etc/sysctl.conf <<EOF

# gRPC 极限低延迟优化
net.core.rmem_max = 1073741824
net.core.wmem_max = 1073741824
net.ipv4.tcp_rmem = 4096 87380 1073741824
net.ipv4.tcp_wmem = 4096 65536 1073741824
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_tw_reuse = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
EOF

echo "✅ TCP 优化配置完成"
echo ""
echo "验证 BBR 拥塞控制:"
sysctl net.ipv4.tcp_congestion_control
echo ""
echo "验证 TCP Fast Open:"
sysctl net.ipv4.tcp_fastopen
