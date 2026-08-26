# 现有两个账号的主流模型与参数传递

本文记录当前 CLIProxyAPI 部署中两个账号渠道的主流模型和参数传递方式：

- Codex Pro OAuth 账号
- Google Vertex AI 服务账号，区域为 `global`

本文不记录账号邮箱、Google Cloud 项目 ID、OAuth Token、服务账号私钥或 CLIProxyAPI 的实际 API Key。

## 1. API 地址

本地：

```text
http://127.0.0.1:8317/v1
```

云服务器：

```text
https://www.xfzh.online/v1
```

建议通过环境变量保存调用信息：

```bash
export OPENAI_BASE_URL="http://127.0.0.1:8317/v1"
export OPENAI_API_KEY="替换为 config.yaml 中配置的调用密钥"
```

调用云服务器时只需替换 Base URL：

```bash
export OPENAI_BASE_URL="https://www.xfzh.online/v1"
```

查看当前实例实际提供的模型：

```bash
curl "${OPENAI_BASE_URL}/models" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}"
```

模型注册表可能随程序更新，因此 `/v1/models` 的实时结果应作为最终依据。

## 2. 模型路由

请求体中的 `model` 同时负责选择模型和账号渠道。

| 模型写法 | 目标账号 |
|---|---|
| `gpt-5.6-sol` | Codex Pro |
| `gpt-5.4` | Codex Pro |
| `vertex/gemini-2.5-pro` | Vertex AI |
| `vertex/gemini-3.1-pro` | Vertex AI |

Vertex 账号配置了 `vertex` 前缀。调用 Vertex 时建议始终使用 `vertex/模型名`，避免与其他 Gemini 渠道混淆。

## 3. Codex Pro 主流模型

| 模型 | 建议用途 | 支持的思考强度 |
|---|---|---|
| `gpt-5.6-sol` | 最复杂的编码、研究和综合任务 | `low`、`medium`、`high`、`xhigh`、`max` |
| `gpt-5.6-terra` | 日常编码与质量、速度均衡 | `low`、`medium`、`high`、`xhigh`、`max` |
| `gpt-5.6-luna` | 快速、批量和成本敏感任务 | `low`、`medium`、`high`、`xhigh`、`max` |
| `gpt-5.5` | 复杂编码与通用工作 | `low`、`medium`、`high`、`xhigh` |
| `gpt-5.4` | 稳定的通用 Codex 模型 | `low`、`medium`、`high`、`xhigh` |
| `gpt-5.4-mini` | 快速、轻量、高频请求 | `low`、`medium`、`high`、`xhigh` |
| `gpt-5.3-codex-spark` | 低延迟编码任务 | `low`、`medium`、`high`、`xhigh` |

### 3.1 Responses API

Codex 推荐使用 `/v1/responses`。思考强度使用嵌套字段 `reasoning.effort`：

```bash
curl "${OPENAI_BASE_URL}/responses" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.6-terra",
    "instructions": "你是一名资深 Go 工程师，优先指出正确性和并发问题。",
    "input": "分析给定代码并给出修改方案。",
    "reasoning": {
      "effort": "high"
    }
  }'
```

常用字段：

| 字段 | 含义 |
|---|---|
| `model` | 模型 ID |
| `instructions` | 系统级指令 |
| `input` | 字符串或 Responses API 输入数组 |
| `reasoning.effort` | 思考强度 |
| `tools` | 函数工具或受支持的内置工具 |
| `tool_choice` | 工具选择策略 |
| `stream` | 客户端是否接收流式响应 |

### 3.2 Chat Completions API

兼容 OpenAI Chat Completions 的客户端可以调用 `/v1/chat/completions`，思考强度使用顶层字段 `reasoning_effort`：

```bash
curl "${OPENAI_BASE_URL}/chat/completions" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5.6-sol",
    "messages": [
      {
        "role": "system",
        "content": "你是一名资深软件架构师。"
      },
      {
        "role": "user",
        "content": "分析这个服务的架构风险。"
      }
    ],
    "reasoning_effort": "xhigh",
    "stream": false
  }'
```

项目会把 `reasoning_effort` 转换为 Codex 上游的：

```json
{
  "reasoning": {
    "effort": "xhigh"
  }
}
```

当前 Chat Completions 转换器在没有传入 `reasoning_effort` 时默认使用 `medium`。若调用方需要稳定、可预测的行为，建议总是显式传值。

### 3.3 Codex 工具调用

