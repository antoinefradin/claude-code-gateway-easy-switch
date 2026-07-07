# Changelog

All notable changes to this project will be documented here.

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
