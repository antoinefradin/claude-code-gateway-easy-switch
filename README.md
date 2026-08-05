# ccgs — Claude Code Gateway Easy Switch

<p align="center">
  <img src="assets/banner.png" alt="ccgs — Claude Code Gateway Easy Switch" width="800"/>
</p>

> **One command to switch Claude Code between native Anthropic and any LiteLLM / OpenAI-compatible proxy.**

![Version](https://img.shields.io/badge/version-0.2.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/bash-3.2%2B-orange)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

---

## Why

Claude Code is powerful. LiteLLM is powerful. But switching between your Anthropic subscription and a self-hosted gateway currently means manually editing `~/.claude/settings.json`. `ccgs` automates this — one command, zero settings corruption.

---

## Quick Start

**1. Install**

```bash
curl -fsSL https://raw.githubusercontent.com/antoinefradin/claude-code-gateway-easy-switch/main/quick-install.sh | bash
```

**2. Add your proxy**

```bash
ccgs add litellm https://litellm.my-company.com sk-yourkey
```
```text
[ccgs] Proxy 'litellm' configured.
  URL:  https://litellm.my-company.com
  Key:  sk-yourk...

  Switch to it:          ccgs proxy litellm
  List models:           ccgs models list litellm
  Set a default model:   ccgs models set litellm
```

**3. Switch to proxy**

```bash
ccgs proxy litellm
```
```text
[ccgs] Switched to proxy 'litellm'.
  URL:   https://litellm.my-company.com
  Key:   sk-yourk...
  Restart Claude Code to apply.
```

**4. Use Claude Code normally — it now routes through your proxy**

```bash
claude
```

**5. Switch back to native when needed**

```bash
ccgs native
```
```text
[ccgs] Switched to native Anthropic mode.
  Proxy settings cleared from settings.json.
  Restart Claude Code to apply.
```

---

## How It Works

`ccgs` writes to the `env` block in `~/.claude/settings.json` — the same mechanism Claude Code uses for environment variable injection:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://litellm.my-company.com",
    "ANTHROPIC_AUTH_TOKEN": "sk-yourkey",
    "ANTHROPIC_MODEL": "claude-sonnet-5"
  }
}
```

Only the four ccgs-managed keys (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`) are ever touched. All other settings — theme, effortLevel, permissions, hooks, and any other env vars such as `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`, `ANTHROPIC_DEFAULT_OPUS_MODEL`, `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` — pass through completely untouched.

Switching back with `ccgs native` simply removes those keys.

### What changes where

`ccgs` stores your proxies in its own config at `~/.config/ccgs/config` (the `CCGS_*` variables) and projects them into `~/.claude/settings.json` (the `ANTHROPIC_*` keys Claude Code reads) when you activate a proxy. The mapping is one-to-one:

| `~/.config/ccgs/config` | → `~/.claude/settings.json` (`env`) | Set by |
|---|---|---|
| `CCGS_PROXY_<NAME>_URL` | `ANTHROPIC_BASE_URL` | `ccgs add`, applied by `ccgs proxy <name>` |
| `CCGS_PROXY_<NAME>_KEY` | `ANTHROPIC_AUTH_TOKEN` | `ccgs add`, applied by `ccgs proxy <name>` |
| `CCGS_PROXY_<NAME>_MODEL` | `ANTHROPIC_MODEL` | **`ccgs models set <name>`** (or `ccgs config`), applied by `ccgs proxy <name>` |
| `CCGS_ACTIVE` | *(internal — never written to settings.json)* | `ccgs proxy` / `ccgs native` |

