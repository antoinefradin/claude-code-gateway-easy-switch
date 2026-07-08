# Shell Override Troubleshooting

## `ccgs proxy` has no effect — Claude Code still uses the old endpoint

**Cause:** `ANTHROPIC_BASE_URL` or `ANTHROPIC_AUTH_TOKEN` (or both) are exported in your shell profile (`~/.zshrc`, `~/.zprofile`, or `~/.zshenv`). Shell env vars take precedence over `settings.json`. `ccgs proxy <name>` writes the new values to `settings.json` correctly, but those writes are silently shadowed for any terminal that already inherited the profile — including VS Code's integrated terminal.

**Fix:** Find and remove the conflicting exports:

```bash
grep -rn "ANTHROPIC_BASE_URL\|ANTHROPIC_AUTH_TOKEN" \
  ~/.zshrc ~/.zprofile ~/.zshenv ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null
```

Comment out or delete the matching lines, then **fully quit and reopen VS Code** (a window reload keeps the inherited env).

To unset in the current session without restarting:

```bash
unset ANTHROPIC_BASE_URL
unset ANTHROPIC_AUTH_TOKEN
```

---

## Export lines in `~/.zshrc` were not added by ccgs install

**Cause:** ccgs install only injects a shell function wrapper, fenced by `# >>> ccgs shell function >>>` markers. It never writes `export ANTHROPIC_BASE_URL` or `export ANTHROPIC_AUTH_TOKEN` to any shell profile. Those lines were added manually — typically as an early direct-config step before ccgs was set up.

**Fix — Find the source:**

```bash
# Check shell profile files
grep -rn "ANTHROPIC_BASE_URL\|ANTHROPIC_AUTH_TOKEN" \
  ~/.zshrc ~/.zprofile ~/.zshenv ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null

# Check the project directory for .env or .envrc
grep -rn "ANTHROPIC_BASE_URL\|ANTHROPIC_AUTH_TOKEN" /path/to/project

# Check for a shell function or alias wrapping claude
type claude
alias | grep claude
```

Once found, remove the lines and restart VS Code. Then use `ccgs proxy <name>` to manage the gateway going forward.

---

## Do I need to remove these lines for ccgs to work?

**Cause:** Shell env vars are a hard override. While `ANTHROPIC_BASE_URL` is set in your profile, `ccgs proxy litellm` writes `settings.json` and reports success — but Claude Code never uses it. The proxy shows `[ACTIVE]` in `ccgs list` yet traffic keeps going to the hardcoded endpoint with no error or warning.

**Fix:** Yes — remove or comment out the `export` lines from your shell profile and do a full VS Code restart. After that, `ccgs proxy <name>` takes full effect.

Commenting out (prefixing with `#`) has the same effect as deleting — the var is no longer exported into new shell sessions:

To confirm the vars are gone before restarting:

```bash
echo $ANTHROPIC_BASE_URL    # should print nothing
echo $ANTHROPIC_AUTH_TOKEN  # should print nothing
```

```bash
# Before — active, overrides ccgs
export ANTHROPIC_BASE_URL="https://litellm.my-company.com"
export ANTHROPIC_AUTH_TOKEN="sk-key"

# After — commented out, ccgs takes over
#export ANTHROPIC_BASE_URL="https://litellm.my-company.com"
#export ANTHROPIC_AUTH_TOKEN="sk-key"
```

Example of what a conflicting entry looks like in `~/.zshrc`:

```bash
# These two lines override ccgs — remove or comment them out
export ANTHROPIC_BASE_URL="https://litellm.my-company.com"
export ANTHROPIC_AUTH_TOKEN="sk-key"
```