```json
{
  "model": "gpt-5.6-sol",
  "input": "查询订单 1001 的状态",
  "reasoning": {
    "effort": "medium"
  },
  "tools": [
    {
      "type": "function",
      "name": "get_order",
      "description": "根据订单号查询订单",
      "parameters": {
        "type": "object",
        "properties": {
          "order_id": {
            "type": "string"
          }
        },
        "required": ["order_id"],
        "additionalProperties": false
      }
    }
  ],
  "tool_choice": "auto"
}
```

### 3.4 Codex 不生效的参数

Codex 渠道会在转发前删除以下参数：

```text
temperature
top_p
max_tokens
max_completion_tokens
max_output_tokens
```

因此不要依赖这些字段控制 Codex。应主要通过以下方式控制结果：

- `instructions`
- 用户提示词
- `reasoning.effort`
- `tools` 和 `tool_choice`
- 结构化输出或调用方自己的结果校验

## 4. Vertex AI 主流模型

| 模型 | 建议用途 | 原生思考能力 |
|---|---|---|
| `vertex/gemini-2.5-pro` | 高质量推理、长文本与复杂任务 | 数字预算，`128` 至 `32768`，支持自动 |
| `vertex/gemini-2.5-flash` | 速度和能力均衡 | 数字预算，最高 `24576`，支持关闭和自动 |
| `vertex/gemini-2.5-flash-lite` | 低成本和高吞吐量 | 数字预算，最高 `24576`，支持关闭和自动 |
| `vertex/gemini-3-pro` | 高质量推理 | `low`、`high` |
| `vertex/gemini-3-flash` | 快速通用任务 | `minimal`、`low`、`medium`、`high` |
| `vertex/gemini-3.1-pro` | 新一代复杂任务 | `low`、`medium`、`high` |
| `vertex/gemini-3.1-flash-lite` | 新一代低成本任务 | `minimal`、`low`、`medium`、`high` |
| `vertex/gemini-3.5-flash` | 高速智能任务 | `minimal`、`low`、`medium`、`high` |

### 4.1 使用 OpenAI Chat Completions 格式

```bash
curl "${OPENAI_BASE_URL}/chat/completions" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "vertex/gemini-2.5-flash",
    "messages": [
      {
        "role": "user",
        "content": "总结这段文字并列出三条结论。"
      }
    ],
    "temperature": 0.4,
    "top_p": 0.9,
    "max_completion_tokens": 2048,
    "reasoning_effort": "medium"
  }'
```

项目会转换为 Gemini/Vertex 参数：

| OpenAI 兼容字段 | Vertex 上游字段 |
|---|---|
| `messages` | `contents` |
| `temperature` | `generationConfig.temperature` |
| `top_p` | `generationConfig.topP` |
| `top_k` | `generationConfig.topK` |
| `max_tokens` | `generationConfig.maxOutputTokens` |
| `max_completion_tokens` | `generationConfig.maxOutputTokens` |
| `n` | `generationConfig.candidateCount`，仅大于 1 时设置 |
| `reasoning_effort` | `generationConfig.thinkingConfig` |
| `tools` | Gemini function declarations 或受支持的原生工具 |

### 4.2 使用 OpenAI Responses 格式

```bash
curl "${OPENAI_BASE_URL}/responses" \
  -H "Authorization: Bearer ${OPENAI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "vertex/gemini-3.1-pro",
    "input": "比较 PostgreSQL 和 MySQL 在高并发写入场景中的差异。",
    "temperature": 0.3,
    "max_output_tokens": 4096,
    "reasoning": {
      "effort": "high"
    }
  }'
```

Responses API 使用 `reasoning.effort`，项目会把它转换成对应 Gemini 模型支持的 `thinkingLevel` 或 `thinkingBudget`。

### 4.3 Vertex 思考强度转换

调用方可以统一使用档位：

```text
none
auto
minimal
low
medium
high
xhigh
max
```

项目内部的标准档位到预算映射为：

| 档位 | 标准预算 |
|---|---:|
| `none` | `0` |
| `auto` | `-1` |
| `minimal` | `512` |
| `low` | `1024` |
| `medium` | `8192` |
| `high` | `24576` |
| `xhigh` | `32768` |
| `max` | `128000`，随后按目标模型上限限制 |

转换规则：

- Gemini 2.5 等预算型模型把档位转换成数字预算。
- Gemini 3 等档位型模型直接使用 `thinkingLevel`。
- 超过模型上限的跨协议参数会限制到模型支持范围。
- 档位型模型收到不支持的跨协议档位时，会调整到最接近的受支持档位。
- `auto` 在模型支持动态思考时传为 `-1`；不支持时转换成中间档位或中间预算。
- 请求原生 Gemini 格式时，预算越界可能直接返回参数错误。

