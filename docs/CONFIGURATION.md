# Configuration Reference

## Config File Location

`ccgs` stores its configuration at:

```text
~/.config/ccgs/config
```

The path respects the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html). If `XDG_CONFIG_HOME` is set, ccgs uses `$XDG_CONFIG_HOME/ccgs/config` instead.

Edit the config with:
```bash
ccgs config           # opens in $EDITOR (falls back to vi)
```

---

## Config File Format

The config file is a plain bash-sourceable key=value file. Values are always double-quoted:

```bash
# ccgs configuration
CCGS_ACTIVE="native"

CCGS_PROXY_LITELLM_URL="https://litellm.my-company.com"
CCGS_PROXY_LITELLM_KEY="sk-mymaster"
CCGS_PROXY_LITELLM_MODEL="claude-sonnet-5"

CCGS_PROXY_OPENROUTER_URL="https://openrouter.ai/api"
CCGS_PROXY_OPENROUTER_KEY="sk-or-v1-mykey"
CCGS_PROXY_OPENROUTER_MODEL="anthropic/claude-sonnet-4-5"
```

---

## Variable Reference

### Core Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `CCGS_ACTIVE` | string | `"native"` | Currently active mode. `"native"` or a proxy name. Managed by ccgs — do not edit manually. |

### Per-Proxy Variables

For each proxy named `<NAME>` (uppercase, underscores), three variables are stored:

| Variable | Type | Required | Description |
|---|---|---|---|
| `CCGS_PROXY_<NAME>_URL` | string | Yes | Base URL of the proxy (must start with `http://` or `https://`) |
| `CCGS_PROXY_<NAME>_KEY` | string | No | API key / Bearer token. Empty = open proxy (no Authorization header sent) |
| `CCGS_PROXY_<NAME>_MODEL` | string | No | Default model to set via `ANTHROPIC_MODEL`. Empty = use Claude Code's default. Set interactively with `ccgs models set <name>` (recommended) or by editing this file directly via `ccgs config` |

**Proxy name rules:** lowercase, letters/digits/underscores only. Dashes in names are automatically converted to underscores. So `my-proxy` and `my_proxy` both resolve to `CCGS_PROXY_MY_PROXY_*`.

### Multiple Proxies Example

```bash
CCGS_ACTIVE="litellm"

# Company LiteLLM proxy
CCGS_PROXY_LITELLM_URL="https://litellm.my-company.com"
CCGS_PROXY_LITELLM_KEY="sk-mymaster"
CCGS_PROXY_LITELLM_MODEL="claude-sonnet-5"

# OpenRouter (cost-effective fallback)
CCGS_PROXY_OPENROUTER_URL="https://openrouter.ai/api"
CCGS_PROXY_OPENROUTER_KEY="sk-or-v1-..."
CCGS_PROXY_OPENROUTER_MODEL="anthropic/claude-sonnet-4-5"

# Internal team proxy (no auth)
CCGS_PROXY_INTERNAL_URL="http://proxy.company.internal:8080"
CCGS_PROXY_INTERNAL_KEY=""
CCGS_PROXY_INTERNAL_MODEL=""
```

---

## Environment Variable Overrides

These environment variables modify ccgs behavior at runtime:

| Variable | Description |
|---|---|
| `CLAUDE_SETTINGS` | Override path to `settings.json`. Default: `~/.claude/settings.json`. Useful for testing: `CLAUDE_SETTINGS=/tmp/test.json ccgs proxy litellm` |
| `NO_COLOR` | Set to any value to disable colored output. ccgs also respects non-interactive TTYs automatically. |
| `CCGS_SESSION_OUTPUT` | Internal. Set to `1` by the shell function to capture only eval-able export/unset lines. Do not set manually. |
| `XDG_CONFIG_HOME` | Standard XDG override for config directory. |

---

## settings.json Integration

When you run `ccgs proxy <name>`, `ccgs native`, or `ccgs models set <name>` (when `<name>` is the active proxy), ccgs reads and writes `~/.claude/settings.json`.

### How ccgs config maps to settings.json

`ccgs` keeps its own state in `~/.config/ccgs/config` (the `CCGS_*` variables) and, when you activate a proxy, projects the relevant ones into the `env` block of `~/.claude/settings.json` (the `ANTHROPIC_*` keys that Claude Code actually reads). The mapping is one-to-one:

