#!/usr/bin/env bash
#
# RooCode Plus — 启动脚本
# 用法: ./start_proxy.sh
#

set -e

# 动态获取脚本所在目录（不依赖任何硬编码路径）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "  RooCode Plus — Multi-Model Adapter"
echo "============================================"

# ---------- 环境检测 ----------
if [ ! -d "venv" ]; then
    echo ""
    echo "[错误] 未检测到 Python 虚拟环境 (venv/)！"
    echo ""
    echo "请先依次执行以下命令完成环境配置："
    echo "  1)  python3 -m venv venv"
    echo "  2)  source venv/bin/activate"
    echo "  3)  pip install fastapi httpx uvicorn"
    echo ""
    echo "然后配置你的 API Key："
    echo "  4)  export DEEPSEEK_API_KEY=\"你的真实API_KEY写在这里\""
    echo ""
    echo "配置完成后，再次运行 ./start_proxy.sh 即可启动。"
    echo ""
    exit 1
fi

# ---------- 检查 API Key ----------
if [ -z "$DEEPSEEK_API_KEY" ] || [ "$DEEPSEEK_API_KEY" = "你的真实API_KEY写在这里" ]; then
    echo ""
    echo "[警告] 未设置有效的 DEEPSEEK_API_KEY 环境变量！"
    echo ""
    echo "请通过以下方式之一设置："
    echo "  export DEEPSEEK_API_KEY=\"sk-xxxxxxxxxxxxxxxx\""
    echo "  或创建 .env 文件并在启动前 source .env"
    echo ""
    echo "继续启动中（若未设置 Key，API 调用将会失败）..."
    echo ""
fi

# ---------- 启动代理 ----------
echo "[启动] 正在激活虚拟环境并启动适配代理..."
echo ""

source venv/bin/activate

nohup python proxy_server.py > proxy.log 2>&1 &

PID=$!
echo "[成功] RooCode Plus 已在后台启动！PID: $PID"
echo "       日志文件: $SCRIPT_DIR/proxy.log"
echo "       监听地址: http://127.0.0.1:8000/v1/chat/completions"
echo ""
echo "使用 'tail -f proxy.log' 查看实时日志"
echo "使用 'kill $PID' 停止服务"
