# Changelog

All notable changes to this project will be documented here.

## [0.2.0] — 2026-07-08

### Added

- `ccgs models set [name]` — interactively pick a proxy's default model with the arrow keys (↑/↓ or j/k, Enter to confirm, q/Esc to cancel), fetched live from `/v1/models`
- Numbered-prompt fallback for `ccgs models set` when stdin/stdout isn't a TTY (scripts, pipes, CI)
- `ccgs models set` applies immediately to `settings.json` when the target proxy is currently active — no need to re-run `ccgs proxy <name>`
- A `(clear default — use Claude Code's default)` option to unset a proxy's default model from the same picker

### Changed

- `ccgs add` now points users at `ccgs models set <name>` instead of `ccgs config` for setting a default model
- `ccgs models set` / `models list` with no active proxy now print actionable guidance (`ccgs proxy <name>` / `ccgs list`, or `ccgs add` when nothing is configured) instead of a single terse line
- Internal: `cmd_models_list` model-fetching logic extracted into reusable `fetch_models_body` / `list_model_ids` helpers

### Fixed

- `ccgs models set` now actually launches the arrow-key picker in a real terminal. It previously always fell back to the numbered prompt because it checked stdout (`-t 1`) for a TTY, but callers capture stdout via `$(...)`; the interactivity check now uses stderr (`-t 2`), where the menu is rendered
- `ccgs models set` arrow keys no longer error on macOS's stock bash 3.2 — the escape-sequence read used a fractional `read -t 0.05` timeout, which bash 3.2 rejects; changed to a whole-second timeout

## [0.1.0] — 2026-07-06

### Added

- `ccgs native` — switch to native Anthropic API (clears proxy from `settings.json`)
- `ccgs proxy <name>` — switch to a named proxy (writes `settings.json` env block)
- `ccgs models list [name]` — list models from a proxy via `/v1/models`, with formatted table output (model ID, context in/out)
- `ccgs add <name> <url> [key]` — add or update a proxy configuration
- `ccgs remove <name>` — remove a proxy with confirmation guard
- `ccgs list` — list all configured proxies with active indicator
- `ccgs status` — show current mode, proxy details, and live `settings.json` state
- `ccgs config` — open config in `$EDITOR`
- `--session` flag — export env vars into current shell (no `settings.json` write); requires shell function or `eval`
- Shell function injection into `.zshrc` / `.bashrc` for seamless `--session` mode
- XDG-compliant config at `~/.config/ccgs/config`
- Atomic `settings.json` writes via Python `tempfile` + `os.replace`
- Automatic backup of `settings.json` before every write (keeps last 10)
- User / system / project install modes
- `quick-install.sh` one-liner bootstrap
- `uninstall.sh` with optional settings.json reset and config removal
- Full documentation: README, LITELLM, CONFIGURATION, CUSTOM_PROXY, TROUBLESHOOTING
- End-to-end test suite (`tests/e2e.sh`) with 35 isolated tests
