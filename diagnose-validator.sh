#!/bin/bash

echo "=== Solana Validator 诊断脚本 ==="
echo ""

echo "1. 检查 Solana 版本："
if command -v agave-validator &> /dev/null; then
    agave-validator --version
else
    echo "   [错误] agave-validator 未找到"
fi
echo ""

echo "2. 检查 PATH 配置："
echo "   当前 PATH: $PATH"
echo ""

echo "3. 检查 agave-validator 位置："
which agave-validator || echo "   [错误] agave-validator 不在 PATH 中"
echo ""

echo "4. 检查 /usr/local/solana/bin 中的文件："
if [ -d "/usr/local/solana/bin" ]; then
    echo "   目录存在，文件列表："
    ls -la /usr/local/solana/bin/ | head -20
    echo ""
    echo "   /usr/local/solana/bin/agave-validator 版本："
    /usr/local/solana/bin/agave-validator --version 2>&1 || echo "   [错误] 无法运行"
    echo ""
    echo "   检查可执行权限："
    ls -l /usr/local/solana/bin/agave-validator
else
    echo "   [错误] /usr/local/solana/bin 目录不存在"
fi
echo ""

echo "5. 检查 systemd service 配置："
if [ -f "/etc/systemd/system/sol.service" ]; then
    echo "   Service 完整配置："
    cat /etc/systemd/system/sol.service
else
    echo "   [错误] /etc/systemd/system/sol.service 不存在"
fi
echo ""

echo "6. 检查 validator.sh 脚本："
if [ -f "/root/sol/bin/validator.sh" ]; then
    echo "   validator.sh 完整内容："
    cat /root/sol/bin/validator.sh
    echo ""
    echo "   检查执行权限："
    ls -l /root/sol/bin/validator.sh
else
    echo "   [错误] /root/sol/bin/validator.sh 不存在"
fi
echo ""

echo "7. 手动测试 validator.sh 执行："
if [ -f "/root/sol/bin/validator.sh" ]; then
    echo "   尝试手动运行 validator.sh (仅测试启动，5秒后终止)："
    timeout 5 /root/sol/bin/validator.sh 2>&1 || echo "   命令执行结果码: $?"
fi
echo ""

echo "8. 检查必要目录："
for dir in /root/sol/ledger /root/sol/accounts /root/sol/snapshot /root/sol/bin; do
    if [ -d "$dir" ]; then
        echo "   ✓ $dir 存在"
        ls -ld "$dir"
    else
        echo "   ✗ $dir 不存在"
    fi
done
echo ""

echo "9. 检查 Yellowstone gRPC 配置："
if [ -f "/root/sol/bin/yellowstone-config.json" ]; then
    echo "   ✓ yellowstone-config.json 存在"
    ls -l /root/sol/bin/yellowstone-config.json
else
    echo "   ✗ yellowstone-config.json 不存在"
fi
echo ""

echo "10. 检查 geyser 插件库："
if [ -f "/root/sol/bin/libyellowstone_grpc_geyser.so" ]; then
    echo "   ✓ libyellowstone_grpc_geyser.so 存在"
    ls -l /root/sol/bin/libyellowstone_grpc_geyser.so
else
    echo "   ✗ libyellowstone_grpc_geyser.so 不存在"
fi
echo ""

echo "11. 检查验证者密钥："
if [ -f "/root/sol/bin/validator-keypair.json" ]; then
    echo "   ✓ validator-keypair.json 存在"
    ls -l /root/sol/bin/validator-keypair.json
else
    echo "   ✗ validator-keypair.json 不存在"
fi
echo ""

echo "12. 检查最近的服务日志错误："
if command -v journalctl &> /dev/null; then
    echo "   最近 50 条 sol 服务日志（完整错误信息）："
    journalctl -u sol -n 50 --no-pager
else
    echo "   [警告] journalctl 不可用，无法查看服务日志"
fi
echo ""

echo "13. 检查日志文件："
if [ -f "/root/solana-rpc.log" ]; then
    echo "   日志文件最后 30 行："
    tail -30 /root/solana-rpc.log
else
    echo "   [提示] /root/solana-rpc.log 尚未创建（服务未成功启动）"
fi
echo ""

echo "=== 诊断完成 ==="
echo ""
echo "请将此诊断输出发送给技术支持以获得帮助"
