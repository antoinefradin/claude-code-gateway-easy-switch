# Troubleshooting

---

## Claude Code still uses the old provider after `ccgs proxy`

**Cause:** Claude Code reads `settings.json` at startup. Switching providers doesn't hot-reload.

**Fix:** Restart Claude Code after every `ccgs native` or `ccgs proxy` command:
- Terminal: close and reopen `claude`
- VS Code: run `Claude Code: Restart` from the command palette, or reload the window
- Desktop app: quit and relaunch

---

## `settings.json` not found / `mkdir` errors

**Cause:** Claude Code hasn't been run yet and `~/.claude/` doesn't exist.

**Fix:** Launch Claude Code at least once to initialize the directory, then use `ccgs`.

Alternatively, ccgs will create the directory and file automatically on first switch — but you need write permission to `~/.claude/`.

---

## Permission denied on `settings.json`

**Cause:** Incorrect file permissions.

**Fix:**
```bash
chmod 644 ~/.claude/settings.json
chmod 755 ~/.claude/
```

---

## `python3: command not found`

**Cause:** python3 is not installed or not in PATH.

**Fix:**
```bash
# macOS (Homebrew)
brew install python3

# Ubuntu/Debian
sudo apt install python3

# Fedora/RHEL
sudo dnf install python3
```

After install, verify: `python3 --version`

---

## `curl` failed to reach proxy

**Cause:** LiteLLM proxy is not running, or wrong URL/port.

**Fix:**
```bash
# Check if proxy is running
curl https://litellm.my-company.com/health

# If not running, start LiteLLM
litellm --config config.yaml --port 4000

# Verify URL in ccgs config
ccgs status
```

---

## HTTP 401 from `models list` endpoint

**Cause:** API key is wrong or missing.

**Fix:**
```bash
# Check your key
ccgs config
# Look at: CCGS_PROXY_<NAME>_KEY

# Test key directly
curl -H "Authorization: Bearer sk-yourkey" https://litellm.my-company.com/v1/models

# If proxy is open (no auth required), re-add without key:
ccgs add litellm https://litellm.my-company.com
```

---

## `--session` mode not working / vars not exported

**Cause:** The shell function is not installed. When `ccgs` runs as a subprocess, env vars can't be exported to the parent shell.

**Fix — Option 1:** Use `eval` (always works without shell function):
```bash
eval "$(ccgs proxy litellm --session)"
eval "$(ccgs native --session)"
```

**Fix — Option 2:** Re-run the installer to inject the shell function:
```bash
bash install.sh
source ~/.zshrc  # or ~/.bashrc
```

Verify the function is loaded:
```bash
type ccgs  # should show "ccgs is a function"
```

---

## `ccgs models list` shows no models

**Cause:** LiteLLM started but has no models configured, or responded with an unexpected format.

**Fix:**
```bash
# Check raw response
curl -H "Authorization: Bearer sk-key" https://litellm.my-company.com/v1/models

# Add models to your litellm_config.yaml and restart:
litellm --config litellm_config.yaml --port 4000
```

---

## `ccgs: command not found`

**Cause:** The install directory (`~/.local/bin`) is not in your `$PATH`.

**Fix:** Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then:
```bash
source ~/.zshrc   # or source ~/.bashrc
```

Alternatively, install system-wide:
```bash
bash install.sh --system  # installs to /usr/local/bin
```

---

## Does ccgs work with Claude Code for VS Code?

**Yes.** The VS Code Claude Code extension reads the same `~/.claude/settings.json`. After `ccgs proxy <name>`, reload the VS Code window or restart the extension for changes to take effect.

---

## Proxy shows `[ACTIVE]` in `ccgs list` but Claude Code uses native

**Cause:** A shell environment variable (`ANTHROPIC_BASE_URL`) is overriding `settings.json`. Shell env vars take precedence over the settings file.

**Diagnosis:**
```bash
echo $ANTHROPIC_BASE_URL   # should be empty for native, or proxy URL for proxy mode
```

**Fix:**
```bash
# Clear the session var
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_MODEL

# Or use session mode intentionally:
eval "$(ccgs proxy litellm --session)"
```

---

## `settings.json` was corrupted after using ccgs

ccgs creates a timestamped backup before every write. Restore with:

```bash
ls ~/.claude/backups/
cp ~/.claude/backups/settings_YYYYMMDD_HHMMSS.json ~/.claude/settings.json
```

---

## I want to see what ccgs writes to settings.json

Use `CLAUDE_SETTINGS` to test against a temp file without touching your real settings:

```bash
CLAUDE_SETTINGS=/tmp/test.json ccgs proxy litellm
cat /tmp/test.json
```
