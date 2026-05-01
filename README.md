# RooCode Plus

Roo Code 的多模型适配层。解决 Roo Code 切换到不同模型时遇到的兼容性问题。目前适配了 DeepSeek，后续会覆盖更多模型。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python: 3.10+](https://img.shields.io/badge/Python-3.10+-blue.svg)](https://www.python.org/)

---

## 我应该看哪部分

| 你的情况 | 去看这里 |
|---|---|
| 没用过 VS Code，没用过终端，第一次接触 AI 编程 | [零基础教程](#零基础教程) |
| 还不知道怎么搞到 DeepSeek API Key（没注册、没充值） | [获取 DeepSeek API Key](#获取-deepseek-api-key) |
| 会用 VS Code 和终端，知道 venv/pip 是什么 | [专业用户快速上手](#专业用户快速上手) |
| 想了解安全模型，代码有没有埋坑 | [安全性说明](#安全性说明) |
| 已经启动了，要在 Roo Code 里配置 | [Roo Code 配置指南](#roo-code-配置指南) |
| 出错了 | [故障排除](#故障排除) |

---

## 这个项目解决什么问题

Roo Code 默认使用的请求格式和很多模型的实际要求有偏差。具体表现：

- 模型不认识某些字段，直接返回 400
- 多轮对话时历史消息校验不通过，对话断掉
- thinking / reasoning_effort 这类参数没有被带上
- 上下文窗口利用率低，白花了 token 钱

RooCode Plus 在 Roo Code 和目标 API 之间做一层请求修正，把这些兼容性问题处理掉。

---

## 适配路线图

| 模型 | 状态 |
|---|---|
| DeepSeek (V4-Pro) | 已支持 |
| OpenAI (GPT-4o) | 计划中 |
| Anthropic (Claude) | 计划中 |
| Google (Gemini) | 待评估 |

欢迎 PR 贡献新模型适配器。

---

## 安全性说明

本地代理会处理你的 API 请求和代码上下文。以下是安全设计。

### 架构

- 默认只监听 `127.0.0.1:8000`，外网访问不到
- API Key 通过环境变量 `DEEPSEEK_API_KEY` 读入，源码里不存任何真实密钥（默认值为空字符串）
- 请求直连 `api.deepseek.com`，中间不经过任何第三方
- 不存请求/响应内容。`proxy.log` 只记连接状态，不写对话正文
- 三个依赖（见 `requirements.txt`）：fastapi、httpx、uvicorn，没有隐藏的第四方包

### 自检方法

clone 下来之后自己跑两条命令确认：

```bash
# 确认代码里没有硬编码密钥
grep -n "sk-" proxy_server.py
# 仅匹配注释行（如 export DEEPSEEK_API_KEY="sk-xxx"），不是真实 key
# 实际代码中 API_KEY 默认值为空字符串

# 确认没监听公网
grep "host=" proxy_server.py
# 输出: host="127.0.0.1"
```

### Key 流经路径

```
环境变量 DEEPSEEK_API_KEY  ->  os.environ.get()  ->  Authorization Header  ->  api.deepseek.com
```

全程 Key 不写入磁盘，不发第三方，不出日志。

### 风险边界

| 风险 | 等级 | 说明 |
|---|---|---|
| 本地恶意软件读环境变量 | 低 | 操作系统层面的事，和本项目无关 |
| 端口被局域网扫描 | 低 | 默认 127.0.0.1，不绑外网 IP |
| 日志泄露 | 极低 | 不记对话正文和 Key |
| 供应链攻击 | 极低 | 三个依赖都是 PyPI 顶级包 |

### 生产环境部署建议

```bash
# 用 systemd 管理，别用 nohup
# 通过 systemd EnvironmentFile 注入 Key，别写 ~/.bashrc
chmod 600 proxy.log
```

---

## 获取 DeepSeek API Key

### 零基础版

没在 DeepSeek 注册过的，跟着做。

**第一步：注册**

1. 浏览器打开 [platform.deepseek.com](https://platform.deepseek.com/)
2. 右上角点「登录 / 注册」
3. 手机号注册或者微信扫码都行

注意：platform.deepseek.com 和 chat.deepseek.com 是两个不同的站。我们用的是 platform，开发者平台，只有这里能拿 API Key。

**第二步：充值**

新账号没余额，得先充值才能调 API。门槛不高，几块钱就行。

1. 左侧菜单点「充值」或顶部「费用中心」
2. 输入金额。建议第一次充 10-20 块，自己用能撑很久
3. 微信或支付宝扫码付款

价格参考：deepseek-chat（V4-Pro）输入 2 元/百万 token，输出 8 元/百万 token。普通编程对话一次消耗几千到几万 token。

**第三步：创建 API Key**

1. 左侧菜单点「API Keys」
2. 点「创建 API Key」
3. 弹出来的窗口里那串 `sk-` 开头的东西就是你的 Key
4. 立刻复制保存。窗口关了就再也看不到了，只能删掉重建

Key 相当于密码，别发群里，别截图给别人。别人拿到就能用你的账户调 API，花你的余额。

### 专业版

1. 打开 [platform.deepseek.com](https://platform.deepseek.com/) 注册/登录
2. 充值页面充任意金额（建议 10+），扫码付款
3. API Keys 页面创建 Key，复制 `sk-` 开头的密钥

### 计费参考

| 模型 | 输入价格 | 输出价格 | 上下文窗口 |
|---|---|---|---|
| deepseek-chat (V4-Pro) | 2 元/百万 token | 8 元/百万 token | 1M token |
| deepseek-reasoner (R1) | 4 元/百万 token | 16 元/百万 token | 64K token |

1 百万 token 大概相当于三四本《三体》第一部的字数。

### 费用估算

| 使用量 | 月花费 |
|---|---|
| 偶尔用，每天问几个问题 | 5-10 元 |
| 高频，每天写不少代码 | 15-30 元 |
| 重度，全天开着干活 | 50-100 元 |

没有月费，没有最低消费，余额永久有效，用多少扣多少。

---

## 零基础教程

没碰过终端和命令行的，从这里开始。

### 准备工作

#### 什么是终端

终端就是你和电脑打字交流的地方。VS Code 里按 `` Ctrl+` ``（ESC 下面那个键），底部弹出来的窗口就是。

你会看到类似 `user@computer:~$` 的东西，光标在 `$` 后面闪，等着你输入。

#### 确认有 Python

在终端里输入：

```bash
python3 --version
```

应该看到 `Python 3.10.12` 或类似的东西。数字低于 3.10 的话去 [python.org](https://www.python.org/downloads/) 下载安装。

上面的 `bash` 只是标记「这是终端命令」，不用打这三个字母。只输入 `python3 --version` 然后回车。

#### 下载项目

一行一行来，每行输完回车，等跑完再输下一行：

```bash
cd ~
```

`cd` = 去某个地方，`~` = 你的个人文件夹。

```bash
git clone https://github.com/Tensor-0/roocode-plus.git
```

从 GitHub 把代码复制到电脑上。如果提示 `git: command not found`，看[故障排除](#故障排除)里的第一条。

```bash
cd roocode-plus
```

进入刚下载的文件夹。

#### 创建虚拟环境

虚拟环境是给这个项目划的独立空间，里面装的东西不影响电脑上其他程序。

```bash
python3 -m venv venv
```

执行完可能什么都没显示，正常的。

#### 进入虚拟环境

```bash
source venv/bin/activate
```

执行后终端前面会出现 `(venv)`。Windows 用户命令不同：`venv\Scripts\activate`。

#### 安装依赖

```bash
pip install -r requirements.txt
```

会看到进度条在跑，最后出现 `Successfully installed ...` 就对了。

#### 设置 API Key

```bash
export DEEPSEEK_API_KEY="sk-你的真实密钥"
```

把 `sk-你的真实密钥` 换成你的真实 Key。Key 是在 [platform.deepseek.com](https://platform.deepseek.com/) 的 API Keys 页面拿的，拿到没有的话先看上面的[获取 API Key 章节](#获取-deepseek-api-key)。

#### 启动

```bash
./start_proxy.sh
```

正常输出：

```text
============================================
  RooCode Plus — Multi-Model Adapter
============================================
[成功] RooCode Plus 已在后台启动！PID: 12345
       监听地址: http://127.0.0.1:8000/v1/chat/completions
```

启动了。终端别关，去看 [Roo Code 配置指南](#roo-code-配置指南)。

---

## 专业用户快速上手

要求：Python >= 3.10，Linux / macOS / Windows (WSL)。

```bash
git clone https://github.com/Tensor-0/roocode-plus.git
cd roocode-plus
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export DEEPSEEK_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
./start_proxy.sh
```

想持久化 Key 的话把 export 写入 `~/.bashrc` 或 `~/.zshrc`。

---

## Roo Code 配置指南

### 打开设置

VS Code 左侧 Roo Code 面板（通常是一个机器人图标），展开后点右上角齿轮图标，进入 Provider Settings。

### 配置项

| 配置项 | 值 |
|---|---|
| API Provider | `OpenAI Compatible` |
| Base URL | `http://127.0.0.1:8000/v1` |
| API Key | 任意非空字符串（比如 `roocode-plus`） |
| Model ID | `deepseek-chat` |

### 验证

Roo Code 聊天框里发一条：

```
你好。当前使用的上下文窗口有多大？
```

正常的话你会看到模型的完整思考链输出。

### 数据流向

```
Roo Code  ---请求--->  RooCode Plus (127.0.0.1:8000)  ---修正后--->  目标模型 API
                              │
                    注入必需参数 / 补全缺失字段 / 修正消息格式 / 流式转发
```

---

## 故障排除

### 1. 提示 'git' 未找到

`git: command not found`

没装 Git。

- Windows：去 [git-scm.com](https://git-scm.com/downloads/win) 下载，一路默认选项安装。
- macOS：终端输入 `xcode-select --install`。
- Linux (Debian/Ubuntu)：`sudo apt install git -y`。

装好后重开终端，`git --version` 确认。

### 2. 提示 'python3' 未找到

`python3: command not found`

试试 `python --version`（不带 3）。如果也不行，去 [python.org](https://www.python.org/downloads/) 下载安装。Windows 安装时一定勾选「Add Python to PATH」。

装好后关掉终端重新打开。

### 3. 漏步骤了

| 漏了哪步 | 出错的命令 | 补上 |
|---|---|---|
| `cd roocode-plus` | start_proxy.sh 找不到 | `cd ~/roocode-plus` |
| `python3 -m venv venv` | source activate 失败 | 回去创建 venv |
| `source venv/bin/activate` | pip 装到了系统层 | 先执行 activate |
| `pip install ...` | 启动报缺少模块 | 先 pip install |

### 4. 看错命令了

常见错误：

- 把 `roocode-plus` 打成 `roocode_plus`
- 把 `DEEPSEEK_API_KEY` 打成 `DEEPSEEK_APIKEY`
- 把 `sk-` 密钥里的 `I`（大写 i）看成 `l`（小写 L）或 `1`（数字 1）
- 把 `./start_proxy.sh` 打成 `./start proxy.sh`（加了空格）

出错了把你的命令和教程里逐个字符对比。

### 5. 网络问题

`pip install` 时出现 `Connection timeout` 或 `Network is unreachable`。

开了代理但代理有问题：

```bash
unset http_proxy https_proxy all_proxy
pip install -r requirements.txt
```

在国内没开代理：

```bash
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple -r requirements.txt
```

### 6. Roo Code 连不上代理

逐项查：

```
[1] 代理还在运行吗？
    ps aux | grep proxy_server
    没输出就是挂了，重新 ./start_proxy.sh

[2] Base URL 对吗？
    http://127.0.0.1:8000/v1
    不是 https，不是 localhost，就是 127.0.0.1

[3] 防火墙拦了？
    Windows 首次启动时如果弹防火墙提示，要点「允许」

[4] 代理端报错了？
    tail -20 proxy.log
```

### 7. API 返回 401

`[API 报错] 状态码: 401`

Key 没设对。

```bash
echo $DEEPSEEK_API_KEY
# 如果是空的或"你的真实API_KEY写在这里"，重新设：
export DEEPSEEK_API_KEY="sk-你的真实密钥"
# 然后重启代理
kill $(ps aux | grep proxy_server | grep -v grep | awk '{print $2}')
./start_proxy.sh
```

检查 Key 里是不是混了空格。

### 8. API 返回 400

`[API 报错] 状态码: 400`

- Roo Code 里的 Model ID 必须填 `deepseek-chat`，不是别的
- Base URL 必须是 `http://127.0.0.1:8000/v1`，末尾不要再加路径
- Roo Code 侧的 API Key 随便填个非空字符串就行

### 9. 电脑关机后连不上了

代理进程关机就没了，export 设置的 Key 也丢了。

重启后：

```bash
cd ~/roocode-plus
source venv/bin/activate
export DEEPSEEK_API_KEY="sk-你的真实密钥"
./start_proxy.sh
```

不想每次重设 Key：

```bash
echo 'export DEEPSEEK_API_KEY="sk-你的真实密钥"' >> ~/.bashrc
source ~/.bashrc
```

### 10. 端口被占用

`OSError: [Errno 98] Address already in use`

```bash
# 杀掉占用 8000 端口的进程
kill $(lsof -t -i:8000) 2>/dev/null
./start_proxy.sh

# 或者换端口：改 proxy_server.py 最后一行的 port=8000，
# Roo Code 的 Base URL 跟着改
```

### 11. Permission Denied

`bash: ./start_proxy.sh: Permission denied`

```bash
chmod +x start_proxy.sh
```

### 12. 虚拟环境找不到

启动脚本提示 `[错误] 未检测到 Python 虚拟环境`

```bash
cd ~/roocode-plus
ls venv/bin/activate      # 确认文件在不在
python3 -m venv venv      # 不在就创建
source venv/bin/activate
pip install -r requirements.txt
```

### 13. DNS 解析失败

`[API 报错] ... Name or service not known`

先确认网是不是通的：

```bash
curl -I https://api.deepseek.com
```

如果不通，检查代理设置（参考故障 5）。在国内没开代理的话 DeepSeek API 可能被墙。

### 14. Roo Code 找不到配置项

Roo Code 版本太旧或者界面布局有差异。先更新 VS Code 和 Roo Code 扩展。核心原则不变：找 Provider 设置 -> 选 OpenAI Compatible -> 填 Base URL 和 Model ID。

### 15. 配置完 Roo Code 没反应

发消息后没输出也没报错。

```bash
tail -f ~/roocode-plus/proxy.log
# 再发一条消息，看日志有没有新输出
# 没有 = Roo Code 根本没连到代理
```

检查：
- API Provider 是不是 `OpenAI Compatible`
- Base URL 是不是 `http://127.0.0.1:8000/v1`
- URL 前有没有多打空格
- Roo Code 有没有选错 Profile

---

## 项目结构

```
roocode-plus/
├── proxy_server.py     # 适配核心
├── start_proxy.sh      # 启动脚本
├── requirements.txt    # Python 依赖声明
├── .gitignore
├── .clinerules
└── README.md
```

---

## 贡献新模型适配器

`proxy_server.py` 的 `apply_model_patches()` 函数设计为可扩展的。适配器通过 `CURRENT_MODEL_PREFIX` 常量匹配模型名，仅对目标模型注入参数。

加新适配只需三步：

1. 在 `apply_model_patches()` 中添加模型检测分支
2. 更新 `TARGET_URL` 指向新模型的 API 端点
3. 设置对应的环境变量读取新模型的 API Key

示例：添加 Claude 适配

```python
# 1. 修改 CURRENT_MODEL_PREFIX（或改为运行时判断）
CURRENT_MODEL_PREFIX = "claude"  # 或同时支持多个前缀

# 2. 在 apply_model_patches() 中添加分支
def apply_model_patches(body: dict) -> dict:
    model = body.get("model", "")

    if "deepseek" in model.lower():
        body.setdefault("thinking", {"type": "enabled"})
        body.setdefault("reasoning_effort", "high")

    elif "claude" in model.lower():
        body["anthropic_version"] = "2023-06-01"
        body.setdefault("max_tokens", 4096)

    elif "gemini" in model.lower():
        body.setdefault("safety_settings", [])

    # ... 通用修复逻辑 ...
    return body

# 3. 更新 TARGET_URL 和 API_KEY
TARGET_URL = "https://api.anthropic.com/v1/messages"
API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
```

更多模型支持计划见上方[适配路线图](#适配路线图)。

---

## License

MIT License

---

如果这个项目解决了你的问题，给个 Star。
