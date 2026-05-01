"""
RooCode Plus — 多模型适配核心
================================
在 Roo Code 与各类 AI 模型 API 之间建立智能适配层。
自动修正 Roo Code 发出的请求参数，确保与目标模型完全兼容。

当前适配: DeepSeek (V4-Pro)
计划适配: OpenAI, Anthropic Claude, Google Gemini, 通义千问 ...

架构: FastAPI 异步代理 → 请求拦截 → 参数注入 → 流式转发
"""

import os
import httpx
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse
import uvicorn

app = FastAPI()

# ------------------------------------------------------------
# 📋 适配器配置区（添加新模型时只需修改此区域）
# ------------------------------------------------------------
# 环境变量: 根据使用的模型选择对应的环境变量名
#   DeepSeek  → export DEEPSEEK_API_KEY="sk-xxx"
#   OpenAI    → export OPENAI_API_KEY="sk-xxx"       (计划支持)
#   Anthropic → export ANTHROPIC_API_KEY="sk-ant-xxx" (计划支持)
# ------------------------------------------------------------
API_KEY = os.environ.get("DEEPSEEK_API_KEY", "你的真实API_KEY写在这里")
TARGET_URL = "https://api.deepseek.com/chat/completions"

client = httpx.AsyncClient(timeout=httpx.Timeout(600.0), proxy=None)


# ------------------------------------------------------------
# 🔧 适配器逻辑：在这里处理每个模型的参数差异
# ------------------------------------------------------------
def apply_model_patches(body: dict) -> dict:
    """
    对请求体进行模型特定的参数修正。
    当添加新模型适配时，在此函数中增加对应的分支逻辑。
    """
    # DeepSeek 适配：注入思考参数
    body["thinking"] = {"type": "enabled"}
    body["reasoning_effort"] = "high"

    # 【通用修复】遍历上下文，补全缺失的字段
    # Roo Code 在多轮对话中可能漏掉某些模型要求的必填字段
    if "messages" in body:
        for msg in body["messages"]:
            if msg.get("role") == "assistant":
                # DeepSeek 要求 assistant 消息必须包含 reasoning_content
                if "reasoning_content" not in msg:
                    msg["reasoning_content"] = ""

    # TODO: 为其他模型添加适配逻辑
    # elif model == "claude":
    #     ... Claude 特定修正 ...
    # elif model == "gemini":
    #     ... Gemini 特定修正 ...

    return body


@app.post("/v1/chat/completions")
async def proxy_completions(request: Request):
    body = await request.json()

    print(f"\n[RooCode Plus] 收到请求，正在执行适配层修正...")
    body = apply_model_patches(body)

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }

    is_stream = body.get("stream", False)

    async def stream_generator():
        async with client.stream("POST", TARGET_URL, json=body, headers=headers) as response:
            if response.status_code != 200:
                error_detail = await response.aread()
                print(f"[API 报错] 状态码: {response.status_code}, 信息: {error_detail}")
                yield error_detail
                return

            print("[RooCode Plus] 开始流式转发...")
            async for chunk in response.aiter_bytes():
                yield chunk
            print("[RooCode Plus] 单次转发完成")

    if is_stream:
        return StreamingResponse(stream_generator(), media_type="text/event-stream")
    else:
        response = await client.post(TARGET_URL, json=body, headers=headers)
        return response.json()


if __name__ == "__main__":
    print("🚀 RooCode Plus 适配代理已启动！(当前适配: DeepSeek)")
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="warning")
