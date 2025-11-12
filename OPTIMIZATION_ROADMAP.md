# gRPC 延迟优化路线图

## 🎯 当前性能

测试结果（70 区块）：
- **Self_Node**: 52.86% 首先接收，平均延迟 48.82ms ✅
- **Your_Node**: 40.00% 首先接收，平均延迟 54.23ms
- **Public_Node**: 7.14% 首先接收，平均延迟 83.16ms

**已经超越公共节点 41%** 🏆

---

## ⚡ 进一步优化方案

### 方案 1: 禁用压缩（推荐优先尝试）

**配置文件**: 修改 `yellowstone-config.json`
```json
"compression": {
  "accept": [],
  "send": []
}
```

**预期效果**:
- 延迟降低: 15-25ms（48.82ms → **25-35ms**）
- CPU 节省: 压缩/解压缩开销（约 10-15%）
- 带宽增加: 2-3 倍（但你的网络延迟很低，带宽应该不是瓶颈）

**适用场景**:
- ✅ 你的服务器带宽充足（数据中心级别）
- ✅ 追求极限延迟
- ✅ 客户端也有充足带宽
- ❌ 如果按流量计费则不推荐

**部署步骤**:
```bash
# 1. 修改配置
vim /root/sol/bin/yellowstone-config.json
# 修改 compression 部分为空数组

# 2. 重启服务
sudo systemctl restart sol

# 3. 验证
curl http://localhost:8999/metrics | grep compression
```

---

### 方案 2: 增加 Tokio 线程

**配置文件**: 修改 `yellowstone-config.json`
```json
"tokio": {
  "worker_threads": 28,
  "affinity": null
}
```

**当前**: 24 threads（75% CPU）
**优化**: 28 threads（87.5% CPU）

**预期效果**:
- 延迟降低: 5-10ms
- 并发处理能力提升: 16%
- CPU 使用率: 增加约 10-15%

**风险**:
- ⚠️ 留给 Solana validator 的 CPU 减少（32 核 → 剩余 4 核）

---

### 方案 3: 极限 HTTP/2 窗口

**配置文件**: 修改 `yellowstone-config.json`
```json
"server_initial_connection_window_size": 33554432,  // 32MB
"server_initial_stream_window_size": 16777216       // 16MB
```

**当前**: 16MB + 8MB
**优化**: 32MB + 16MB

**预期效果**:
- 延迟降低: 5-10ms（减少流控暂停）
- 内存占用: 每连接增加 24MB

**适用场景**:
- ✅ 内存充足（128GB 完全够用）
- ✅ 高吞吐量场景

---

### 方案 4: 系统级 TCP 优化

**脚本**: `tcp-optimize.sh`

**优化项**:
1. **TCP buffer**: 1GB 接收/发送缓冲
2. **TCP Fast Open**: 减少握手延迟
3. **BBR 拥塞控制**: Google 的现代拥塞控制算法
4. **TIME_WAIT 优化**: 减少连接等待时间

**预期效果**:
- 延迟降低: 5-15ms（尤其是建立连接时）
- 吞吐量提升: 10-20%
- 系统级别优化，影响所有网络应用

**部署步骤**:
```bash
chmod +x tcp-optimize.sh
sudo ./tcp-optimize.sh
```

**验证**:
```bash
# 验证 BBR
sysctl net.ipv4.tcp_congestion_control

# 验证 TCP Fast Open
sysctl net.ipv4.tcp_fastopen

# 验证 buffer sizes
sysctl net.core.rmem_max net.core.wmem_max
```

---

### 方案 5: 组合极限优化

**配置文件**: `yellowstone-config-extreme.json`（已创建）

**包含所有优化**:
- ❌ 禁用压缩
- 🔧 28 worker threads
- 📦 32MB + 16MB HTTP/2 窗口
- 📈 更大 channel 容量（1.5M + 250M）

**预期效果**:
- 延迟目标: **20-30ms**（降低 40-60%）
- 首先接收率: **60-70%**
- 资源占用: 内存 +10GB，CPU +15%

**部署步骤**:
```bash
# 1. 应用 TCP 优化
sudo bash tcp-optimize.sh

# 2. 备份当前配置
sudo cp /root/sol/bin/yellowstone-config.json \
       /root/sol/bin/yellowstone-config.json.backup

# 3. 应用极限配置
sudo cp yellowstone-config-extreme.json \
       /root/sol/bin/yellowstone-config.json

# 4. 重启服务
sudo systemctl restart sol

# 5. 监控
sudo journalctl -u sol -f
```

---

## 📊 优化效果对比表

| 方案 | 预期延迟 | 难度 | 风险 | 资源占用 | 推荐指数 |
|------|---------|------|------|---------|---------|
| 当前配置 | 48.82ms | - | - | 基准 | ⭐⭐⭐⭐ |
| 仅禁用压缩 | 25-35ms | 低 | 低 | 带宽 +2x | ⭐⭐⭐⭐⭐ |
| +Tokio 线程 | 20-30ms | 低 | 中 | CPU +10% | ⭐⭐⭐⭐ |
| +HTTP/2 窗口 | 15-25ms | 低 | 低 | 内存 +5GB | ⭐⭐⭐⭐ |
| +TCP 优化 | 10-20ms | 中 | 低 | 系统级 | ⭐⭐⭐⭐⭐ |
| 组合极限 | 20-30ms | 中 | 中 | 全部 | ⭐⭐⭐⭐⭐ |

---

## 🎯 推荐策略

### 保守策略（推荐）
1. **先试禁用压缩** → 测试效果
2. 如果满意 → 完成
3. 如果不满意 → 继续下一步

### 激进策略
1. **TCP 优化** + **禁用压缩** → 测试
2. 如果还不满意 → **组合极限配置**

---

## 🔍 性能监控

### 实时延迟监控
```bash
watch -n 1 'curl -s http://localhost:8999/metrics | grep -E "latency|duration"'
```

### 队列深度（应接近 0）
```bash
watch -n 1 'curl -s http://localhost:8999/metrics | grep message_queue_size'
```

### CPU 使用率
```bash
top -b -n 1 | grep solana
```

### 内存使用
```bash
systemctl show sol --property=MemoryCurrent | awk '{printf "%.1fG\n", $2/1024/1024/1024}'
```

### 网络流量
```bash
# 安装 iftop（如果没有）
sudo apt install iftop -y

# 监控端口 10900 流量
sudo iftop -i eth0 -f "port 10900"
```

---

## ⚠️ 回滚方案

如果优化后出现问题，快速回滚：

```bash
# 恢复备份配置
sudo cp /root/sol/bin/yellowstone-config.json.backup \
       /root/sol/bin/yellowstone-config.json

# 重启服务
sudo systemctl restart sol

# 验证服务状态
sudo systemctl status sol
```

---

## 📈 预期最终效果

**目标性能**:
- 平均延迟: **< 30ms**
- 首先接收率: **> 60%**
- 超越公共节点: **2-3 倍**

**资源要求**:
- CPU: 28/32 核心（87.5%）
- 内存: 80-90GB（128GB 完全够用）
- 带宽: 1Gbps+（无压缩情况下）
- 磁盘 I/O: 无额外要求
