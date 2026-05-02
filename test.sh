#!/usr/bin/env bash
#
# RooCode Plus — 自动化测试脚本
# 用法: bash test.sh
#
# 在 /tmp 隔离环境中运行，不影响当前项目。
# 覆盖 install.sh 和 start_proxy.sh 的 happy path + 常见错误场景。
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0

pass() { echo -e "  ${GREEN}✓ PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "  ${RED}✗ FAIL${NC} $1 — $2"; FAIL=$((FAIL + 1)); }

cleanup() {
    # 杀掉测试中启动的代理进程
    if [ -n "$TEST_PID" ] && kill -0 "$TEST_PID" 2>/dev/null; then
        kill "$TEST_PID" 2>/dev/null || true
    fi
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

echo "============================================"
echo "  RooCode Plus — 自动化测试"
echo "============================================"
echo ""

# ---------- 环境准备 ----------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="/tmp/roocode-test-$$"
echo "[准备] 创建隔离测试环境: $TEST_DIR"
echo "[准备] 从 $SCRIPT_DIR 复制项目文件..."
mkdir -p "$TEST_DIR"
cp -r "$SCRIPT_DIR"/* "$TEST_DIR/"
# .git 目录太大，不复制（测试用不到）；.vscode 也不复制
rm -rf "$TEST_DIR/.git" "$TEST_DIR/.vscode"
cd "$TEST_DIR"
chmod +x install.sh start_proxy.sh

echo ""

# ================================================================
# 测试 1: start_proxy.sh — 缺少 venv 时应报错退出
# ================================================================
echo "--- 测试 1: 缺少 venv 时应报错退出 ---"
rm -rf "$TEST_DIR/venv"
if bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_1.txt 2>&1; then
    fail "测试 1" "期望退出码非 0，实际为 0"
else
    if grep -q "未检测到 Python 虚拟环境" /tmp/test_out_1.txt; then
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
if [ -f venv/bin/pip ]; then
    venv/bin/pip install -r requirements.txt -q 2>&1
else
    curl -sS https://bootstrap.pypa.io/get-pip.py | venv/bin/python -q 2>&1
    venv/bin/pip install -r requirements.txt -q 2>&1
fi
echo "DEEPSEEK_API_KEY=sk-test-fake-key-123" > .env
chmod 600 .env
echo "  venv + .env 就绪"

# ================================================================
# 测试 2: start_proxy.sh — 端口冲突时应报错退出
# ================================================================
echo ""
echo "--- 测试 2: 端口冲突时应报错退出 ---"
# 先启动一个占用 8000 端口的代理
bash "$TEST_DIR/start_proxy.sh" > /dev/null 2>&1
sleep 1
FIRST_PID=$(pgrep -f "proxy_server.py" | grep -v grep | head -1 || true)
if [ -z "$FIRST_PID" ]; then
    fail "测试 2" "首个代理启动失败，无法继续测试端口冲突"
else
    # 尝试再启动一个（端口冲突）
    if bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_2.txt 2>&1; then
        fail "测试 2" "期望退出码非 0（端口冲突），实际为 0"
    else
        if grep -q "端口 8000 已被占用" /tmp/test_out_2.txt; then
            pass "测试 2: 正确检测到端口冲突"
        else
            # 兼容输出中的失败提示
            if grep -q "代理进程启动后立即退出" /tmp/test_out_2.txt; then
                pass "测试 2: 正确检测到进程失败（端口冲突）"
            else
                fail "测试 2" "输出中没有端口冲突或进程失败提示"
            fi
        fi
    fi
    kill "$FIRST_PID" 2>/dev/null || true
    sleep 1
fi

# ================================================================
# 测试 3: start_proxy.sh — 正常启动（端口空闲）
# ================================================================
echo ""
echo "--- 测试 3: 正常启动 ---"
if bash "$TEST_DIR/start_proxy.sh" > /tmp/test_out_3.txt 2>&1; then
    TEST_PID=$(pgrep -f "proxy_server.py" | grep -v grep | head -1 || true)
    if [ -n "$TEST_PID" ]; then
        pass "测试 3: 代理正常启动 (PID=$TEST_PID)"
    else
        fail "测试 3" "脚本返回成功但进程未找到"
    fi
else
    fail "测试 3" "期望退出码 0，实际为非 0"
    cat /tmp/test_out_3.txt
fi

# ================================================================
# 测试 4: install.sh — .env 已存在时跳过覆盖
# ================================================================
echo ""
echo "--- 测试 4: install.sh .env 已存在时跳过 ---"
# 用交互式管道：先选不覆盖 (n)，然后选不加别名 (n)
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
