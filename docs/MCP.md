# MCP & claude.ai Connectors with a Gateway

The model provider and MCP servers are **two independent systems** — with one specific exception. Switching Claude Code to a gateway with `ccgs` disables **claude.ai connectors**, but it does **not** disable MCP. This guide explains why, and how to keep full MCP while running on LiteLLM (or any other gateway).

> **What is claude.ai?** [claude.ai](https://claude.ai) is Anthropic's web app and subscription (Pro, Max, Team, Enterprise) — where you chat with Claude in the browser and manage your **connectors**. Signing into Claude Code with that account uses your subscription to pay for requests. That's a different path from the API/gateway one `ccgs` configures, where an `ANTHROPIC_*` credential bills per token instead. "claude.ai subscription login" and "claude.ai connectors" below both refer to this account.

---

## The bottom line

The connectors warning you see after `ccgs proxy <name>` is telling you the truth, and it's not fixable while keeping your gateway. But it only affects **claude.ai connectors** (cloud-managed MCP servers), not MCP in general.

You keep LiteLLM and get full MCP by adding servers **locally** instead.

---

## Why claude.ai connectors and a gateway are mutually exclusive

claude.ai connectors are fetched **only** when your active auth method is a claude.ai subscription login. From the Claude Code docs:

> Connectors from claude.ai are fetched only when your active authentication method is a claude.ai subscription login. They aren't loaded when `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `apiKeyHelper`, or a third-party provider such as Amazon Bedrock or Google Cloud's Agent Platform is active, even if you previously ran `/login`.

Pointing Claude Code at LiteLLM requires setting a **credential variable** — `ccgs proxy <name>` writes `ANTHROPIC_AUTH_TOKEN` into `~/.claude/settings.json`. That credential takes precedence over the claude.ai login → connectors are disabled. There is no way to have both at once. This is **by design**: connectors live in your claude.ai account and are keyed to that identity.

> **Note on `ANTHROPIC_BASE_URL` alone.** Setting only `ANTHROPIC_BASE_URL` *without* a credential doesn't disable the login — but then LiteLLM isn't actually authenticating you; your claude.ai subscription is still the billed credential. That's not really "using LiteLLM as the provider."

---

## The solution: keep the gateway, add MCP servers locally

MCP servers you add via `claude mcp add` are **completely independent** of the model provider. They behave exactly the same whether you're on LiteLLM, Bedrock, or claude.ai. Anything available as a claude.ai connector (Notion, Sentry, GitHub, Asana, Jira, etc.) is a plain remote MCP server you can add directly.

### 1. Keep your LiteLLM config

Store it in `~/.claude/settings.json` so it persists — this is exactly the `env` block `ccgs proxy` writes:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://litellm.my-company.com",
    "ANTHROPIC_AUTH_TOKEN": "sk-your-litellm-key"
  }
}
```

Use `ANTHROPIC_AUTH_TOKEN` if LiteLLM expects an `Authorization: Bearer` header; use `ANTHROPIC_API_KEY` if it expects `x-api-key`. LiteLLM's virtual keys typically go in the `Authorization` header → `ANTHROPIC_AUTH_TOKEN`. Run `ccgs status` (or `/status` inside Claude Code) to confirm which credential is active.

### 2. Add MCP servers directly

**Remote HTTP server** (recommended for cloud services):

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

**With an auth header:**

```bash
claude mcp add --transport http github https://api.githubcopilot.com/mcp/ \
  --header "Authorization: Bearer YOUR_GITHUB_PAT"
```

**OAuth server** (add, then authenticate in-session):

```bash
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```
```text
# then inside Claude Code:
/mcp        # opens a browser to log in
```

**Jira / Confluence** (Atlassian's remote MCP server — OAuth over HTTP):

```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp/authv2
```

See [Example: connect Jira / Confluence](#example-connect-jira--confluence) below for the full add → authenticate → use walkthrough.

> **Prefer HTTP over SSE.** The SSE (Server-Sent Events) transport is deprecated — use `--transport http` instead, where the server offers an HTTP endpoint. All the examples above use HTTP.

**Local stdio server** (note the `--` separating Claude's flags from the server command):

```bash
claude mcp add --env API_KEY=xxx --transport stdio db \
  -- npx -y some-mcp-server
```

Everything after `--` is passed to the server untouched.

### 3. Choose a scope with `-s`

| Scope | Stored in | Visible from |
|---|---|---|
| `local` (default) | `~/.claude.json` → `projects["<cwd>"].mcpServers` | Only Claude sessions started in **that one project directory** |
| `project` | committed `.mcp.json` in the repo | Everyone who clones the repo (and you, in that repo) |
| `user` | `~/.claude.json` → top-level `mcpServers` | **Every** project / terminal / session on your machine |

#### `local` means one project, not one machine

This is the most common source of confusion. `local` (the default) does **not** mean "installed on this computer" — it means **the current working directory only**. The server is filed under that project's path in `~/.claude.json`, so a Claude Code session started anywhere else can't see it. Use `user` scope for a server you want in **all** your terminals and sessions.

**Symptom of the local-scope trap:** one terminal shows the server healthy…

```text
Manage MCP servers
  1 server
    Local MCPs (/Users/you/.claude.json [project: /Users/you/dev/your-project])
  ❯ atlassian · ✔ connected · 40 tools