| ccgs config variable | → settings.json `env` key | Written by | Meaning |
|---|---|---|---|
| `CCGS_PROXY_<NAME>_URL` | `ANTHROPIC_BASE_URL` | `ccgs add` sets it in config; `ccgs proxy <name>` projects it | Proxy base URL |
| `CCGS_PROXY_<NAME>_KEY` | `ANTHROPIC_AUTH_TOKEN` | `ccgs add` sets it in config; `ccgs proxy <name>` projects it | Bearer token — omitted entirely from `settings.json` when empty (open proxy) |
| `CCGS_PROXY_<NAME>_MODEL` | `ANTHROPIC_MODEL` | `ccgs models set <name>` (or manual `ccgs config`) sets it in config; `ccgs proxy <name>` projects it | Default model — omitted entirely from `settings.json` when empty (uses Claude Code's default) |
| `CCGS_ACTIVE` | *(not projected)* | `ccgs proxy` / `ccgs native` | Tracks the active mode inside ccgs only; never written to `settings.json` |

Notes:

- **`ANTHROPIC_API_KEY`** is never *set* by ccgs — it's only ever *removed* (cleared on `ccgs native`) so a stale key can't shadow the proxy token. It has no corresponding `CCGS_*` variable.
- **`ccgs models set <name>`** always updates `CCGS_PROXY_<NAME>_MODEL` in the config. If that proxy is currently active, it *also* rewrites `ANTHROPIC_MODEL` in `settings.json` immediately (or removes it, if you chose "clear default") so you don't have to re-run `ccgs proxy <name>`. If the proxy isn't active, only the config changes — the model is applied the next time you `ccgs proxy <name>`.
- **`ccgs native`** removes all four managed keys (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`) from `settings.json`, fully resetting Claude Code to your native Anthropic account.

**What ccgs touches (only):**

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "...",
    "ANTHROPIC_AUTH_TOKEN": "...",
    "ANTHROPIC_MODEL": "..."
  }
}
```

**What ccgs never touches:**

All other top-level keys (`theme`, `effortLevel`, `permissions`, `hooks`, `apiKeyHelper`, etc.) and all other `env` keys (e.g. `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`) are preserved exactly.

**Backup:** Before every write, ccgs creates a timestamped backup at `~/.claude/backups/settings_YYYYMMDD_HHMMSS.json`. The last 10 backups are kept.

### settings.json Transform Example

Before `ccgs proxy litellm`:
```json
{
  "theme": "light-ansi",
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-8",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"
  }
}
```

After `ccgs proxy litellm` (url=`https://litellm.my-company.com`, key=`sk-abc`, model=`claude-sonnet-5`):
```json
{
  "theme": "light-ansi",
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-8",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1",
    "ANTHROPIC_BASE_URL": "https://litellm.my-company.com",
    "ANTHROPIC_AUTH_TOKEN": "sk-abc",
    "ANTHROPIC_MODEL": "claude-sonnet-5"
  }
}
```

After `ccgs native`:
```json
{
  "theme": "light-ansi",
  "effortLevel": "high",
  "env": {
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-8",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-8",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS": "1"
  }
}
```

### `ccgs models set` on the active proxy

If `litellm` is already active (from the example above) and you run `ccgs models set litellm` and pick `claude-opus-4-8`, ccgs updates `CCGS_PROXY_LITELLM_MODEL="claude-opus-4-8"` in its config **and** rewrites just the one key in `settings.json`:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://litellm.my-company.com",
    "ANTHROPIC_AUTH_TOKEN": "sk-abc",
    "ANTHROPIC_MODEL": "claude-opus-4-8"
  }
}
```

Choosing "clear default — use Claude Code's default" instead sets `CCGS_PROXY_LITELLM_MODEL=""` and removes `ANTHROPIC_MODEL` from `settings.json`, leaving `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` in place.

---

### Verifying with `/status`

Running `/status` inside Claude Code shows the active configuration — useful to confirm a switch took effect without leaving the session.

**Native mode** (no proxy active):

```
Settings   Status   Config   Usage   Stats

Version:          2.1.204
Session ID:       11111111-1111-1111-1111-111111111111
cwd:              /Users/you/Documents/GITHUB/claude-code-gateway-switch
Login method:     Claude Pro account
Organization:     you@example.com's Organization
Email:            you@example.com
Model:            Default (Sonnet 5 · Efficient for routine tasks)
IDE:              Connected to VS Code extension version 2.1.204
MCP servers:      3 need auth, 1 disabled · /mcp
Setting sources:  User settings
```

**After `ccgs proxy litellm`** (illustrative — field labels vary by Claude Code version):

```
Settings   Status   Config   Usage   Stats

Version:          2.1.204
Session ID:       22222222-2222-2222-2222-222222222222
cwd:              /Users/you/Documents/GITHUB/claude-code-gateway-switch
Login method:     API key (ANTHROPIC_AUTH_TOKEN)
API Base URL:     https://litellm.my-company.com
Model:            claude-sonnet-5 (via ANTHROPIC_MODEL)
IDE:              Connected to VS Code extension version 2.1.204
MCP servers:      3 need auth, 1 disabled · /mcp
Setting sources:  User settings
```

The key thing to confirm is that Base URL and Model match your `ccgs config` — the exact "Login method"/"API Base URL" field names will vary by Claude Code version.

---

## Session Mode vs Persistent Mode

| Mode | Command | Scope | How |
|---|---|---|---|
| Persistent (default) | `ccgs proxy litellm` | All terminals, all Claude Code sessions | Writes `settings.json` |
| Session-only | `ccgs proxy litellm --session` | Current shell only | Exports env vars into current shell |

Session-only mode does **not** write `settings.json`. The exported vars (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`) take precedence over `settings.json` for any Claude Code process spawned from that shell.

---

## Resetting to Defaults

To fully reset:

```bash
ccgs native                     # clear proxy from settings.json
ccgs remove litellm             # remove proxy from config
# or to remove all proxies: manually edit: ccgs config
```

Or just run:

```bash
bash uninstall.sh               # removes binary, shell function, offers to reset settings.json
```
