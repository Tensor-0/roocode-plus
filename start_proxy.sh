#!/usr/bin/env bash
#
# RooCode Plus — 启动脚本
# 用法: ./start_proxy.sh  或  roocode（安装别名后）
#
# 自动加载 .env 中的 API Key，无需手动 export 或激活 venv。
#

set -e

# 动态获取脚本所在目录（不依赖任何硬编码路径）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "  RooCode Plus — Multi-Model Adapter"
echo "============================================"

# ---------- 1. 自动加载 .env ----------
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
fi

# ---------- 2. 环境检测 ----------
if [ ! -d "venv" ]; then
    echo ""
    echo "[错误] 未检测到 Python 虚拟环境 (venv/)！"
    echo ""
    echo "请先运行安装脚本："
    echo "  bash install.sh"
    echo ""
    exit 1
fi

# ---------- 3. 检查 API Key ----------
if [ -z "$DEEPSEEK_API_KEY" ] || [ "$DEEPSEEK_API_KEY" = "你的真实API_KEY写在这里" ]; then
    echo ""
    echo "[警告] 未设置有效的 DEEPSEEK_API_KEY！"
    echo ""
    echo "请通过以下方式之一设置："
    echo "  1) 运行安装脚本: bash install.sh"
    echo "  2) 手动创建 .env: echo 'DEEPSEEK_API_KEY=sk-xxx' > .env"
    echo "  3) 环境变量:     export DEEPSEEK_API_KEY=\"sk-xxx\""
    echo ""
    echo "继续启动中（若未设置 Key，API 调用将会失败）..."
    echo ""
fi

# ---------- 4. 启动代理 ----------
echo "[启动] 正在启动适配代理..."
echo ""

# 跨平台 venv 路径：Windows 用 Scripts/，Linux/macOS 用 bin/
if [ -f "venv/Scripts/python.exe" ]; then
    VENV_PYTHON="venv/Scripts/python.exe"
else
    VENV_PYTHON="venv/bin/python"
fi

nohup $VENV_PYTHON proxy_server.py > proxy.log 2>&1 &
PID=$!

# 等待一瞬间，检查进程是否存活（端口冲突等会导致进程立即退出）
sleep 0.5

if ! kill -0 "$PID" 2>/dev/null; then
    echo ""
    echo "============================================"
    echo "  [失败] 代理进程启动后立即退出！"
    echo "============================================"
    echo ""
    echo "常见原因："
    echo "  1) 端口 8000 已被占用 — 运行: kill \$(lsof -t -i:8000) 2>/dev/null"
    echo "  2) Python 依赖缺失     — 运行: bash install.sh"
    echo "  3) 查看错误详情        — 运行: cat $SCRIPT_DIR/proxy.log"
    echo ""
    exit 1
fi

echo "[成功] RooCode Plus 已在后台启动！PID: $PID"
echo "       日志文件: $SCRIPT_DIR/proxy.log"
echo "       监听地址: http://127.0.0.1:8000/v1/chat/completions"
echo ""
echo "使用 'tail -f proxy.log' 查看实时日志"
echo "使用 'kill $PID' 停止服务"
