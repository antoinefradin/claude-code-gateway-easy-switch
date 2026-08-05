---
name: ccgs
description: >-
  Switch Claude Code between native Anthropic and a LiteLLM / OpenAI-compatible
  gateway, and manage the proxies and models involved, by driving the `ccgs`
  CLI. Use when the user wants to switch providers, add / remove / list proxies,
  pick a default model, or diagnose which provider Claude Code is pointed at.
  Triggers include: "switch to my proxy", "use litellm", "go back to native
  Anthropic", "which gateway am I on", "what provider is Claude Code using",
  "add a proxy", "list my proxies", "set the default model".
allowed-tools: Bash, Read
---

# ccgs — Claude Code Gateway Easy Switch

Operate the `ccgs` CLI to switch Claude Code between **native Anthropic** and any
**LiteLLM / OpenAI-compatible gateway**, and to manage the proxies and models involved.

## Prime directive: the CLI owns all mutations

Drive **every** change through the `ccgs` command. **Never** hand-edit
`~/.claude/settings.json` or `~/.config/ccgs/config` yourself — that is exactly the manual,
error-prone process `ccgs` exists to replace.

`ccgs` manages **only** these four keys in the `env` block of `~/.claude/settings.json`:

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_API_KEY` (only ever *cleared*, never set)
- `ANTHROPIC_MODEL`

Everything else — theme, `effortLevel`, permissions, hooks, and other env vars like
`ANTHROPIC_DEFAULT_SONNET_MODEL` — passes through untouched. Preserving that guarantee is the
whole point of the tool, so if you ever feel tempted to open settings.json in an editor, stop:
there is a `ccgs` command for it.

- Proxy definitions live in `~/.config/ccgs/config` (`CCGS_*` vars).
- Claude Code reads `~/.claude/settings.json` (`ANTHROPIC_*` keys).
- `ccgs proxy <name>` projects the former into the latter.

## Inspect first

Before changing anything, run `ccgs status` to learn the active mode and the current
settings.json env block, and `ccgs list` to see the configured proxies and which one is
`[ACTIVE]`. Decide from that state — don't assume.

## Command reference

| Command | Purpose |
| --- | --- |
| `ccgs native` | Switch to native Anthropic API (clears the managed keys) |
| `ccgs proxy <name>` | Switch to a named proxy |
| `ccgs models list [name]` | List models from the active proxy (or a named one) |
| `ccgs models set [name]` | Interactively pick a default model (arrow keys) |
| `ccgs add <name> <url> [key]` | Add or update a proxy (positional) |
| `ccgs add <name> --base-url <url> [--token <key>]` | Add or update a proxy (named flags) |
| `ccgs remove <name>` | Remove a proxy |
| `ccgs list` | List all configured proxies |
| `ccgs status` | Show current mode and settings.json env block |
| `ccgs config` | Open the config file in `$EDITOR` |
| `ccgs help` | Show help |
| `ccgs version` | Show version (currently 0.2.0) |

Run `ccgs help` if a flag is unclear.

**`--session` flag.** `ccgs native` and `ccgs proxy <name>` accept `--session` to export the env
vars into the *current shell* instead of writing `settings.json`. It requires the installed shell
function, or `eval "$(ccgs proxy <name> --session)"`. Use this only when the user explicitly wants
a session-only, non-persistent switch.

## Common workflows

- **Add and switch to a proxy:** `ccgs add <name> <url> [key]` → `ccgs proxy <name>`, then verify.
- **Switch back to native:** `ccgs native`, then verify the env block cleared.
- **Set a default model:** `ccgs models set <name>` is **interactive** (arrow keys). Prefer telling
  the user to run it themselves; only run it non-interactively when a model id is already decided
  and can be supplied directly.

## Safety rules

- **Secrets:** never write tokens into files yourself. Pass a key only as a `ccgs add` argument.
  Never echo a full token back — `ccgs` already masks them (e.g. `sk-yourk...`); keep it that way.
- **Confirm destructive or identity-changing actions.** Get explicit confirmation before
  `ccgs remove <name>`, and before switching the active provider if the user didn't clearly ask —
  switching changes billing/identity and disables claude.ai connectors.
- **Restart reminder:** every switch requires **restarting Claude Code** to take effect. The CLI
  prints this; surface it to the user.

## MCP / claude.ai connectors caveat

Switching to a gateway disables **claude.ai connectors** (cloud-managed MCP servers) because a
credential (`ANTHROPIC_AUTH_TOKEN`) then takes precedence over the claude.ai subscription login.
It does **not** disable local MCP servers added via `claude mcp add` — those are independent of the
model provider. If the user needs connectors while on a gateway, point them to `docs/MCP.md`.

## Verification: keep proof distinct

After any change, prove it:

- `ccgs status` proves the active mode and the exact settings.json env block.
- `ccgs list` proves the configured proxies and which one is `[ACTIVE]`.

Re-run `ccgs status` after switching and confirm the env block matches intent — e.g. after
`ccgs native` the four managed keys are gone; after `ccgs proxy <name>` `ANTHROPIC_BASE_URL` and
`ANTHROPIC_AUTH_TOKEN` point at that proxy. State-changing commands and their proof are separate
steps — don't treat the command's own success message as verification.
