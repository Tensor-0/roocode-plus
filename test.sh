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
        local pids
        pids=$(tasklist //FI "IMAGENAME eq python.exe" //FO CSV //NH 2>/dev/null | cut -d, -f2 | tr -d '"' | tr -d ' ')
        for pid in $pids; do
            if wmic process where "ProcessId=$pid" get CommandLine 2>/dev/null | tr -d '\000' | grep -q "$keyword"; then
                echo "$pid"
                return 0
            fi
        done
        return 1
    else
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

# 跨平台强杀所有 python 进程（仅测试清理用）
nuke_all_python() {
    if $IS_WINDOWS; then
        taskkill //F //IM python.exe > /dev/null 2>&1 || true
    else
        pkill -9 -f python 2>/dev/null || true
    fi
}

# 跨平台杀占用指定端口的进程
kill_port() {
    local port="$1"
    if $IS_WINDOWS; then
        # Windows: 用 netstat 找 PID 然后用 taskkill
        local pid
        pid=$(netstat -ano 2>/dev/null | grep ":$port " | grep LISTENING | awk '{print $NF}' | head -1)
        if [ -n "$pid" ]; then
            taskkill //F //PID "$pid" > /dev/null 2>&1 || true
        fi
    else
        # Unix: lsof 或 fuser
        kill $(lsof -t -i:$port) 2>/dev/null || fuser -k ${port}/tcp 2>/dev/null || true
    fi
}

cleanup() {
    if [ -n "$TEST_PID" ]; then
        kill_pid "$TEST_PID"
    fi
    nuke_all_python
    sleep 1
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
        fail "测试 1" "输出中没有 '虚拟环境/venv/virtual'"
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
set -x

# 用 Python 可靠占住 8000 端口（跨平台）
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

    # 防崩溃清理
    if $IS_WINDOWS; then
        taskkill //F //PID "$DUMMY_PID" > /dev/null 2>&1 || true
        taskkill //F //IM python.exe > /dev/null 2>&1 || true
    else
        kill -9 "$DUMMY_PID" > /dev/null 2>&1 || true
    fi
    safe_sleep 2
fi
set +x
nuke_all_python
safe_sleep 2

# ================================================================
# 测试 3: start_proxy.sh — 正常启动（curl 验证端口）
# ================================================================
echo ""
echo "--- 测试 3: 正常启动 ---"
set -x
if bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_3.txt 2>&1; then
    set +x
    # 用 curl 重试验证端口（比查找进程名更可靠）
    TEST_PASS=0
    for i in 1 2 3 4 5; do
        if curl -s http://127.0.0.1:8000/docs > /dev/null 2>&1; then
            TEST_PASS=1
            break
        fi
        safe_sleep 1
    done

    if [ "$TEST_PASS" = "1" ]; then
        pass "测试 3: 代理成功响应 HTTP 请求"
    else
        echo "=== 测试 3 代理响应失败！下面是日志：==="
        cat "$TEST_DIR/proxy.log" 2>/dev/null || true
        fail "测试 3" "代理未能响应请求"
    fi

    # 清理：杀占用 8000 端口的进程
    kill_port 8000
    safe_sleep 1
else
    set +x
    fail "测试 3" "期望退出码 0，实际为非 0"
    echo "--- start_proxy.sh 输出 ---"
    cat /tmp/test_out_3.txt
    echo "--- proxy.log 内容 ---"
    cat "$TEST_DIR/proxy.log" 2>/dev/null || true
    # 清理可能的残留
    kill_port 8000
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
