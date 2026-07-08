#!/usr/bin/env bash
# ccgs installer
# Usage: bash install.sh [--user|--system|--project] [--no-shell-function] [--no-path-check]

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────────────────

INSTALL_MODE="user"
INJECT_SHELL_FUNCTION=1
CHECK_PATH=1

# Locate the ccgs script (same dir as this install.sh, or CCGS_REPO_DIR override)
SCRIPT_DIR="${CCGS_REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CCGS_SCRIPT="$SCRIPT_DIR/ccgs.sh"

# ─── Colors ───────────────────────────────────────────────────────────────────

if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; BLUE=''; BOLD=''; RESET=''
fi

info()    { printf "${BLUE}  %s${RESET}\n" "$*"; }
success() { printf "${GREEN}[install] %s${RESET}\n" "$*"; }
warn()    { printf "${YELLOW}[install] Warning: %s${RESET}\n" "$*" >&2; }
die()     { printf '\033[0;31m[install] Error: %s\033[0m\n' "$*" >&2; exit 1; }

# ─── Argument Parsing ─────────────────────────────────────────────────────────

for arg in "$@"; do
    case "$arg" in
        --user)               INSTALL_MODE="user" ;;
        --system)             INSTALL_MODE="system" ;;
        --project)            INSTALL_MODE="project" ;;
        --no-shell-function)  INJECT_SHELL_FUNCTION=0 ;;
        --no-path-check)      CHECK_PATH=0 ;;
        --help|-h)
            printf 'Usage: bash install.sh [OPTIONS]\n\n'
            printf 'Options:\n'
            printf '  --user     Install to ~/.local/bin (default, no sudo required)\n'
            printf '  --system   Install to /usr/local/bin (may require sudo)\n'
            printf '  --project  Copy ccgs to current working directory\n'
            printf '  --no-shell-function  Skip shell function injection\n'
            printf '  --no-path-check      Skip PATH warning\n'
            exit 0
            ;;
        *) die "Unknown option: $arg. Use --help for usage." ;;
    esac
done

# ─── Validate Source ──────────────────────────────────────────────────────────

[[ -f "$CCGS_SCRIPT" ]] || die "ccgs script not found at: $CCGS_SCRIPT"
[[ -x "$CCGS_SCRIPT" ]] || chmod +x "$CCGS_SCRIPT"

# ─── Determine Install Directory ──────────────────────────────────────────────

case "$INSTALL_MODE" in
    user)
        if [[ -d "$HOME/.local/bin" ]] || ! [[ -d "$HOME/bin" ]]; then
            INSTALL_DIR="$HOME/.local/bin"
        else
            INSTALL_DIR="$HOME/bin"
        fi
        ;;
    system)
        INSTALL_DIR="/usr/local/bin"
        ;;
    project)
        INSTALL_DIR="$(pwd)"
        ;;
esac

# ─── Install ──────────────────────────────────────────────────────────────────

printf '\n'
printf "${BOLD}Installing ccgs${RESET}\n"
printf '\n'
info "Mode:        $INSTALL_MODE"
info "Install dir: $INSTALL_DIR"
printf '\n'

mkdir -p "$INSTALL_DIR"
cp "$CCGS_SCRIPT" "$INSTALL_DIR/ccgs"
chmod +x "$INSTALL_DIR/ccgs"
success "Copied ccgs → $INSTALL_DIR/ccgs"

# ─── Shell Function ───────────────────────────────────────────────────────────

if [[ "$INJECT_SHELL_FUNCTION" -eq 1 ]] && [[ "$INSTALL_MODE" != "project" ]]; then
    printf '\n'
    "$INSTALL_DIR/ccgs" --inject-shell-function
fi

# ─── PATH Check ───────────────────────────────────────────────────────────────

if [[ "$CHECK_PATH" -eq 1 ]]; then
    if ! command -v ccgs >/dev/null 2>&1; then
        printf '\n'
        warn "'$INSTALL_DIR' is not in your PATH."
        printf '\n'
        printf "  Add to PATH by appending to your shell profile:\n"
        printf '\n'
        printf "    ${BOLD}export PATH=\"%s:\$PATH\"${RESET}\n" "$INSTALL_DIR"
        printf '\n'
        printf "  Then:  source ~/.zshrc  (or ~/.bashrc)\n"
    fi
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

printf '\n'
success "Installation complete!"
printf '\n'
info "Quick start:"
info "  ccgs add litellm https://litellm.my-company.com sk-yourkey"
info "  ccgs proxy litellm"
info "  ccgs native"
info "  ccgs help"
printf '\n'
