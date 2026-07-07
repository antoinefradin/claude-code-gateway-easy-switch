#!/usr/bin/env bash
# ccgs uninstaller

set -euo pipefail

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()    { printf "${BLUE}  %s${RESET}\n" "$*"; }
success() { printf "${GREEN}[uninstall] %s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}[uninstall] %s${RESET}\n" "$*" >&2; }

ask() {
    local prompt="$1" reply
    printf '%s [y/N] ' "$prompt"
    read -r reply || reply="n"
    [[ "$reply" =~ ^[Yy]$ ]]
}

printf '\n'
printf "${BOLD}Uninstalling ccgs${RESET}\n"
printf '\n'

# ─── Remove Binary ────────────────────────────────────────────────────────────

REMOVED_BINARY=0
for candidate in "$HOME/.local/bin/ccgs" "$HOME/bin/ccgs" "/usr/local/bin/ccgs" "./ccgs"; do
    if [[ -f "$candidate" ]]; then
        rm -f "$candidate"
        success "Removed $candidate"
        REMOVED_BINARY=1
        break
    fi
done

# Also check PATH
if [[ "$REMOVED_BINARY" -eq 0 ]]; then
    CCGS_PATH=$(command -v ccgs 2>/dev/null || true)
    if [[ -n "$CCGS_PATH" ]]; then
        rm -f "$CCGS_PATH"
        success "Removed $CCGS_PATH"
        REMOVED_BINARY=1
    fi
fi

[[ "$REMOVED_BINARY" -eq 1 ]] || warn "ccgs binary not found; may already be removed."

# ─── Remove Shell Function ────────────────────────────────────────────────────

TARGET_SHELL=$(basename "${SHELL:-bash}")
case "$TARGET_SHELL" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash) SHELL_RC="$HOME/.bashrc" ;;
    *)    SHELL_RC="" ;;
esac

if [[ -n "$SHELL_RC" ]] && grep -q ">>> ccgs shell function >>>" "$SHELL_RC" 2>/dev/null; then
    python3 - "$SHELL_RC" << 'PYEOF'
import sys, re, os, tempfile
file = sys.argv[1]
with open(file) as f:
    content = f.read()
new = re.sub(
    r'\n?# >>> ccgs shell function >>>.*?# <<< ccgs shell function <<<\n?',
    '\n', content, flags=re.DOTALL)
dir_path = os.path.dirname(os.path.abspath(file))
fd, tmp = tempfile.mkstemp(dir=dir_path, prefix='.ccgs_tmp_')
with os.fdopen(fd, 'w') as f:
    f.write(new)
os.replace(tmp, file)
PYEOF
    success "Shell function removed from $SHELL_RC"
fi

# ─── Reset settings.json to Native ───────────────────────────────────────────

CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
if [[ -f "$CLAUDE_SETTINGS" ]]; then
    if ask "Reset $CLAUDE_SETTINGS to native mode (remove proxy settings)?"; then
        python3 - "$CLAUDE_SETTINGS" << 'PYEOF'
import sys, json, os, tempfile
settings_file = sys.argv[1]
MANAGED = ("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_MODEL")
try:
    with open(settings_file) as f:
        data = json.load(f)
except (json.JSONDecodeError, ValueError):
    data = {}
env = data.get("env", {})
for k in MANAGED:
    env.pop(k, None)
data["env"] = env
dir_path = os.path.dirname(os.path.abspath(settings_file))
fd, tmp = tempfile.mkstemp(dir=dir_path, prefix='.ccgs_settings_tmp_')
with os.fdopen(fd, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp, settings_file)
print("settings.json reset to native mode.")
PYEOF
        success "settings.json reset. Restart Claude Code to apply."
    fi
fi

# ─── Remove Config Directory ─────────────────────────────────────────────────

CCGS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ccgs"
if [[ -d "$CCGS_CONFIG_DIR" ]]; then
    if ask "Remove config directory $CCGS_CONFIG_DIR?"; then
        rm -rf "$CCGS_CONFIG_DIR"
        success "Config directory removed."
    fi
fi

printf '\n'
success "Uninstall complete."
printf '\n'