### 4.4 直接传入 Gemini generationConfig

OpenAI Chat Completions 入口也会保留调用方提供的 `generationConfig`，因此可以精确设置 Vertex 参数：

```json
{
  "model": "vertex/gemini-2.5-pro",
  "messages": [
    {
      "role": "user",
      "content": "分析这个技术方案。"
    }
  ],
  "generationConfig": {
    "temperature": 0.2,
    "topP": 0.9,
    "maxOutputTokens": 4096,
    "thinkingConfig": {
      "thinkingBudget": 16384,
      "includeThoughts": true
    }
  }
}
```

Gemini 3 档位型模型示例：

```json
{
  "model": "vertex/gemini-3.1-pro",
  "messages": [
    {
      "role": "user",
      "content": "检查设计方案。"
    }
  ],
  "generationConfig": {
    "thinkingConfig": {
      "thinkingLevel": "high",
      "includeThoughts": true
    }
  }
}
```

不要同时传 `thinkingLevel` 和 `thinkingBudget`。项目最终会根据模型能力保留其中一种格式。

## 5. 模型后缀

两个账号渠道都支持在模型名后添加思考后缀：

```json
{
  "model": "gpt-5.6-sol(max)",
  "input": "执行复杂代码审查"
}
```

```json
{
  "model": "vertex/gemini-2.5-pro(16384)",
  "input": "执行复杂分析"
}
```

后缀支持：

```text
(none)
(auto)
(minimal)
(low)
(medium)
(high)
(xhigh)
(max)
(数字预算)
```

模型后缀的思考设置优先于请求体中的 `reasoning_effort`、`reasoning.effort` 或 `thinkingConfig`。

## 6. 参数优先级

通常按以下顺序处理：

1. 根据请求端点识别 OpenAI Chat、OpenAI Responses 或 Gemini 格式。
2. 根据 `model` 选择 Codex 或 Vertex 账号。
3. 把客户端参数转换成目标渠道格式。
4. 解析并校验思考参数。
5. 如果模型名带后缀，后缀覆盖请求体中的思考设置。
6. 应用 `config.yaml` 中的 `payload.default`、`payload.override` 和 `payload.filter`。
7. 执行渠道要求的最终规范化并请求上游。

如果 `config.yaml` 配置了匹配当前模型的 `payload.override`，它可以覆盖客户端参数和模型后缀转换后的最终字段。

## 7. Python OpenAI SDK

Responses API：

```python
import os
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["OPENAI_API_KEY"],
    base_url=os.environ["OPENAI_BASE_URL"],
)

response = client.responses.create(
    model="gpt-5.6-terra",
    instructions="你是一名资深 Go 工程师。",
    input="分析这个并发实现。",
    reasoning={"effort": "high"},
)

print(response.output_text)
```

Chat Completions：

```python
import os
from openai import OpenAI

client = OpenAI(
    api_key=os.environ["OPENAI_API_KEY"],
    base_url=os.environ["OPENAI_BASE_URL"],
)

response = client.chat.completions.create(
    model="vertex/gemini-2.5-flash",
    messages=[
        {"role": "user", "content": "总结这段内容。"},
    ],
    temperature=0.4,
    max_completion_tokens=2048,
    extra_body={"reasoning_effort": "medium"},
)

print(response.choices[0].message.content)
```

部分 OpenAI SDK 版本的 Chat Completions 类型定义没有 `reasoning_effort`，此时通过 `extra_body` 传入。

## 8. 排查顺序

请求失败时按以下顺序检查：

1. 调用 `/v1/models`，确认模型 ID 当前可见。
2. Vertex 模型使用 `vertex/` 前缀。
3. `/v1/responses` 使用 `reasoning.effort`。
4. `/v1/chat/completions` 使用 `reasoning_effort`。
5. 检查思考档位是否在目标模型支持范围内。
6. 检查 `config.yaml` 是否存在覆盖或过滤该参数的 `payload` 规则。
7. 检查账号是否处于冷却、限额或授权失效状态。

## 9. 安全约定

- 客户端只使用 `config.yaml` 中配置的 CLIProxyAPI 调用密钥。
- 不把 Codex OAuth JSON 或 Vertex 服务账号 JSON 下发给客户端。
- 不在代码、文档、日志或截图中写入真实 API Key、Refresh Token 或私钥。
- 云服务器继续通过 HTTPS 地址访问，不直接暴露后端 `8317` 端口。
