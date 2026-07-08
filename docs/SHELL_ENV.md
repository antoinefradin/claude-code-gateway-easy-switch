# Shell Environment Variables

## How it works

When VS Code launches, its integrated terminal inherits the full environment from your shell profile. Any `export ANTHROPIC_AUTH_TOKEN=...` or `export ANTHROPIC_BASE_URL=...` in `~/.zshrc`, `~/.zprofile`, or `~/.zshenv` is already set in the process environment before Claude Code reads settings.json — so those values take effect regardless of what settings files contain, and `/status` will show them as "User settings."

---

## Diagnosing shell-injected values

Run these to find where the variables are coming from:

```bash
echo $ANTHROPIC_AUTH_TOKEN
echo $ANTHROPIC_BASE_URL

# Search shell profile files
grep -rn "ANTHROPIC_AUTH_TOKEN\|ANTHROPIC_BASE_URL" \
  ~/.zshrc ~/.zprofile ~/.zshenv ~/.bashrc ~/.bash_profile ~/.profile 2>/dev/null

# Check for a shell function or alias wrapping claude
type claude
alias | grep claude
```

If you're running `claude` from the ccgs repo, also check for a `.envrc` (direnv), `.env`, or shell function that exports these vars from that directory:

```bash
grep -rn "ANTHROPIC_AUTH_TOKEN\|ANTHROPIC_BASE_URL" \
  /path/to/claude-code-gateway-switch
```

---

## Fix

1. Remove or comment out the `export` line(s) found above.
2. **Fully quit VS Code** — not just reload the window. The integrated terminal keeps the environment it inherited at launch; only a fresh start picks up the updated profile.
3. Run `/status` again to confirm the values are cleared.

### Why window reload isn't enough

Reloading the VS Code window reuses the existing terminal process and its inherited environment. A full quit-and-reopen (or opening a new terminal after editing your profile) is required for the change to take effect.

---

## Uninstall / cleanup

To fully remove all shell-injected gateway configuration:

1. Open your shell profile (`~/.zshrc`, `~/.zprofile`, or `~/.zshenv`) and delete or comment out any lines that export `ANTHROPIC_AUTH_TOKEN` or `ANTHROPIC_BASE_URL`.

2. If a `.env` or `.envrc` file in the project directory exports these vars, remove or clear it:

```bash
# Remove a project-level .env
rm /path/to/project/.env

# Or for direnv: clear .envrc and re-allow
echo "" > /path/to/project/.envrc && direnv allow
```

3. Unset the variables in the current terminal session without restarting:

```bash
unset ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_BASE_URL
```

4. Confirm the vars are gone:

```bash
echo $ANTHROPIC_AUTH_TOKEN  # should print nothing
echo $ANTHROPIC_BASE_URL    # should print nothing
```
