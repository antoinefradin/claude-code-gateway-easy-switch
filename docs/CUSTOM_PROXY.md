# Custom Proxy Setup

`ccgs` works with any HTTP proxy that speaks the Anthropic API format. This guide covers OpenRouter, generic proxies, and compatibility requirements.

---

## Compatibility Requirements

For full ccgs functionality, your proxy should implement:

| Endpoint | Required for |
|---|---|
| `GET /v1/models` | `ccgs models list` |
| `POST /v1/messages` | Claude Code API calls |

The `/v1/models` endpoint should return OpenAI-format JSON:
```json
{
  "data": [
    {"id": "claude-sonnet-4-6", "max_input_tokens": 200000, "max_output_tokens": 8192},
    ...
  ]
}
```

If your proxy doesn't support `/v1/models`, you can still use `ccgs proxy <name>` for switching — only `ccgs models list` will fail.

---

## OpenRouter

[OpenRouter](https://openrouter.ai) is a cloud gateway that provides access to many models via a unified API.

```bash
# 1. Get your API key from https://openrouter.ai/keys
# 2. Add the proxy
ccgs add openrouter https://openrouter.ai/api sk-or-v1-yourkey

# 3. Set Claude model alias (OpenRouter uses provider/model format)
ccgs config
# Set: CCGS_PROXY_OPENROUTER_MODEL="anthropic/claude-sonnet-4-5"

# 4. Switch
ccgs proxy openrouter
ccgs models list openrouter   # shows all OpenRouter models
```

**Note:** OpenRouter model IDs use `provider/model` format (e.g. `anthropic/claude-sonnet-4-5`). Set `CCGS_PROXY_OPENROUTER_MODEL` in your config if Claude Code should use a specific model by default.

---

## Generic OpenAI-Compatible Proxy

Any proxy that implements the Anthropic messages API works:

```bash
# Example: a self-hosted proxy at my-company.com
ccgs add myproxy https://llm-proxy.my-company.com sk-internal-key

# Or with a custom path:
ccgs add myproxy https://api.my-company.com/anthropic sk-key
```

**Testing a new proxy before switching:**

```bash
# 1. List models (checks /v1/models endpoint)
ccgs models list myproxy

# 2. If that works, switch
ccgs proxy myproxy
```

---

## Keyless (Open) Proxies

Some proxies run without authentication (internal corporate proxies, local development):

```bash
ccgs add localproxy http://proxy.internal:8080
# No key argument = no Authorization header sent
```

Verify:
```bash
ccgs models list localproxy
```

---

## AWS Bedrock via LiteLLM

LiteLLM can front AWS Bedrock, letting Claude Code use your AWS account's Claude models:

```yaml
# litellm_config.yaml
model_list:
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: us-east-1
```

```bash
# Assumes AWS credentials in env or ~/.aws/credentials
litellm --config litellm_config.yaml --port 4000
ccgs add bedrock http://localhost:4000
ccgs proxy bedrock
```

---

## Azure OpenAI via LiteLLM

```yaml
# litellm_config.yaml
model_list:
  - model_name: claude-sonnet-4-6
    litellm_params:
      model: azure/my-claude-deployment
      api_base: https://my-instance.openai.azure.com
      api_key: os.environ/AZURE_API_KEY
      api_version: "2024-06-01"
```

---

## Ollama (Local Models)

Ollama doesn't support the Anthropic messages format natively, but LiteLLM can bridge it:

```yaml
# litellm_config.yaml
model_list:
  - model_name: llama3
    litellm_params:
      model: ollama/llama3
      api_base: http://localhost:11434
```

Note: Ollama models don't support Claude-specific features. Expect degraded Claude Code functionality.

---

## Multiple Proxies Workflow

```bash
# Set up all proxies
ccgs add litellm      http://localhost:4000      sk-local
ccgs add openrouter   https://openrouter.ai/api  sk-or-v1-...
ccgs add bedrock-gw   http://localhost:4001      sk-bedrock

# See all configured proxies
ccgs list

# Switch between them quickly
ccgs proxy litellm
ccgs proxy openrouter
ccgs native
```

---

## Proxy Doesn't Support `/v1/models`?

If `ccgs models list` returns an error but the proxy works for actual Claude Code API calls, that's fine — the model list is purely informational.

You can still use all other ccgs commands normally. Just note the proxy's supported models from its documentation.
