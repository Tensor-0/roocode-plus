# 🔌 RooCode Plus

> 让 Roo Code 完美适配任何模型 | 当前支持 DeepSeek V4-Pro · 更多模型接入中

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python: 3.8+](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)

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

### 🗺️ 适配路线图

| 模型 | 状态 |
|---|---|
| DeepSeek (V4-Pro) | ✅ 已支持 |
| OpenAI (GPT-4o) | 🚧 计划中 |
| Anthropic (Claude) | 🚧 计划中 |
| Google (Gemini) | 📋 待评估 |

> 💡 欢迎提交 PR 贡献新模型适配器！

---

## 🚀 快速上手

### 环境要求

- **Python** ≥ 3.8
- **操作系统**: Linux / macOS / Windows (WSL)

### 1. 克隆仓库

```bash
git clone https://github.com/Tensor-0/roocode-plus.git
cd roocode-plus
```

### 2. 安装依赖

```bash
python3 -m venv venv
source venv/bin/activate
pip install fastapi httpx uvicorn
```

### 3. 配置 API Key

```bash
# DeepSeek 用户
export DEEPSEEK_API_KEY="sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 未来其他模型:
# export OPENAI_API_KEY="sk-xxx"
# export ANTHROPIC_API_KEY="sk-ant-xxx"
```

> 也可将上述命令写入 `~/.bashrc` / `~/.zshrc` 持久化。

### 4. 启动

```bash
./start_proxy.sh
```

启动成功后会显示：

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

### 步骤 2：配置提供商

| 配置项 | 值 |
|---|---|
| **API Provider** | `OpenAI Compatible` |
| **Base URL** | `http://127.0.0.1:8000/v1` |
| **API Key** | 任意非空字符串（如 `roocode-plus`） |
| **Model ID** | `deepseek-chat` |

### 步骤 3：验证

在 Roo Code 中发送一条测试消息：

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

### Q: 端口被占用？

编辑 `proxy_server.py` 最后一行的 `port=8000`，并同步更新 Roo Code 中的 Base URL。

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
