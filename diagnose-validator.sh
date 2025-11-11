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
echo "   PATH: $PATH"
echo ""

echo "3. 检查 agave-validator 位置："
which agave-validator || echo "   [错误] agave-validator 不在 PATH 中"
echo ""

echo "4. 检查 /usr/local/solana/bin 中的文件："
if [ -d "/usr/local/solana/bin" ]; then
    ls -la /usr/local/solana/bin/ | head -20
    echo ""
    echo "   /usr/local/solana/bin/agave-validator 版本："
    /usr/local/solana/bin/agave-validator --version 2>&1 || echo "   [错误] 无法运行"
else
    echo "   [错误] /usr/local/solana/bin 目录不存在"
fi
echo ""

echo "5. 检查 systemd service 配置："
if [ -f "/etc/systemd/system/sol.service" ]; then
    echo "   Service PATH 配置："
    grep "Environment.*PATH" /etc/systemd/system/sol.service
else
    echo "   [错误] /etc/systemd/system/sol.service 不存在"
fi
echo ""

echo "6. 检查 validator.sh 脚本："
if [ -f "/root/sol/bin/validator.sh" ]; then
    echo "   validator.sh 前 5 行："
    head -5 /root/sol/bin/validator.sh
else
    echo "   [错误] /root/sol/bin/validator.sh 不存在"
fi
echo ""

echo "7. 测试端口范围参数："
echo "   测试 --dynamic-port-range 8000-8020："
agave-validator --dynamic-port-range 8000-8020 --help &>/dev/null && echo "   ✓ 端口范围有效" || echo "   ✗ 端口范围无效"
echo ""

echo "8. 检查最近的服务日志错误："
if command -v journalctl &> /dev/null; then
    echo "   最近 20 条 sol 服务日志："
    journalctl -u sol -n 20 --no-pager
else
    echo "   [警告] journalctl 不可用，无法查看服务日志"
fi
echo ""

echo "=== 诊断完成 ==="
