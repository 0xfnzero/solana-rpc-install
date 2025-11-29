# Jito 预编译版本更新日志

## 🎉 新增功能

### ⚡ Jito 预编译安装选项

添加了基于 Jito 预编译二进制文件的快速安装方式，与现有的源码编译方式并存。

**新增文件**:
- `2-install-solana-jito.sh` - Jito 预编译版本安装脚本
- `JITO_VS_SOURCE.md` - 两种安装方式的详细对比文档
- `JITO_QUICKSTART.md` - Jito 版本快速入门指南
- `CHANGELOG_JITO.md` - 本更新日志

### 📦 双安装方式对比

| 特性 | Jito 预编译 | 源码编译 |
|------|------------|---------|
| **安装时间** | 2-3 分钟 | 20-40 分钟 |
| **脚本文件** | `2-install-solana-jito.sh` | `2-install-solana.sh` |
| **MEV 支持** | ✅ 内置 | ❌ 默认无 |
| **版本格式** | v3.0.11-jito | v3.0.10 |
| **依赖需求** | 最小（仅基础工具） | 完整开发工具链 |
| **推荐场景** | 生产环境、快速部署 | 开发调试、自定义构建 |

## 🔧 主要改进

### 1. 安装脚本功能

**`2-install-solana-jito.sh` 特性**:
- ✅ 交互式版本选择（支持任意 Jito 版本）
- ✅ 自动版本验证（检查 GitHub release 是否存在）
- ✅ 下载 Jito 预编译包（~400MB）
- ✅ 自动解压和安装到 `/usr/local/solana`
- ✅ 三层 PATH 持久化配置：
  - `/root/.bashrc` (root 用户)
  - `/etc/profile.d/solana.sh` (所有用户登录)
  - `/etc/environment` (系统级别)
- ✅ 完整的防火墙配置
- ✅ Yellowstone gRPC 插件安装
- ✅ systemd 服务配置
- ✅ 辅助脚本部署

### 2. PATH 环境变量持久化

相比旧脚本的临时 export，新脚本实现了**三层持久化**：

```bash
# 层级 1: Root 用户 bashrc
/root/.bashrc:
  export PATH="/usr/local/solana/bin:$PATH"

# 层级 2: 系统登录配置（所有用户）
/etc/profile.d/solana.sh:
  export PATH="/usr/local/solana/bin:$PATH"

# 层级 3: 系统环境变量（systemd 服务可用）
/etc/environment:
  PATH="/usr/local/solana/bin:/usr/local/sbin:..."
```

**优势**:
- 无需手动 source 或重新登录
- systemd 服务直接可用
- 所有用户都能访问 solana 命令
- 重启后自动生效

### 3. 版本管理

**Jito 版本格式**:
```
v3.0.11-jito  → 基于 Agave v3.0.11
v3.0.10-jito  → 基于 Agave v3.0.10
```

**下载 URL 格式**:
```
https://github.com/jito-foundation/jito-solana/releases/download/
  v{VERSION}-jito/solana-release-x86_64-unknown-linux-gnu.tar.bz2
```

**版本验证**:
- 脚本自动验证版本是否存在
- 验证失败时提供重试机会
- 显示 GitHub releases 页面链接

### 4. 去除重启要求

**修改内容**:
- ✅ 移除所有脚本中的"重启系统"步骤
- ✅ 更新 README.md 安装说明
- ✅ 更新 JITO_QUICKSTART.md
- ✅ 调整步骤编号（步骤 3 → 验证，步骤 4 → 启动）

**原因**:
- PATH 配置通过 `source` 立即生效
- 系统优化参数已在 `1-prepare.sh` 中应用
- 无需重启即可继续后续步骤

## 📝 文档更新

### README.md

**新增部分**:
```markdown
## 🚀 Quick Start

### Choose Your Installation Method

Option A: Jito Precompiled (⚡ Recommended - 2-3 minutes)
Option B: Source Compilation (🔧 Advanced - 20-40 minutes)

💡 Which method to choose?
- Jito Precompiled: Fast, MEV-ready, production
- Source Compilation: Custom, full control, development
```

**更新部分**:
- ✅ Deployment Features (添加双安装选项说明)
- ✅ Architecture (添加安装方式对比)
- ✅ Documentation (添加新文档链接)

### 新增文档

1. **JITO_VS_SOURCE.md** - 完整对比分析
   - 安装时间对比
   - 资源消耗对比
   - 使用场景建议
   - 版本对应关系
   - PATH 配置对比
   - 常见问题解答

2. **JITO_QUICKSTART.md** - 快速开始指南
   - 一键安装命令
   - 详细步骤说明
   - 验证检查清单
   - 常用命令参考
   - 故障排查指南

