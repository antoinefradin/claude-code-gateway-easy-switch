# Configuration Reference

## Config File Location

`ccgs` stores its configuration at:

```
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
| `CCGS_PROXY_<NAME>_MODEL` | string | No | Default model to set via `ANTHROPIC_MODEL`. Empty = use Claude Code's default |

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

When you run `ccgs proxy <name>` or `ccgs native`, ccgs reads and writes `~/.claude/settings.json`.

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

---

## Session Mode vs Persistent Mode

| Mode | Command | Scope | How |
|---|---|---|---|
| Persistent (default) | `ccgs proxy litellm` | All terminals, all Claude Code sessions | Writes `settings.json` |
| Session-only | `eval "$(ccgs proxy litellm --session)"` | Current shell only | Exports env vars into current shell |

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
