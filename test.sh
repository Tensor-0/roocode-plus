#!/usr/bin/env bash
#
# RooCode Plus — 自动化测试脚本
# 用法: bash test.sh
#
# 在临时隔离环境中运行，不影响当前项目。
# 覆盖 install.sh 和 start_proxy.sh 的 happy path + 常见错误场景。
# 支持 Ubuntu、macOS、Windows (Git Bash) 三平台。
#

set -e

# 强制 Bash/Python 使用 UTF-8（解决 Windows Git Bash 中文乱码和 Python emoji 崩溃）
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓ PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC} $1 — $2"; FAIL=$((FAIL + 1)); }

# ---------- 跨平台工具函数 ----------

# 检测操作系统
IS_WINDOWS=false
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

# 跨平台进程查找：根据命令行关键字返回 PID
find_pid() {
    local keyword="$1"
    if $IS_WINDOWS; then
        # Windows: 用 tasklist + 管道查找 python 进程（关键字匹配靠人工判断，这里取所有 python.exe）
        # 精确匹配：用 WMIC 查命令行
        local pids
        pids=$(tasklist //FI "IMAGENAME eq python.exe" //FO CSV //NH 2>/dev/null | cut -d, -f2 | tr -d '"' | tr -d ' ')
        # 遍历 PID，用 wmic 检查命令行中是否含有关键字
        for pid in $pids; do
            if wmic process where "ProcessId=$pid" get CommandLine 2>/dev/null | tr -d '\000' | grep -q "$keyword"; then
                echo "$pid"
                return 0
            fi
        done
        return 1
    else
        # Unix: 用 ps + grep
        ps aux | grep "$keyword" | grep -v grep | awk '{print $2}' | head -1
    fi
}

# 跨平台杀进程
kill_pid() {
    local pid="$1"
    if [ -z "$pid" ]; then
        return 0
    fi
    if $IS_WINDOWS; then
        taskkill //F //PID "$pid" >/dev/null 2>&1 || true
    else
        kill "$pid" 2>/dev/null || true
    fi
}

# 跨平台 chmod（Windows 跳过）
safe_chmod() {
    if $IS_WINDOWS; then
        return 0
    fi
    chmod "$@"
}

# 跨平台 sleep（确保参数被接受）
safe_sleep() {
    sleep "$1" 2>/dev/null || sleep 1
}

cleanup() {
    # 杀掉测试中启动的代理进程
    if [ -n "$TEST_PID" ]; then
        kill_pid "$TEST_PID"
    fi
    # Windows 兜底：杀残留 Python 进程
    if $IS_WINDOWS; then
        taskkill //F //IM python.exe > /dev/null 2>&1 || true
    fi
    sleep 1
    # 切换出测试目录再删（防止自己占着目录导致 busy）
    cd /tmp 2>/dev/null || cd "$SCRIPT_DIR" || true
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "============================================"
echo "  RooCode Plus — 自动化测试"
echo "============================================"
if $IS_WINDOWS; then
    echo "  [平台: Windows (Git Bash)]"
fi
echo ""

# ---------- 环境准备 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="/tmp/roocode-test-$$"
echo "[准备] 创建隔离测试环境: $TEST_DIR"
echo "[准备] 从 $SCRIPT_DIR 复制项目文件..."
mkdir -p "$TEST_DIR"
cp -r "$SCRIPT_DIR"/* "$TEST_DIR/"
rm -rf "$TEST_DIR/.git" "$TEST_DIR/.vscode"
cd "$TEST_DIR"
# Windows 下不需要 chmod +x
if ! $IS_WINDOWS; then
    chmod +x install.sh start_proxy.sh
fi

echo ""

# ================================================================
# 测试 1: start_proxy.sh — 缺少 venv 时应报错退出
# ================================================================
echo "--- 测试 1: 缺少 venv 时应报错退出 ---"
rm -rf "$TEST_DIR/venv"
if bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_1.txt 2>&1; then
    fail "测试 1" "期望退出码非 0，实际为 0"
else
    if grep -qE "(虚拟环境|venv|virtual)" /tmp/test_out_1.txt; then
        pass "测试 1: 正确检测到缺少 venv 并退出"
    else
        fail "测试 1" "输出中没有 '未检测到 Python 虚拟环境'"
    fi
fi

# ================================================================
# 环境搭建：创建 venv + .env（供后续测试使用）
# ================================================================
echo ""
echo "--- 搭建测试 venv + .env ---"
python3 -m venv venv --without-pip 2>/dev/null || python3 -m venv venv 2>/dev/null

# 跨平台 venv 路径：Windows 用 Scripts/，Linux/macOS 用 bin/
if [ -f "venv/Scripts/python.exe" ]; then
    VENV_PYTHON="venv/Scripts/python.exe"
    VENV_PIP="venv/Scripts/pip.exe"
else
    VENV_PYTHON="venv/bin/python"
    VENV_PIP="venv/bin/pip"
fi

if [ -f "$VENV_PIP" ]; then
    "$VENV_PIP" install -r requirements.txt -q 2>&1
else
    curl -sS https://bootstrap.pypa.io/get-pip.py | "$VENV_PYTHON" -q 2>&1
    "$VENV_PIP" install -r requirements.txt -q 2>&1
fi
echo "DEEPSEEK_API_KEY=sk-test-fake-key-123" > .env
safe_chmod 600 .env
echo "  venv + .env 就绪"

# ================================================================
# 测试 2: start_proxy.sh — 端口冲突时应报错退出
# ================================================================
echo ""
echo "--- 测试 2: 端口冲突时应报错退出 ---"
set -x  # 调试模式：CI 日志中打印每条命令

# 用 Python 可靠占住 8000 端口（跨平台，绕过 bash 进程管理的坑）
DUMMY_PID=""
"$VENV_PYTHON" -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', 8000))
s.listen(1)
time.sleep(10)
" &
DUMMY_PID=$!
safe_sleep 1

# 确认占位进程存活
if [ -z "$DUMMY_PID" ] || ! kill -0 "$DUMMY_PID" 2>/dev/null; then
    set +x
    fail "测试 2" "Python 占位进程启动失败"
else
    # 尝试启动代理（端口冲突）
    bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_2.txt 2>&1 || true
    safe_sleep 1

    if grep -qE "8000|kill|lsof|error|failed" /tmp/test_out_2.txt 2>/dev/null; then
        set +x
        pass "测试 2: 正确检测到端口冲突"
    else
        set +x
        cat /tmp/test_out_2.txt 2>/dev/null || true
        fail "测试 2" "输出中未匹配到端口冲突关键字"
    fi

    # 防崩溃清理（|| true 必须！set -e 下 kill 失败会终止脚本）
    if $IS_WINDOWS; then
        taskkill //F //PID "$DUMMY_PID" > /dev/null 2>&1 || true
        # 兜底：无差别杀残留 python 进程
        taskkill //F //IM python.exe > /dev/null 2>&1 || true
    else
        kill -9 "$DUMMY_PID" > /dev/null 2>&1 || true
    fi
    # 给 Windows 留出释放端口和目录锁的时间
    safe_sleep 2
fi
set +x
# 强制清理残留进程后等待端口释放（测试 2 → 测试 3 过渡）
taskkill //F //IM python.exe > /dev/null 2>&1 || kill -9 $DUMMY_PID > /dev/null 2>&1 || true
safe_sleep 2

# ================================================================
# 测试 3: start_proxy.sh — 正常启动（端口空闲）
# ================================================================
echo ""
echo "--- 测试 3: 正常启动 ---"
set -x
if bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_3.txt 2>&1; then
    safe_sleep 1
    TEST_PID=$(find_pid "proxy_server.py")
    if [ -n "$TEST_PID" ]; then
        pass "测试 3: 代理正常启动 (PID=$TEST_PID)"
    else
        echo "--- proxy.log 内容 ---"
        cat "$TEST_DIR/proxy.log" 2>/dev/null || true
        fail "测试 3" "脚本返回成功但进程未找到"
    fi
    set +x
    # 清除本测试进程
    kill_pid "$TEST_PID"
    safe_sleep 1
else
    set +x
    fail "测试 3" "期望退出码 0，实际为非 0"
    echo "--- start_proxy.sh 输出 ---"
    cat /tmp/test_out_3.txt
    echo "--- proxy.log 内容 ---"
    cat "$TEST_DIR/proxy.log" 2>/dev/null || true
fi

# ================================================================
# 测试 4: install.sh — .env 已存在时跳过覆盖
# ================================================================
echo ""
echo "--- 测试 4: install.sh .env 已存在时跳过 ---"
printf 'n\nn\n' | bash "$TEST_DIR/install.sh" > /tmp/test_out_4.txt 2>&1
if grep -q "sk-test-fake-key-123" "$TEST_DIR/.env"; then
    pass "测试 4: 原有 .env 内容未被覆盖"
else
    fail "测试 4" ".env 内容被意外修改"
fi

echo ""
echo "============================================"
echo "  测试结果: ${GREEN}$PASS 通过${NC} / ${RED}$FAIL 失败${NC}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
