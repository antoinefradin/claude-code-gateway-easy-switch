# LiteLLM Setup Guide

This guide covers setting up a local or remote LiteLLM proxy and connecting it to Claude Code via `ccgs`.

---

## What is LiteLLM?

[LiteLLM](https://github.com/BerriAI/litellm) is an open-source proxy that provides a unified API over 100+ LLM providers. For Claude Code, it acts as a translation layer: Claude Code sends Anthropic-format requests to LiteLLM, and LiteLLM routes them to whichever backend you configure (Anthropic, Bedrock, Azure, OpenAI, Ollama, etc.).

**Why use LiteLLM with Claude Code?**
- Route Claude Code through AWS Bedrock or Azure (enterprise compliance)
- Use alternative/cheaper models while keeping the Claude Code interface
- Add request logging, rate limiting, cost tracking
- Pool API keys across a team with virtual keys

---

## Local Setup (Development)

### 1. Install LiteLLM

```bash
pip install litellm
# or with extras:
pip install 'litellm[proxy]'
```

### 2. Start with a single model (no config file)

The simplest way to verify the integration:

```bash
export ANTHROPIC_API_KEY=sk-ant-yourkey
litellm --model anthropic/claude-sonnet-4-6 --port 4000
```

Then in another terminal:

```bash
ccgs add litellm https://litellm.my-company.com
ccgs proxy litellm
ccgs models list litellm
claude  # should work via proxy
```

### 3. Config file (recommended for multiple models)

Create `litellm_config.yaml`:

```yaml
model_list:
  - model_name: claude-sonnet-4-6        # alias used by Claude Code
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-opus-4-8
    litellm_params:
      model: anthropic/claude-opus-4-8
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-haiku-4-5
    litellm_params:
      model: anthropic/claude-haiku-4-5-20251001
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: claude-sonnet-5
    litellm_params:
      model: anthropic/claude-sonnet-5
      api_key: os.environ/ANTHROPIC_API_KEY

general_settings:
  master_key: sk-mymaster  # optional: require auth for requests
```

Start:

```bash
export ANTHROPIC_API_KEY=sk-ant-yourkey
litellm --config litellm_config.yaml --port 4000
```

Connect ccgs:

```bash
ccgs add litellm https://litellm.my-company.com sk-mymaster
ccgs proxy litellm
ccgs models list litellm
```

---

## Docker Compose Deployment

For a persistent proxy (shared team use or always-on local):

```yaml
# docker-compose.yml
version: "3.8"

services:
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    ports:
      - "4000:4000"
    volumes:
      - ./litellm_config.yaml:/app/config.yaml:ro
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY:-sk-mymaster}
    command: ["--config", "/app/config.yaml", "--port", "4000", "--num_workers", "4"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
```

```bash
export ANTHROPIC_API_KEY=sk-ant-...
export LITELLM_MASTER_KEY=sk-mymaster
docker compose up -d
ccgs add litellm https://litellm.my-company.com sk-mymaster
ccgs proxy litellm
```

---

## Authentication Options

### Open proxy (no key required)

If you don't set a `master_key` in LiteLLM config, the proxy is open:

```bash
ccgs add litellm https://litellm.my-company.com   # no key argument
```

### With master key

```bash
ccgs add litellm https://litellm.my-company.com sk-mymaster
```

### Virtual keys (team use)

LiteLLM supports per-user virtual keys with budget limits. Create them via the LiteLLM UI or API, then:

```bash
ccgs add litellm https://litellm.my-company.com sk-virtual-key-for-alice
```

---

## Verify the Integration

```bash
# 1. Check proxy is running
curl https://litellm.my-company.com/health

# 2. List available models
ccgs models list litellm

# 3. Switch Claude Code to use the proxy
ccgs proxy litellm

# 4. Restart Claude Code, then test
claude "Hello, what model are you?"

# 5. Check status
ccgs status
```

---

## Setting a Default Model

If your proxy exposes multiple models and you want Claude Code to use a specific one, pick it interactively:

```bash
ccgs models set litellm
```

This fetches the live model list from `litellm`'s `/v1/models` endpoint and lets you choose with the arrow keys (↑/↓ or j/k, Enter to confirm, q/Esc to cancel). If `litellm` is the active proxy, the choice is written straight to `settings.json` — no need to re-run `ccgs proxy litellm`.

To clear a previously-set default (falls back to Claude Code's own default), select `(clear default — use Claude Code's default)` from the same menu.

You can still set it manually by editing `CCGS_PROXY_LITELLM_MODEL` via `ccgs config` if you prefer.

---

## Troubleshooting LiteLLM

**`ccgs models list` shows empty list**
LiteLLM started but no models are configured in your config.yaml. Add at least one `model_list` entry.

**HTTP 401 from models endpoint**
Your master key is wrong or not set. Check `LITELLM_MASTER_KEY` in your compose file matches what you passed to `ccgs add`.

**Claude Code connects but fails with model errors**
The model alias in your config.yaml doesn't match what Claude Code requests. Check the model names in your `litellm_config.yaml`.

**Port already in use**
Another process is on port 4000. Change the port: `litellm --port 4001` and update: `ccgs add litellm http://localhost:4001 ...`

**Proxy running but Claude Code still uses Anthropic**
Claude Code reads settings.json at startup. After `ccgs proxy litellm`, restart Claude Code (close and reopen, or restart the VS Code extension).