Empty `KEY` or `MODEL` values are omitted from `settings.json` entirely (open proxy / Claude Code's default model). `ANTHROPIC_API_KEY` is never set — only cleared on `ccgs native` so a stale key can't shadow the proxy token. Running `ccgs models set <name>` on the **currently active** proxy rewrites `ANTHROPIC_MODEL` in `settings.json` immediately; otherwise it just updates the config until the next `ccgs proxy <name>`. See [docs/CONFIGURATION.md](docs/CONFIGURATION.md#settingsjson-integration) for full before/after examples.

---

## Command Reference

| Command | Description |
|---|---|
| `ccgs native` | Switch to native Anthropic API |
| `ccgs proxy <name>` | Switch to a named proxy |
| `ccgs models list` | List models from the active proxy |
| `ccgs models list <name>` | List models from a specific proxy |
| `ccgs models set [name]` | Interactively pick a default model (arrow keys) |
| `ccgs add <name> <url> [key]` | Add or update a proxy (positional) |
| `ccgs add <name> --base-url <url> [--token <key>]` | Add or update a proxy (named flags) |
| `ccgs remove <name>` | Remove a proxy |
| `ccgs list` | List all configured proxies |
| `ccgs status` | Show current mode and settings.json state |
| `ccgs config` | Edit config file in `$EDITOR` |
| `ccgs help` | Show help |
| `ccgs version` | Show version |

### Examples

**Add a proxy**

```bash
ccgs add litellm https://litellm.my-company.com sk-mykey
# or with named flags:
ccgs add litellm --base-url https://litellm.my-company.com --token sk-mykey
```
```text
[ccgs] Proxy 'litellm' configured.
  URL:  https://litellm.my-company.com
  Key:  sk-mykey...

  Switch to it:          ccgs proxy litellm
  List models:           ccgs models list litellm
  Set a default model:   ccgs models set litellm
```

```bash
ccgs add openrouter https://openrouter.ai/api sk-or-v1-mykey
ccgs add internal http://proxy.internal:8080  # no auth key
```

**Switch**

```bash
ccgs proxy litellm
```
```text
[ccgs] Switched to proxy 'litellm'.
  URL:   https://litellm.my-company.com
  Key:   sk-mykey...
  Restart Claude Code to apply.
```

```bash
ccgs native
```
```text
[ccgs] Switched to native Anthropic mode.
  Proxy settings cleared from settings.json.
  Restart Claude Code to apply.
```

**Inspect**

```bash
ccgs list
```
```text
Configured proxies:

  litellm                 https://litellm.my-company.com  [ACTIVE]
    key:   sk-mykey...
  openrouter              https://openrouter.ai/api

  Active mode: litellm

  Switch:  ccgs native  |  ccgs proxy <name>
```

```bash
ccgs status
```
```text
ccgs status

  Active mode:             litellm
  Proxy URL:               https://litellm.my-company.com
  Auth key:                sk-mykey...

  Config file:             ~/.config/ccgs/config
  settings.json:           ~/.claude/settings.json

  Current settings.json env block:
    ANTHROPIC_BASE_URL                     https://litellm.my-company.com
    ANTHROPIC_AUTH_TOKEN                   sk-mykey...
    ANTHROPIC_DEFAULT_SONNET_MODEL         claude-sonnet-5
    ANTHROPIC_DEFAULT_HAIKU_MODEL          claude-haiku-4-8
    ANTHROPIC_DEFAULT_OPUS_MODEL           claude-opus-4-8
    ANTHROPIC_MODEL                        claude-sonnet-5
    CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS 1
```

```bash
ccgs models list litellm
```
```text
Models available on 'litellm' (https://litellm.my-company.com):

  MODEL ID                                          CTX IN       CTX OUT
  -----------------------------------------------------------------------
  claude-sonnet-5                                   200,000       64,000
  claude-opus-4-8                                   200,000       32,000
  claude-haiku-4-8                                  200,000       32,000

  Total: 3 model(s)
```

**Pick a default model interactively**

```bash
ccgs models set litellm
```
```text
Fetching models from 'litellm' (https://litellm.my-company.com)...
Select default model for 'litellm'  (↑/↓ or j/k, Enter to select, q to cancel)
    (clear default — use Claude Code's default)
  › claude-opus-4-8
    claude-sonnet-5
[ccgs] Default model for 'litellm' set to: claude-opus-4-8
  Applied immediately — 'litellm' is the active proxy.
  Restart Claude Code to apply.
```

Navigate with `↑`/`↓` (or `j`/`k`), `Enter` to select, `q`/`Esc` to cancel. If the proxy you're setting is the active one, the change is written straight to `settings.json` — no need to run `ccgs proxy <name>` again. Piping input (e.g. in scripts or CI) falls back to a numbered prompt automatically.

**Session-only (env vars, no settings.json write)**

```bash
ccgs proxy litellm --session
ccgs native --session
```
```text
[ccgs] Session vars applied to current shell.
```

---

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/antoinefradin/claude-code-gateway-easy-switch/main/quick-install.sh | bash
```

Installs to `~/.local/bin/ccgs` and injects the shell function into your `~/.zshrc` or `~/.bashrc`.

### Manual

```bash
git clone https://github.com/antoinefradin/claude-code-gateway-easy-switch
cd claude-code-gateway-easy-switch
bash install.sh
```

### Install modes

| Mode | Location | Requires sudo |
|---|---|---|
| `--user` (default) | `~/.local/bin` | No |
| `--system` | `/usr/local/bin` | Usually yes |
| `--project` | Current directory | No |

```bash
bash install.sh --user       # default
bash install.sh --system     # system-wide
bash install.sh --project    # local to current dir
bash install.sh --no-shell-function  # skip shell function injection
```

### PATH setup

If `~/.local/bin` is not in your PATH, add this to your shell profile:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then: `source ~/.zshrc` (or `~/.bashrc`)

### Uninstall

```bash
bash uninstall.sh
```

---

## Session Mode (`--session`)

By default, `ccgs proxy` writes to `settings.json` — permanent across all terminals and Claude Code restarts. Use `--session` when you want the switch to only affect the current shell session:

```bash
# Requires the shell function (installed automatically):
ccgs proxy litellm --session
ccgs native --session

# Verify
echo $ANTHROPIC_BASE_URL
```

Session mode exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and optionally `ANTHROPIC_MODEL` as shell variables. These override `settings.json` for Claude Code processes spawned from that shell.

---

## Configuration

Config is stored at `~/.config/ccgs/config` (XDG-compliant):

```bash
CCGS_ACTIVE="litellm"

CCGS_PROXY_LITELLM_URL="https://litellm.my-company.com"
CCGS_PROXY_LITELLM_KEY="sk-mymaster"
CCGS_PROXY_LITELLM_MODEL="claude-sonnet-5"

CCGS_PROXY_OPENROUTER_URL="https://openrouter.ai/api"
CCGS_PROXY_OPENROUTER_KEY="sk-or-v1-..."
CCGS_PROXY_OPENROUTER_MODEL=""
```

Edit with: `ccgs config`

See [docs/CONFIGURATION.md](docs/CONFIGURATION.md) for full reference.

---

## Setting Up LiteLLM

See [docs/LITELLM.md](docs/LITELLM.md) for a complete guide including:
- Local setup with `pip install litellm`
- Example `config.yaml` for Claude models
- Docker Compose deployment

Quick example:

```bash
pip install litellm
litellm --model anthropic/claude-sonnet-4-6 --port 4000
ccgs add litellm https://litellm.my-company.com
ccgs proxy litellm
ccgs models list litellm
```

---

## MCP & claude.ai Connectors

Switching to a gateway disables **claude.ai connectors** (cloud-managed MCP) — but not MCP itself. Add the same servers locally with `claude mcp add`; they work regardless of provider.

See [docs/MCP.md](docs/MCP.md) for why connectors and gateways are mutually exclusive, how to add MCP servers locally, and the MCP tool search caveat behind a custom base URL.

---

## Requirements

- **bash** 3.2+ (macOS default ships 3.2; any Linux bash works)
- **python3** (macOS 3.9+ system python; any modern Linux python3)
- **curl** (for `models list`)
- **Claude Code** with `~/.claude/settings.json` (created on first Claude Code run)

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for solutions to common issues.

**Most common:** After switching, restart Claude Code (the settings.json is read at startup).

---

## Contributing

Contributions welcome! Please open an issue first for significant changes.

```bash
git clone https://github.com/antoinefradin/claude-code-gateway-easy-switch
cd claude-code-gateway-easy-switch
# Run tests
bash tests/e2e.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branching, commit, and PR rules,
and [docs/RELEASE.md](docs/RELEASE.md) for how versioning and automated releases
work.

---

## License

MIT — see [LICENSE](LICENSE)

---

*Inspired by [foreveryh/claude-code-switch](https://github.com/foreveryh/claude-code-switch)*
