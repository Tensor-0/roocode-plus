#!/usr/bin/env bash
#
# RooCode Plus — 一键安装脚本
# 用法: cd ~/roocode-plus && bash install.sh
#
# 自动完成：Python 检测 → 创建 venv → pip install → 配置 API Key → 可选别名
#

set -e

# 动态获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================"
echo "  RooCode Plus — 一键安装"
echo "============================================"
echo ""

# ---------- 1. 检查 Python ----------
echo "[1/4] 检查 Python 环境..."

PYTHON=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        version=$("$cmd" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
        major=$(echo "$version" | cut -d. -f1)
        minor=$(echo "$version" | cut -d. -f2)
        if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
            PYTHON="$cmd"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo ""
    echo "[错误] 未检测到 Python 3.10+！"
    echo "请前往 https://www.python.org/downloads/ 下载安装。"
    echo "Windows 用户安装时务必勾选「Add Python to PATH」。"
    exit 1
fi

echo "  ✓ 检测到 $PYTHON ($("$PYTHON" --version))"
echo ""

# ---------- 2. 创建虚拟环境 + 安装依赖 ----------
echo "[2/4] 配置虚拟环境..."

if [ -d "venv" ]; then
    echo "  ✓ venv 已存在，跳过创建"
else
    "$PYTHON" -m venv venv
    echo "  ✓ 虚拟环境已创建"
fi

echo "  ⏳ 安装依赖 (fastapi, httpx, uvicorn)..."
"$SCRIPT_DIR/venv/bin/pip" install -r requirements.txt -q
echo "  ✓ 依赖安装完成"
echo ""

# ---------- 3. 配置 API Key ----------
echo "[3/4] 配置 DeepSeek API Key"
echo ""
echo "  API Key 保存在项目内的 .env 文件中（已被 .gitignore 排除，不会提交到 GitHub）。"
echo "  Key 只在你的电脑上，全程不经过第三方。"
echo ""

# 如果 .env 已存在，询问是否覆盖
if [ -f ".env" ]; then
    existing=$(sed -n 's/^DEEPSEEK_API_KEY=//p' .env 2>/dev/null || true)
    if [ -n "$existing" ]; then
        echo "  当前 .env 中已有 Key: ${existing:0:12}..."
        echo ""
        read -r -p "  是否覆盖？[y/N] " overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            echo "  保持现有 Key。"
            echo ""
        else
            rm -f .env
        fi
    fi
fi

if [ ! -f ".env" ]; then
    echo "  请输入你的 DeepSeek API Key（以 sk- 开头）："
    echo "  （在 https://platform.deepseek.com/ 的 API Keys 页面获取）"
    echo ""
    read -r -p "  API Key: " api_key_input

    if [ -z "$api_key_input" ]; then
        echo ""
        echo "  [警告] 未输入 Key。你可以稍后手动创建 .env 文件："
        echo "    echo 'DEEPSEEK_API_KEY=sk-你的真实密钥' > .env"
        echo ""
    else
        echo "DEEPSEEK_API_KEY=$api_key_input" > .env
        chmod 600 .env
        echo ""
        echo "  ✓ API Key 已保存到 .env（权限 600，仅你可读）"
        echo ""
    fi
fi

# ---------- 4. 可选：添加别名 ----------
echo "[4/4] 快速启动别名"
echo ""
echo "  添加别名后，以后在任意终端输入 roocode 即可一键启动代理，无需 cd。"
echo ""

# 检测 shell 类型
shell_rc=""
if [ -n "$ZSH_VERSION" ] || echo "$SHELL" | grep -q zsh; then
    shell_rc="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || echo "$SHELL" | grep -q bash; then
    shell_rc="$HOME/.bashrc"
else
    shell_rc="$HOME/.bashrc"
fi

read -r -p "  是否添加 roocode 别名？[Y/n] " add_alias
if [ "$add_alias" = "n" ] || [ "$add_alias" = "N" ]; then
    echo "  跳过。以后可手动添加："
    echo "    echo \"alias roocode='cd $SCRIPT_DIR && ./start_proxy.sh'\" >> $shell_rc"
else
    # 检查是否已存在
    if grep -q "alias roocode=" "$shell_rc" 2>/dev/null; then
        echo "  ! roocode 别名已存在于 $shell_rc，跳过"
    else
        echo "" >> "$shell_rc"
        echo "# RooCode Plus — 一键启动代理" >> "$shell_rc"
        echo "alias roocode='cd $SCRIPT_DIR && ./start_proxy.sh'" >> "$shell_rc"
        echo "  ✓ 别名已添加到 $shell_rc"
    fi
    echo ""
    echo "  ⚠ 请执行以下命令使别名立即生效（或关闭终端重新打开）："
    echo "    source $shell_rc"
fi

# ---------- 完成 ----------
echo ""
echo "============================================"
echo "  安装完成！"
echo "============================================"
echo ""
echo "  以后每次启动："
echo "    roocode          （添加别名后）"
echo "    或"
echo "    ./start_proxy.sh （在项目目录下）"
echo ""
echo "  首次启动后，按 README 中的「Roo Code 配置指南」配置 VS Code 即可使用。"
echo ""
