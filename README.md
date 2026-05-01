# 🔌 RooCode Plus

> 让 Roo Code 完美适配任何模型 | 当前支持 DeepSeek V4-Pro · 更多模型接入中

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python: 3.8+](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)

---

## 🧭 我应该看哪部分？

| 你的情况 | 去看这里 |
|---|---|
| 没用过 VS Code，没用过终端，第一次接触 AI 编程 | → [🟢 零基础教程](#-零基础教程高中生友好) |
| 还不知道怎么搞到 DeepSeek API Key（没注册、没充值） | → [🛒 获取 DeepSeek API Key](#-获取-deepseek-api-key) |
| 会用 VS Code 和终端，知道 venv/pip 是什么 | → [🔵 专业用户快速上手](#-专业用户快速上手) |
| 已经启动代理，要在 Roo Code 里配置 | → [🔧 Roo Code 配置指南](#-roo-code-配置指南) |
| 出错了！不知道怎么办 | → [🆘 故障排除大全](#-故障排除大全) |

---

## 📖 这个项目是什么？

**RooCode Plus** 是一个轻量级本地适配代理，架在 Roo Code 和各种 AI 模型 API 之间。

它的核心工作很简单：**Roo Code 发出的请求不一定能被目标模型完全理解，Plus 在中间自动帮你修正，让请求 100% 符合目标模型的格式要求。**

### 🎯 解决的问题

Roo Code 是一个强大的 AI 编程助手前端，但当你切换不同模型时，常常会遇到：

| 问题 | 表现 |
|---|---|
| **参数不兼容** | 模型不认识 Roo Code 发出的某些字段，返回 `400 Bad Request` |
| **历史记录校验失败** | 多轮对话中，之前 AI 的回复格式不符合模型要求，对话突然中断 |
| **能力未完全激活** | 模型的一些高级功能（如深度思考）需要特定参数才能启用 |
| **上下文浪费** | 因格式问题导致模型无法充分利用其上下文窗口 |

**RooCode Plus 在请求发出去之前帮你把这些问题全部修好。**

---

## 🔒 安全性说明（专业用户必读）

> 作为本地代理，RooCode Plus 会处理你的 API 请求和代码上下文。以下从专业角度说明安全模型。

### 架构安全

| 维度 | 设计决策 |
|---|---|
| **网络边界** | 默认绑定 `127.0.0.1:8000`，仅监听本地回环地址，外网无法访问 |
| **API Key 存储** | 通过环境变量 `DEEPSEEK_API_KEY` 注入，代码中不包含任何硬编码密钥 |
| **请求转发** | 请求经代理修正后直连 `api.deepseek.com`，无中间跳转、无第三方日志上报 |
| **数据落盘** | 代理本身不存储任何请求/响应内容。日志仅输出连接状态到 `proxy.log`，不记录对话正文 |
| **依赖最小化** | 仅依赖 `fastapi` + `httpx` + `uvicorn` 三个包，攻击面可控 |

### 代码级安全验证

```bash
# 克隆后立即验证：确认代码中没有硬编码密钥
grep -n "sk-" proxy_server.py
# 唯一输出应为第 9 行的默认占位符注释，不包含真实密钥

# 确认监听地址
grep "host=" proxy_server.py
# 输出: uvicorn.run(app, host="127.0.0.1", port=8000, ...)
```

### 你的 API Key 流经路径

```text
你的 Shell 环境变量                代理内存（进程存活期间）
DEEPSEEK_API_KEY="sk-xxx"  ──▶  os.environ.get()  ──▶  Authorization Header
                                                          │
                                                    api.deepseek.com
                                                          │
                                             Key 不出本地网络边界
```

全程 **Key 不会写入磁盘、不会发送到第三方、不会出现在日志中**。

### 风险边界

| 风险 | 等级 | 缓解措施 |
|---|---|---|
| 本地恶意软件读取环境变量 | 低 | 不属本项目范围，属操作系统安全 |
| 代理端口被局域网扫描 | 低 | 默认 `127.0.0.1` 不暴露到局域网 |
| 日志文件泄露敏感信息 | 极低 | 日志不含对话正文、不含 Key |
| 依赖包供应链攻击 | 极低 | 三个依赖均为 PyPI 顶级包（fastapi 70k+ stars，httpx 13k+ stars） |

### 生产环境建议

如果你要在团队服务器上部署：

```bash
# 1. 使用 systemd 管理进程（而非 nohup）
# 2. 通过 systemd EnvironmentFile 注入 API Key（而非 ~/.bashrc）
# 3. 限制 proxy.log 文件权限
chmod 600 proxy.log
# 4. 考虑添加 rate limiting（参考 proxy_server.py 中 apply_model_patches 的 TODO）
```

---

## 🗺️ 适配路线图

| 模型 | 状态 |
|---|---|
| DeepSeek (V4-Pro) | ✅ 已支持 |
| OpenAI (GPT-4o) | 🚧 计划中 |
| Anthropic (Claude) | 🚧 计划中 |
| Google (Gemini) | 📋 待评估 |

> 💡 欢迎提交 PR 贡献新模型适配器！

---

# 🛒 获取 DeepSeek API Key

> 不管你是什么水平，没有 API Key 就等于没有「燃料」。这一章帮你从零搞到一个可用的 DeepSeek API Key。

---

## 🟢 零基础版：手把手教你注册 + 充值 + 拿密钥

> 适合：没在 DeepSeek 注册过账号，没用过任何 API 平台。

### 第 1 步：注册 DeepSeek 账号

1. 打开浏览器，访问 **[platform.deepseek.com](https://platform.deepseek.com/)**
2. 点击页面右上角的 **「登录 / 注册」**
3. 你可以选择：
   - **手机号注册**：输入手机号 → 收验证码 → 填验证码 → 设置密码
   - **微信扫码**：用微信扫页面上的二维码 → 在手机上确认
4. 注册/登录成功后，你会看到 DeepSeek 的控制台页面（Dashboard）

> 💡 这个平台和 chat.deepseek.com（聊天页面）是两个不同的网站。我们要用的是 **platform.deepseek.com**，这是「开发者平台」，在这里才能拿到 API Key。

### 第 2 步：充值（充值后才有 API 额度）

> ⚠️ 新账号没有余额，必须充值才能用 API。好消息是 DeepSeek **充值门槛很低**，几块钱就能开始用。

1. 在左侧菜单栏点击 **「充值」**（或页面顶部的「费用中心」）
2. 你会看到充值页面，输入充值金额：
   - **建议第一次充 10-20 元**，足够你个人用很久了
   - DeepSeek V4-Pro 的价格大约是 **输入 ¥2 元/百万 token，输出 ¥8 元/百万 token**
   - 普通编程对话一次大概消耗几千到几万 token，非常便宜
3. 选择支付方式（微信 / 支付宝）
4. 扫码支付

> 💡 **关于花了多少钱**：如果你只是自己写代码用，一个月 10-20 元绰绰有余。不用担心「天价账单」，API 调用就跟你交话费一样，用了多少扣多少。

### 第 3 步：创建 API Key

1. 在左侧菜单栏点击 **「API Keys」**
2. 点击 **「创建 API Key」** 按钮
3. 系统会弹出一个窗口，里面有一串以 `sk-` 开头的字符，这就是你的 API Key
   - 格式类似：`sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
4. **立刻复制这串密钥并保存到安全的地方！**
   - ⚠️ 这个窗口关掉后，你就再也看不到完整的 Key 了（这是安全设计）
   - 如果弄丢了，只能删掉旧的重新创建一个新的

> 💡 把 Key 看成你的「银行卡密码」。不要发到群里，不要截图给别人看，不要贴到公开的论坛里。如果有人拿到你的 Key，他可以用你的账户调用 API，费用从你的余额里扣。

---

## 🔵 专业版：3 步拿 Key

1. 访问 [platform.deepseek.com](https://platform.deepseek.com/) 注册/登录
2. 进入「充值」页面，充值任意金额（建议 ¥10+）→ 扫码支付
3. 进入「API Keys」→ 「创建 API Key」→ 复制 `sk-` 开头的密钥

---

## 📊 DeepSeek API 计费速查

| 模型 | 输入价格 | 输出价格 | 上下文窗口 |
|---|---|---|---|
| deepseek-chat (V4-Pro) | ¥2 / 百万 token | ¥8 / 百万 token | 1M token |
| deepseek-reasoner (R1) | ¥4 / 百万 token | ¥16 / 百万 token | 64K token |

> 💡 **1 百万 token 是什么概念？** 大概相当于 3-4 本《三体》第一部的文字量。普通编程对话，每次问答消耗几千到几万 token，非常经用。

---

## 💰 费用估算（给心里没底的同学）

| 使用场景 | 大概花费 |
|---|---|
| 偶尔用，每天问几个编程问题 | 每月 5-10 元 |
| 高频使用，每天写几百行代码 | 每月 15-30 元 |
| 重度使用，把 AI 当搭档全天干活 | 每月 50-100 元 |

> 🔔 **省钱提示**：DeepSeek 的 API 没有月费、没有最低消费，充值余额永久有效。用多少扣多少，不用担心「包月用不完」的问题。

---

# 🟢 零基础教程（高中生友好）

> 如果你从来没打开过「终端」，不知道什么叫「命令行」—— 别怕，跟着下面一步步做，每步都有解释。

---

## 第 1 章：准备工作（一次性）

### 1.1 什么是「终端」？

终端就是你和电脑「打字交流」的地方。在 VS Code 里按 `` Ctrl+` ``（键盘左上角 ESC 下面的那个键），下面会弹出一个窗口，那个就是终端。

> 📺 **视觉参考**：弹出窗口里你会看到类似 `user@computer:~$` 这样的一行字，光标在 `$` 后面闪 —— 这就是终端，等着你输入命令。

### 1.2 确保你有 Python

在终端里**一个字一个字地**输入下面这行，然后按回车：

```bash
python3 --version
```

你应该看到类似 `Python 3.10.12` 或 `Python 3.11.x` 的输出。

**如果显示的不是 3.8 以上的数字**，说明你没有 Python。去 [python.org](https://www.python.org/downloads/) 下载安装。

> 💡 输入命令时不需要打 `bash` 那个字，`bash` 只是标记「这是一条终端命令」。你只需要输入 `python3 --version` 然后按回车。

### 1.3 下载本项目

在终端里**一行一行地**执行（每行输完按回车，等它跑完再输下一行）：

```bash
cd ~
```

> 💡 这行命令的意思：把终端「切换」到家目录。`~` 就是你的个人文件夹的缩写，`cd` 就是「去某个地方」。

```bash
git clone https://github.com/Tensor-0/roocode-plus.git
```

> 💡 这行命令的意思：从 GitHub 把代码「克隆」到你的电脑上。`clone` = 复制一份。如果提示 `git: command not found`，见 [故障：提示 'git' 未找到](#1-提示-git-未找到)。

```bash
cd roocode-plus
```

> 💡 进入刚刚下载的 roocode-plus 文件夹。

### 1.4 创建「虚拟环境」

Python 的虚拟环境就像给这个项目划了一间「单独的房间」，里面安装的东西不会影响你电脑上的其他程序。

在终端里：

```bash
python3 -m venv venv
```

> 💡 `-m venv venv` 的意思是「用 Python 的 venv 模块，创建一个叫 venv 的文件夹」。输完可能没有任何提示，这是正常的（在终端里，「没消息就是好消息」）。

### 1.5 进入虚拟环境

```bash
source venv/bin/activate
```

执行后，你会看到终端前面多了一个 `(venv)` 的标志。这表示你已经进入了「房间」。

> 💡 如果你是 Windows 系统，命令不同：`venv\Scripts\activate`

### 1.6 安装依赖

```bash
pip install fastapi httpx uvicorn
```

> 💡 `pip install` = 从网上下载安装 Python 插件包。你会看到一堆进度条在跑，最后出现 `Successfully installed ...` 就对了。

### 1.7 设置 API Key

```bash
export DEEPSEEK_API_KEY="sk-你的真实密钥"
```

> ⚠️ 把 `sk-你的真实密钥` 替换成你的真实 DeepSeek API Key（在 [platform.deepseek.com](https://platform.deepseek.com/) 的 API Keys 页面获取）。密钥格式类似 `sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`。

### 1.8 启动代理

```bash
./start_proxy.sh
```

你应该看到：

```text
============================================
  RooCode Plus — Multi-Model Adapter
============================================
[成功] RooCode Plus 已在后台启动！PID: 12345
       监听地址: http://127.0.0.1:8000/v1/chat/completions
```

> 🎉 恭喜！代理已经运行起来了。现在保持终端不要关，去看下面的 [Roo Code 配置指南](#-roo-code-配置指南)。

---

### 🆘 零基础常见问题快速跳转

| 问题 | 跳转 |
|---|---|
| 提示 `python3: command not found` | → [故障 2](#2-提示-python3-未找到) |
| 提示 `git: command not found` | → [故障 1](#1-提示-git-未找到) |
| `pip install` 报网络错误 | → [故障 5](#5-网络连接失败) |
| 提示 `permission denied: ./start_proxy.sh` | → [故障 11](#11-权限拒绝-permission-denied) |
| 什么提示都没有就结束了 | → [故障 3](#3-漏步骤或跳步骤了) |

---

# 🔵 专业用户快速上手

### 环境要求

- **Python** ≥ 3.8
- **操作系统**: Linux / macOS / Windows (WSL)

### 1. 克隆

```bash
git clone https://github.com/Tensor-0/roocode-plus.git
cd roocode-plus
```

### 2. 安装

```bash
python3 -m venv venv
source venv/bin/activate
pip install fastapi httpx uvicorn
```

### 3. 配置 API Key

```bash
export DEEPSEEK_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

> 也可写入 `~/.bashrc` / `~/.zshrc` 持久化。

### 4. 启动

```bash
./start_proxy.sh
```

启动成功后：

```text
============================================
  RooCode Plus — Multi-Model Adapter
============================================
[成功] RooCode Plus 已在后台启动！PID: 12345
       监听地址: http://127.0.0.1:8000/v1/chat/completions
```

---

## 🔧 Roo Code 配置指南

### 步骤 1：打开 Roo Code 设置

在 VS Code 中，点击左侧 Roo Code 面板 → 右上角齿轮图标 ⚙️ → **Provider Settings**。

> 📺 **视觉参考**：左侧边栏有一个 Roo Code 的图标（通常是一个小机器人），点击它会展开一个面板。面板右上角有一个齿轮 ⚙️。

### 步骤 2：配置提供商

| 配置项 | 值 |
|---|---|
| **API Provider** | `OpenAI Compatible` |
| **Base URL** | `http://127.0.0.1:8000/v1` |
| **API Key** | 任意非空字符串（如 `roocode-plus`） |
| **Model ID** | `deepseek-chat` |

### 步骤 3：验证

在 Roo Code 聊天框发送：

```
你好！当前使用的上下文窗口有多大？
```

如果适配层正常工作，你将看到模型的完整思考链输出。

### 工作原理

```text
┌──────────┐   请求    ┌─────────────────┐   修正后请求   ┌──────────────────┐
│  Roo Code │────────▶│  RooCode Plus   │─────────────▶│  目标模型 API    │
│  (VS Code)│         │  127.0.0.1:8000 │              │  (DeepSeek/...)  │
└──────────┘         └─────────────────┘              └──────────────────┘
                            │
                            ├── 检查并注入模型必需参数
                            ├── 补全缺失字段（如 reasoning_content）
                            ├── 修正消息格式
                            └── 流式转发响应（零性能损耗）
```

---

# 🆘 故障排除大全

> 遇到问题了？按 Ctrl+F 搜索你的错误信息，或按编号查找。

---

## 安装阶段故障

### 1. 提示 'git' 未找到

**错误信息**：`git: command not found` 或 `'git' 不是内部或外部命令`

**原因**：你的电脑没装 Git。

**解决**：

- **Windows**: 去 [git-scm.com](https://git-scm.com/downloads/win) 下载安装，一路点「Next」，全部用默认选项即可。
- **macOS**: 在终端输入 `xcode-select --install`，弹窗点「安装」。
- **Linux**: 在终端输入 `sudo apt install git -y`（Ubuntu/Debian）或 `sudo yum install git -y`（CentOS）。

装好后重新打开终端，输入 `git --version` 确认。

### 2. 提示 'python3' 未找到

**错误信息**：`python3: command not found`

**原因**：没装 Python 或者装了但命令名不一样。

**解决**：

1. 试试输入 `python --version`（不带 3），看能否显示 Python 3.x。
2. 如果不能，去 [python.org](https://www.python.org/downloads/) 下载 Python 安装包。
   - **Windows 安装注意**：安装界面**一定要勾选**「Add Python to PATH」这个复选框！不然装完还得手动配。
3. 装好后**关掉终端重新打开**，再试。

### 3. 漏步骤或跳步骤了

**症状**：执行某条命令时报错，但前面的命令好像跑过。

**常见漏步**：

| 如果你跳过了 | 出错的命令 | 怎么补救 |
|---|---|---|
| `cd roocode-plus` | `./start_proxy.sh` 找不到 | 手动执行 `cd ~/roocode-plus` |
| `python3 -m venv venv` | `source venv/bin/activate` 失败 | 回到第 1.4 步创建虚拟环境 |
| `source venv/bin/activate` | `pip install` 装到了系统而非虚拟环境 | 先执行 `source venv/bin/activate` |
| `pip install ...` | `./start_proxy.sh` 报缺少模块 | 先执行 `pip install fastapi httpx uvicorn` |

> 💡 **最安全的做法**：严格按顺序操作，每步确认成功后再做下一步。终端里「没报错」就是成功。

### 4. 看错步骤了

**症状**：你觉得自己照着做了，但就是不行。

**最常见的看错情况**：

- 把 `roocode-plus` 打成了 `roocode_plus`（下划线 vs 横线）
- 把 `DEEPSEEK_API_KEY` 打成了 `DEEPSEEK_APIKEY`（少了下划线）
- 把 `sk-` 后面的密钥中的字母 `I`（大写 i）看成了 `l`（小写 L）或 `1`（数字 1）
- 把 `./start_proxy.sh` 打成了 `./start proxy.sh`（多了空格）

> 💡 **自查方法**：把你的命令和教程里的命令**逐个字符**对比一遍。特别检查英文大小写、横线/下划线、空格。

---

## 运行阶段故障

### 5. 网络连接失败

**错误信息**：`pip install` 时出现 `Connection timeout`、`Network is unreachable`、`Could not resolve host`

**原因**：你开了代理但代理有问题，或者网络本身不稳定。

**解决**：

**场景 A —— 你开着 VPN 或代理软件（如 Clash、V2Ray）**：
```bash
# 先关掉代理软件，然后在终端里输入：
unset http_proxy
unset https_proxy
unset all_proxy
# 再重试 pip install
pip install fastapi httpx uvicorn
```

**场景 B —— 你在中国大陆，没开代理**：
```bash
# 使用清华镜像源加速
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple fastapi httpx uvicorn
```

**场景 C —— 代理开着但配置不对**：
```bash
# 检查当前代理设置
echo $http_proxy
echo $https_proxy
# 如果输出不为空但代理软件已关，清除它们：
unset http_proxy https_proxy all_proxy
```

### 6. 代理启动后 Roo Code 连不上

**症状**：Roo Code 报 `Failed to fetch` 或连接被拒绝。

**逐项排查**：

```
[1] 代理还在运行吗？
    → 终端输入: ps aux | grep proxy_server
    → 如果没有输出，说明代理已经挂了，重新执行 ./start_proxy.sh

[2] 端口对吗？
    → 确认 Roo Code 的 Base URL 是 http://127.0.0.1:8000/v1
    → 不是 https！不是 http://localhost！是 http://127.0.0.1:8000/v1

[3] 防火墙拦了吗？
    → Windows 用户：首次启动代理时可能会弹出防火墙提示，必须点「允许」
    → 如果没弹窗或点了阻止：去 Windows 防火墙设置里放行 Python

[4] 代理端报错了吗？
    → 终端输入: tail -20 proxy.log
    → 查看最后 20 行日志，找到具体错误原因
```

### 7. DeepSeek API 返回 401 Unauthorized

**错误信息**：`[API 报错] 状态码: 401`

**原因**：DeepSeek API Key 不对。

**解决**：
```bash
# 检查当前设置的值
echo $DEEPSEEK_API_KEY
# 如果显示为空或「你的真实API_KEY写在这里」，需要重新设置：
export DEEPSEEK_API_KEY="sk-你的真实密钥"
# 然后重启代理：
kill $(ps aux | grep proxy_server | grep -v grep | awk '{print $2}')
./start_proxy.sh
```

> ⚠️ 注意检查密钥中是否混入了空格（复制粘贴时常见）。密钥应该是连续的字符，没有空格。

### 8. DeepSeek API 返回 400 Bad Request

**错误信息**：`[API 报错] 状态码: 400`

**可能原因及解决**：

| 原因 | 解决 |
|---|---|
| Roo Code 端的 Model ID 填错了 | 必须填 `deepseek-chat`，不是 `deepseek-v4` 或其他 |
| Base URL 多了/少了路径 | 必须是 `http://127.0.0.1:8000/v1`，不要在末尾加 `/chat/completions` |
| API Key 为空 | Roo Code 侧随便填一个非空字符串即可 |

### 9. 突然电脑关机了

**症状**：电脑重启后，之前能用的代理连不上了。

**原因**：代理是后台运行的，关机后进程自然就没了。而且终端里的 `export` 命令设置的 API Key 在重启后也丢失了。

**解决**（按顺序）：

```bash
# 1. 重新进入项目目录
cd ~/roocode-plus

# 2. 重新激活虚拟环境
source venv/bin/activate

# 3. 重新设置 API Key
export DEEPSEEK_API_KEY="sk-你的真实密钥"

# 4. 重新启动代理
./start_proxy.sh
```

> 💡 **不想每次重启都配？** 把 `export DEEPSEEK_API_KEY="sk-..."` 写入 `~/.bashrc` 文件末尾即可永久生效：
> ```bash
> echo 'export DEEPSEEK_API_KEY="sk-你的真实密钥"' >> ~/.bashrc
> source ~/.bashrc
> ```

### 10. 端口被占用

**错误信息**：`OSError: [Errno 98] Address already in use` 或 `端口 8000 已被占用`

**原因**：上次的代理进程可能没关干净，或者有其他程序占了 8000 端口。

**解决**：

```bash
# 方法 1：杀掉旧进程
kill $(lsof -t -i:8000) 2>/dev/null
# 然后重新启动
./start_proxy.sh

# 方法 2：如果方法 1 不行，换一个端口
# 编辑 proxy_server.py 最后一行的 port=8000 改成 port=9000
# 然后 Roo Code 的 Base URL 也改成 http://127.0.0.1:9000/v1
```

### 11. 权限拒绝 (Permission Denied)

**错误信息**：`bash: ./start_proxy.sh: Permission denied` 或 `permission denied`

**原因**：脚本没有执行权限。

**解决**：

```bash
chmod +x start_proxy.sh
```

然后重新执行 `./start_proxy.sh`。

### 12. 虚拟环境找不到

**错误信息**：启动脚本显示 `[错误] 未检测到 Python 虚拟环境`

**原因**：没有创建 venv 或者不在项目目录里。

**解决**：

```bash
# 确认你在项目目录
cd ~/roocode-plus
# 确认 venv 文件夹存在
ls venv/bin/activate
# 如果不存在，创建它：
python3 -m venv venv
# 然后安装依赖：
source venv/bin/activate
pip install fastapi httpx uvicorn
```

### 13. 代理日志显示 "Name or service not known"

**错误信息**：`[API 报错] ... Name or service not known`

**原因**：DNS 解析失败，你的网络环境无法访问 `api.deepseek.com`。

**解决**：

```bash
# 测试是否真的连不上
curl -I https://api.deepseek.com

# 如果确认连不上：
# 1. 检查你是否能正常上网（打开浏览器随便访问一个网站试试）
# 2. 如果开着代理，参考 [故障 5](#5-网络连接失败) 排查代理问题
# 3. 如果在中国大陆没开代理，DeepSeek API 可能被墙，需要开代理
```

---

## Roo Code 配置阶段故障

### 14. Roo Code 里找不到某个配置项

**原因**：Roo Code 版本太旧或界面布局有差异。

**解决**：

1. 确保 VS Code 和 Roo Code 扩展都是最新版（在 VS Code 扩展面板搜索 Roo Code，点「更新」）。
2. 如果界面不同，核心原则不变：找到 Provider 设置 → 选「OpenAI Compatible」类型 → 填入 Base URL 和 Model ID。

### 15. 配置完 Roo Code 后没有任何反应

**症状**：发了消息，Roo Code 没有任何输出，也没有报错。

**排查**：

```bash
# 1. 看代理日志有没有收到请求
tail -f ~/roocode-plus/proxy.log
# 然后在 Roo Code 里再发一条消息
# 如果日志没有任何新输出 → Roo Code 根本没连到代理

# 2. 检查 Roo Code 配置
# - API Provider 是不是选的 "OpenAI Compatible"？
# - Base URL 是不是 http://127.0.0.1:8000/v1 ？
# - 有没有不小心在前面多打了一个空格？
# - 是不是选错了 Profile（Roo Code 有多个 Profile 切换）？
```

---

## 📁 项目结构

```text
roocode-plus/
├── proxy_server.py    # 适配核心：请求拦截 + 参数修正 + 流式转发
├── start_proxy.sh     # 一键启动脚本（零硬编码路径）
├── .gitignore         # 忽略 venv/log/pyc/.env
├── .clinerules        # 贡献者代码规范
└── README.md          # 本文件
```

---

## 🤝 如何贡献新模型适配器

`proxy_server.py` 的架构天然支持多模型扩展。添加新适配只需两步：

**1. 在 `apply_model_patches()` 中添加分支：**

```python
def apply_model_patches(body: dict) -> dict:
    # ... 现有 DeepSeek 逻辑 ...

    # 新增: Claude 适配
    # body["anthropic_version"] = "2023-06-01"
    # ...

    # 新增: Gemini 适配
    # body["safety_settings"] = [...]
    # ...

    return body
```

**2. 更新 `TARGET_URL` 和环境变量读取逻辑（支持动态切换）。**

欢迎 Fork & PR！

---

## ❓ 常见问题

### Q: Roo Code 侧的 API Key 填什么？

填任意非空字符串即可（如 `roocode-plus`）。真正的 API Key 由代理侧通过环境变量读取。

### Q: 如何查看实时日志？

```bash
tail -f proxy.log
```

### Q: 如何停止代理？

```bash
ps aux | grep proxy_server
kill <PID>
```

---

## 📄 License

MIT License © 2025

---

<p align="center">
  <b>Made with ❤️ for the Roo Code community</b><br>
  <sub>如果 RooCode Plus 解决了你的问题，请给一个 ⭐ Star！</sub>
</p>