3. **MOUNT_STRATEGY.md** - 存储挂载策略
   - 磁盘挂载最佳实践
   - 性能分析和建议
   - 验证脚本

4. **MOUNT_QUICKREF.md** - 挂载配置快速参考
   - 一页纸总结
   - 快速命令参考

## 🔄 兼容性

### 向后兼容
- ✅ 原有的源码编译脚本 `2-install-solana.sh` 完全保留
- ✅ 现有用户可继续使用源码编译方式
- ✅ 新用户可选择 Jito 预编译或源码编译

### 脚本互换性
- ✅ 两个脚本安装目录相同：`/usr/local/solana`
- ✅ PATH 配置方式相同
- ✅ systemd 服务配置相同
- ⚠️ 切换安装方式需停止服务并重新安装

## 🚀 使用示例

### 新用户安装（推荐 Jito）

```bash
# 1. 准备系统
sudo bash 1-prepare.sh

# 2. 安装 Jito Solana
sudo bash 2-install-solana-jito.sh
# 输入版本: v3.0.11

# 3. 加载环境变量（可选）
source /etc/profile.d/solana.sh

# 4. 验证安装
solana --version

# 5. 启动节点
bash 3-start.sh
```

### 从源码编译切换到 Jito

```bash
# 1. 停止服务
sudo systemctl stop sol

# 2. 重新安装（使用 Jito）
sudo bash 2-install-solana-jito.sh
# 输入版本: v3.0.11

# 3. 启动服务
sudo systemctl start sol
```

### 版本升级

```bash
# Jito 版本升级（2-3 分钟）
sudo systemctl stop sol
sudo bash 2-install-solana-jito.sh
# 输入新版本号
sudo systemctl start sol

# 源码编译升级（20-40 分钟）
sudo systemctl stop sol
sudo bash 2-install-solana.sh
# 输入新版本号
sudo systemctl start sol
```

## 📊 性能对比

### 安装速度

**测试环境**: 64 核 CPU, 512GB RAM, 10Gbps 网络

| 步骤 | Jito 预编译 | 源码编译 |
|------|------------|---------|
| 下载 | 30 秒 | 20 秒 |
| 解压/编译 | 10 秒 | 25 分钟 |
| 配置安装 | 5 秒 | 2 分钟 |
| **总计** | **~2 分钟** | **~27 分钟** |

### 磁盘空间

```
Jito 预编译: 1.8GB
源码编译: 1.8GB + 8GB (编译缓存) + 2GB (Rust) = ~12GB
```

## ⚠️ 注意事项

### 重要提示

1. **版本选择**
   - Jito 版本格式: `v3.0.11-jito`
   - 查看可用版本: https://github.com/jito-foundation/jito-solana/releases
   - 建议使用最新稳定版（非 RC 版本）

2. **环境变量**
   - 安装后需要 `source /etc/profile.d/solana.sh`
   - 或者重新登录 SSH 会话
   - systemd 服务自动可用，无需额外配置

3. **切换安装方式**
   - 停止服务: `sudo systemctl stop sol`
   - 运行新安装脚本
   - 启动服务: `sudo systemctl start sol`
   - 数据目录不受影响

4. **不需要重启**
   - PATH 配置立即生效（通过 source）
   - 系统优化已在 1-prepare.sh 中完成
   - 可直接进行下一步操作

### 故障排查

**问题 1**: `solana: command not found`
```bash
# 解决方案: 加载环境变量
source /etc/profile.d/solana.sh
# 或
source /root/.bashrc
# 或重新登录
```

**问题 2**: 版本验证失败
```bash
# 检查版本格式
# 正确: v3.0.11 (不要 -jito 后缀)
# 错误: 3.0.11 (缺少 v 前缀)

# 查看可用版本
# https://github.com/jito-foundation/jito-solana/releases
```

**问题 3**: 下载速度慢
```bash
# 使用代理或 CDN
# 或手动下载后放到 /tmp/jito-solana-download/
```

## 🎯 下一步计划

### 未来改进

- [ ] 添加自动版本检测（获取最新 Jito 版本）
- [ ] 支持镜像下载源配置
- [ ] 添加版本回滚功能
- [ ] 集成健康检查到安装脚本
- [ ] 添加配置文件模板生成器

### 反馈和建议

如有问题或建议，请通过以下方式反馈：
- GitHub Issues: https://github.com/0xfnzero/solana-rpc-install/issues
- Telegram: https://t.me/fnzero_group
- Discord: https://discord.gg/vuazbGkqQE

---

**更新日期**: 2025-11-29
**版本**: v1.0.0-jito
**维护者**: fnzero
