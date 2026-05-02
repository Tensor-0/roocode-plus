"""
RooCode Plus — Python 单元测试
===============================
测试 proxy_server.py 中的适配器逻辑和代理端点。
使用 pytest + pytest-httpx mock 上游 API，不依赖真实网络。
"""

import os
import json
import pytest
import httpx
from fastapi.testclient import TestClient


# ====================================================================
# setup: 设置环境变量 + 导入被测模块
# ====================================================================

os.environ["DEEPSEEK_API_KEY"] = "sk-test-mock-key"

from proxy_server import app, apply_model_patches


# ====================================================================
# apply_model_patches() — 纯函数测试（9 个）
# ====================================================================

class TestApplyModelPatches:
    """适配器参数注入 — 纯函数，无外部依赖"""

    def test_deepseek_injects_thinking_params(self):
        """DeepSeek 模型：注入 thinking + reasoning_effort"""
        body = {"model": "deepseek-chat", "messages": [{"role": "user", "content": "hi"}]}
        result = apply_model_patches(body)
        assert result["thinking"] == {"type": "enabled"}
        assert result["reasoning_effort"] == "high"

    def test_non_deepseek_does_not_inject(self):
        """非 DeepSeek 模型：不注入 thinking 参数"""
        body = {"model": "gpt-4o", "messages": [{"role": "user", "content": "hi"}]}
        result = apply_model_patches(body)
        assert "thinking" not in result
        assert "reasoning_effort" not in result

    def test_empty_model_field(self):
        """model 字段为空：不注入参数，不崩溃"""
        body = {"model": "", "messages": []}
        result = apply_model_patches(body)
        assert "thinking" not in result

    def test_missing_model_field(self):
        """model 字段不存在：不注入参数，不崩溃"""
        body = {"messages": [{"role": "user", "content": "hi"}]}
        result = apply_model_patches(body)
        assert "thinking" not in result

    def test_case_insensitive_prefix_match(self):
        """model 大小写不敏感匹配"""
        body = {"model": "DEEPSEEK-CHAT", "messages": []}
        result = apply_model_patches(body)
        assert result["thinking"] == {"type": "enabled"}

    def test_setdefault_does_not_overwrite(self):
        """已有 thinking 字段：不覆盖用户设置"""
        body = {"model": "deepseek-chat", "thinking": {"type": "disabled"}, "messages": []}
        result = apply_model_patches(body)
        assert result["thinking"] == {"type": "disabled"}

    def test_reasoning_content_filled_for_assistant(self):
        """assistant 消息缺少 reasoning_content：补空字符串"""
        body = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "user", "content": "hi"},
                {"role": "assistant", "content": "hello"},
            ],
        }
        result = apply_model_patches(body)
        assert result["messages"][1]["reasoning_content"] == ""

    def test_reasoning_content_not_overwritten(self):
        """assistant 已有 reasoning_content：不覆盖"""
        body = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "assistant", "content": "hello", "reasoning_content": "thinking..."},
            ],
        }
        result = apply_model_patches(body)
        assert result["messages"][0]["reasoning_content"] == "thinking..."

    def test_user_message_not_modified(self):
        """user 消息不添加 reasoning_content"""
        body = {"model": "deepseek-chat", "messages": [{"role": "user", "content": "hi"}]}
        result = apply_model_patches(body)
        assert "reasoning_content" not in result["messages"][0]


# ====================================================================
# proxy_completions 端点测试 — mock 上游 API（2 个）
# ====================================================================

class TestProxyEndpoints:
    """测试 API 端点的边界情况（需要 mock 上游 API）"""

    def test_non_stream_200(self, httpx_mock):
        """非流式 + 上游返回 200 → 完整转发"""
        import proxy_server as ps
        ps.client = httpx.Client(timeout=httpx.Timeout(600.0))
        try:
            httpx_mock.add_response(
                method="POST",
                url="https://api.deepseek.com/chat/completions",
                json={"choices": [{"message": {"content": "hello"}}]},
                status_code=200,
            )
            with TestClient(app) as tc:
                response = tc.post(
                    "/v1/chat/completions",
                    json={
                        "model": "deepseek-chat",
                        "messages": [{"role": "user", "content": "hi"}],
                        "stream": False,
                    },
                )
            assert response.status_code == 200
            data = response.json()
            assert data["choices"][0]["message"]["content"] == "hello"
        finally:
            ps.client = None

    def test_non_stream_upstream_error(self, httpx_mock):
        """非流式 + 上游返回 401 → 透传错误"""
        import proxy_server as ps
        ps.client = httpx.Client(timeout=httpx.Timeout(600.0))
        try:
            httpx_mock.add_response(
                method="POST",
                url="https://api.deepseek.com/chat/completions",
                json={"error": "invalid api key"},
                status_code=401,
            )
            with TestClient(app) as tc:
                response = tc.post(
                    "/v1/chat/completions",
                    json={
                        "model": "deepseek-chat",
                        "messages": [{"role": "user", "content": "hi"}],
                        "stream": False,
                    },
                )
            assert response.status_code == 401
        finally:
            ps.client = None


# ====================================================================
# 适配器回归测试（2 个）
# ====================================================================

class TestAdapterRegression:
    """确保新增模型适配不破坏现有逻辑"""

    def test_unknown_model_no_side_effects(self):
        """未知模型：不修改任何字段"""
        body = {"model": "unknown-model", "messages": [{"role": "user", "content": "test"}]}
        result = apply_model_patches(body)
        assert result["model"] == "unknown-model"
        assert result["messages"][0] == {"role": "user", "content": "test"}

    def test_no_messages_field(self):
        """没有 messages 字段：不崩溃"""
        body = {"model": "deepseek-chat"}
        result = apply_model_patches(body)
        assert "thinking" in result
        assert "messages" not in body