```

…while a terminal opened in a *different* directory reports:

```text
No MCP servers configured. Run claude doctor if this is unexpected…
```

Nothing is broken — the server is simply scoped to one project. The tell is in the `/mcp` header: `Local MCPs (… [project: /…/your-project])` names the single directory it's bound to.

#### Share a server across all terminals (user scope)

Add it with `-s user` in the first place:

```bash
claude mcp add --transport http notion https://mcp.notion.com/mcp -s user
```

Or promote a server you already added at `local` scope by removing and re-adding it at `user` scope:

```bash
claude mcp remove atlassian                 # drop the project-scoped entry
claude mcp add --transport http atlassian \
  https://mcp.atlassian.com/v1/mcp/authv2 -s user   # re-add for all projects
```

An OAuth server re-added this way needs one re-authentication — run `/mcp` inside Claude Code or `claude mcp login atlassian` from your shell.

### 4. Manage your servers

Once configured, manage your MCP servers with these commands:

```bash
# List all configured servers
claude mcp list

# Get details for a specific server
claude mcp get atlassian

# Remove a server
claude mcp remove atlassian

# Authenticate an OAuth server from your shell (v2.1.186+)
claude mcp login atlassian

# (within Claude Code) Check server status
/mcp
```

| Command | Description |
|---|---|
| `claude mcp list` | List all configured servers |
| `claude mcp get <name>` | Show details for one server |
| `claude mcp remove <name>` | Remove a server |
| `claude mcp login <name>` | Run an OAuth server's login flow from your shell |
| `/mcp` | (in-session) Check status and complete OAuth logins |

---

## Example: connect Jira / Confluence

A full walkthrough using Atlassian's remote MCP server — the same flow applies to any OAuth server (Sentry, Notion, etc.). This works identically whether you're on native Anthropic or a LiteLLM gateway.

**1. Add the server**

```bash
claude mcp add --transport http atlassian https://mcp.atlassian.com/v1/mcp/authv2
```

**2. Check its status with `/mcp`**

Inside Claude Code, run `/mcp`. A freshly added OAuth server shows as **needs authentication**:

```text
▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔
   Manage MCP servers
   1 server

     Local MCPs (/Users/you/.claude.json [project: /Users/you/dev/your-project])
   ❯ atlassian · △ needs authentication

   https://code.claude.com/docs/en/mcp for help
   ↑/↓ to navigate · Enter to confirm · Esc to cancel
```

**3. Authenticate**

Select the server and press `Enter` to launch the Atlassian OAuth login in your browser. You can also start the flow from your shell without opening the panel:

```bash
claude mcp login atlassian
```

Once you approve, `/mcp` shows the server as `connected`.

**4. Use it**

Ask Claude to work with your tracker directly — e.g. *"Add the feature described in JIRA issue ENG-4521 and open a PR."*

---

## Caveat: MCP tool search behind a gateway

With a custom `ANTHROPIC_BASE_URL`, Claude Code disables MCP **tool search** by default, because most proxies don't forward the `tool_reference` beta blocks it needs. From the docs:

> Tool search is enabled by default … It is also disabled when `ANTHROPIC_BASE_URL` points to a non-first-party host, since most proxies don't forward `tool_reference` blocks.

**Practical effect:** all MCP tool schemas load upfront into context (fine for a few servers; heavier with many). If your LiteLLM proxy *does* forward the beta header and you're on Sonnet 4.5 / Haiku 4.5 / Opus 4.5 or later, you can force it back on:

```bash
ENABLE_TOOL_SEARCH=true claude
```

If the proxy doesn't forward the header, leave it at the default (off).

> **ccgs-specific gotcha.** Setting `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1` keeps tool search off, and `ENABLE_TOOL_SEARCH` **can't** override it — that flag strips the beta header tool search depends on. This variable appears in some ccgs `settings.json` examples, so remove it if you want to force tool search on.

---

## Summary

| Goal | Works with LiteLLM? |
|---|---|
| LiteLLM as model provider | ✅ set `ANTHROPIC_BASE_URL` + credential var |
| claude.ai connectors (cloud-managed) | ❌ requires claude.ai login as active auth |
| MCP servers via `claude mcp add` | ✅ fully independent of provider |
| MCP tool search | ⚠️ off by default behind a custom base URL |

So: you don't lose MCP by using LiteLLM — you just add the same servers locally instead of provisioning them in claude.ai.

---

## Silence the connectors warning

To stop Claude Code loading claude.ai MCP servers (and silence the warning) entirely, set `disableClaudeAiConnectors` to `true` in any settings scope:

```json
{
  "disableClaudeAiConnectors": true
}
```

---

## Sources

- [Connect Claude Code to tools via MCP](https://code.claude.com/docs/en/mcp)
- [Connect Claude Code to an LLM gateway](https://code.claude.com/docs/en/llm-gateway-connect)
- [Other LLM gateways](https://code.claude.com/docs/en/llm-gateway)
