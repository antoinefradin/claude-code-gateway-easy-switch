# Changelog

All notable changes to this project will be documented here.

## [0.3.1] — 2026-08-05

### Fixed

- keep brand link on project Pages subpath

### Changed

Merge pull request #5 from antoinefradin/feat/website
- restore GitHub Pages deploy workflow for /website
- add release process guide

## [0.3.0] — 2026-08-05

### Added

- restyle brand as Micro 5 wordmark
- add landing page with GitHub Pages deploy
- add interactive default-model picker
- add --base-url and --token flags to ccgs add

### Fixed

- send tput cursor sequences to stderr
- make the arrow-key picker actually activate
- give actionable guidance when no proxy is active

### Changed

Merge pull request #4 from antoinefradin/feat/website
- remove GitHub Pages deploy workflow
- add ccgs Claude Code skill
- document versioning and release workflow
- add automated release pipeline
Merge pull request #3 from antoinefradin/docs/mcp-gateway-guide
- add MCP & claude.ai connectors guide
Merge pull request #2 from antoinefradin/fix/select-cursor-stdout
- update README title and tagline for repo rename
- rename repo references to claude-code-gateway-easy-switch
Merge pull request #1 from antoinefradin/feat/models-set-picker
- explain config-to-settings.json variable mapping for models set
- use bare 'ccgs --session' instead of eval wrapper
- add /status verification examples for native and proxy modes
- add shell override troubleshooting guide
- add SHELL_ENV guide for shell-injected env vars
- rename ccgs to ccgs.sh
- update proxy examples and differentiate output code blocks
- update CCGS_PROXY_LITELLM_URL examples to company proxy
- replace localhost:4000 with company proxy URL in docs/
- update examples to reflect real-world settings.json
- add banner and screenshots folder structure
- add banner image
- add CONTRIBUTING.md and README example output
Replace YOUR_USERNAME placeholder with antoinefradin
Initial release: ccgs v0.1.0 — Claude Code Gateway Switch

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
