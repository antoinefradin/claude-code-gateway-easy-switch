# ccgs — Claude Code Gateway Switch

> One command to switch Claude Code between native Anthropic and any LiteLLM / OpenAI-compatible proxy.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Bash](https://img.shields.io/badge/bash-3.2%2B-orange)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)

---

## Why

Claude Code is powerful. LiteLLM is powerful. But switching between your Anthropic subscription and a self-hosted gateway currently means manually editing `~/.claude/settings.json`. `ccgs` automates this — one command, zero settings corruption.

---

## Quick Start

```bash
# 1. Install
curl -fsSL https://raw.githubusercontent.com/antoinefradin/claude-code-gateway-switch/main/quick-install.sh | bash

# 2. Add your proxy
ccgs add litellm http://localhost:4000 sk-yourkey

# 3. Switch to proxy
ccgs proxy litellm

# 4. Use Claude Code normally — it now routes through your proxy
claude

# 5. Switch back to native when needed
ccgs native
```

---

## How It Works

`ccgs` writes to the `env` block in `~/.claude/settings.json` — the same mechanism Claude Code uses for environment variable injection:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_AUTH_TOKEN": "sk-yourkey"
  }
}
```

Only the four ccgs-managed keys (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL`) are ever touched. All other settings — theme, effortLevel, permissions, hooks, custom env vars — pass through completely untouched.

Switching back with `ccgs native` simply removes those keys.

---

## Command Reference

| Command | Description |
|---|---|
| `ccgs native` | Switch to native Anthropic API |
| `ccgs proxy <name>` | Switch to a named proxy |
| `ccgs models list` | List models from the active proxy |
| `ccgs models list <name>` | List models from a specific proxy |
| `ccgs add <name> <url> [key]` | Add or update a proxy |
| `ccgs remove <name>` | Remove a proxy |
| `ccgs list` | List all configured proxies |
| `ccgs status` | Show current mode and settings.json state |
| `ccgs config` | Edit config file in `$EDITOR` |
| `ccgs help` | Show help |
| `ccgs version` | Show version |

### Examples

```bash
# Add proxies
ccgs add litellm http://localhost:4000 sk-mykey
ccgs add openrouter https://openrouter.ai/api sk-or-v1-mykey
ccgs add internal http://proxy.internal:8080  # no auth key

# Switch
ccgs proxy litellm
ccgs proxy openrouter
ccgs native

# Inspect
ccgs list
ccgs status
ccgs models list litellm

# Session-only (env vars, no settings.json write)
eval "$(ccgs proxy litellm --session)"
eval "$(ccgs native --session)"
```

---

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/antoinefradin/claude-code-gateway-switch/main/quick-install.sh | bash
```

Installs to `~/.local/bin/ccgs` and injects the shell function into your `~/.zshrc` or `~/.bashrc`.

### Manual

```bash
git clone https://github.com/antoinefradin/claude-code-gateway-switch
cd claude-code-gateway-switch
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
# Requires the shell function (installed automatically) or eval:
eval "$(ccgs proxy litellm --session)"
eval "$(ccgs native --session)"

# Verify
echo $ANTHROPIC_BASE_URL
```

Session mode exports `ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, and optionally `ANTHROPIC_MODEL` as shell variables. These override `settings.json` for Claude Code processes spawned from that shell.

---

## Configuration

Config is stored at `~/.config/ccgs/config` (XDG-compliant):

```bash
CCGS_ACTIVE="litellm"

CCGS_PROXY_LITELLM_URL="http://localhost:4000"
CCGS_PROXY_LITELLM_KEY="sk-mykey"
CCGS_PROXY_LITELLM_MODEL=""

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
ccgs add litellm http://localhost:4000
ccgs proxy litellm
ccgs models list litellm
```

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
git clone https://github.com/antoinefradin/claude-code-gateway-switch
cd claude-code-gateway-switch
# Run tests
bash tests/e2e.sh
```

---

## License

MIT — see [LICENSE](LICENSE)

---

*Inspired by [foreveryh/claude-code-switch](https://github.com/foreveryh/claude-code-switch)*
