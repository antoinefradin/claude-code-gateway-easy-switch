#!/usr/bin/env bash
# ccgs — Claude Code Gateway Switch
# Switch Claude Code between native Anthropic and LiteLLM / OpenAI-compatible proxies.
# https://github.com/antoinefradin/claude-code-gateway-switch
# MIT License

set -euo pipefail

# ─── Constants ────────────────────────────────────────────────────────────────

readonly CCGS_VERSION="0.1.0"
readonly CCGS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ccgs"
readonly CCGS_CONFIG_FILE="$CCGS_CONFIG_DIR/config"
# Allow CLAUDE_SETTINGS env var to override the settings.json path (useful for testing)
readonly CLAUDE_SETTINGS_FILE="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"

# ─── Colors ───────────────────────────────────────────────────────────────────

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; RESET=''
fi

# ─── Logging ──────────────────────────────────────────────────────────────────

err()     { printf "${RED}[ccgs] Error: %s${RESET}\n" "$*" >&2; }
warn()    { printf "${YELLOW}[ccgs] Warning: %s${RESET}\n" "$*" >&2; }
info()    { printf "${BLUE}  %s${RESET}\n" "$*"; }
success() { printf "${GREEN}[ccgs] %s${RESET}\n" "$*"; }
header()  { printf "${BOLD}${CYAN}%s${RESET}\n" "$*"; }
die()     { err "$@"; exit 1; }

# ─── Dependency Checks ────────────────────────────────────────────────────────

require_python3() {
    command -v python3 >/dev/null 2>&1 \
        || die "python3 is required. Install: brew install python3 (macOS) | apt install python3 (Linux)"
}

require_curl() {
    command -v curl >/dev/null 2>&1 \
        || die "curl is required. Install: brew install curl (macOS) | apt install curl (Linux)"
}

# ─── Config File Management ───────────────────────────────────────────────────

load_config() {
    [[ -f "$CCGS_CONFIG_FILE" ]] || return 0
    # shellcheck source=/dev/null
    source "$CCGS_CONFIG_FILE"
}

init_config() {
    mkdir -p "$CCGS_CONFIG_DIR"
    cat > "$CCGS_CONFIG_FILE" << 'CONF'
# ccgs configuration
# https://github.com/antoinefradin/claude-code-gateway-switch
CCGS_ACTIVE="native"

# LiteLLM proxy (edit URL and key to match your setup)
CCGS_PROXY_LITELLM_URL="http://localhost:4000"
CCGS_PROXY_LITELLM_KEY=""
CCGS_PROXY_LITELLM_MODEL=""
CONF
    success "Config created at $CCGS_CONFIG_FILE"
}

write_config_value() {
    local key="$1" value="$2"
    mkdir -p "$CCGS_CONFIG_DIR"
    [[ -f "$CCGS_CONFIG_FILE" ]] || init_config
    require_python3
    python3 - "$CCGS_CONFIG_FILE" "$key" "$value" << 'PYEOF'
import sys, os, tempfile
config_file, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_file) as f:
    lines = f.readlines()
new_line = '{}="{}"\n'.format(key, value)
found = False
new_lines = []
for line in lines:
    if line.startswith('{}='.format(key)):
        new_lines.append(new_line)
        found = True
    else:
        new_lines.append(line)
if not found:
    new_lines.append(new_line)
dir_path = os.path.dirname(os.path.abspath(config_file))
fd, tmp = tempfile.mkstemp(dir=dir_path, prefix='.ccgs_tmp_')
with os.fdopen(fd, 'w') as f:
    f.writelines(new_lines)
os.replace(tmp, config_file)
PYEOF
}

remove_config_values_by_prefix() {
    local prefix="$1"
    [[ -f "$CCGS_CONFIG_FILE" ]] || return 0
    require_python3
    python3 - "$CCGS_CONFIG_FILE" "$prefix" << 'PYEOF'
import sys, os, tempfile
config_file, prefix = sys.argv[1], sys.argv[2]
with open(config_file) as f:
    lines = f.readlines()
new_lines = [l for l in lines if not l.startswith(prefix)]
dir_path = os.path.dirname(os.path.abspath(config_file))
fd, tmp = tempfile.mkstemp(dir=dir_path, prefix='.ccgs_tmp_')
with os.fdopen(fd, 'w') as f:
    f.writelines(new_lines)
os.replace(tmp, config_file)
PYEOF
}

# ─── Proxy Name Helpers ───────────────────────────────────────────────────────

normalize_proxy_name() {
    # Lowercase, dashes → underscores, strip invalid chars → valid bash identifier segment
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr '-' '_' | tr -cd 'a-z0-9_'
}

proxy_var_prefix() {
    # "my_proxy" → "CCGS_PROXY_MY_PROXY"
    local upper
    upper=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    printf 'CCGS_PROXY_%s' "$upper"
}

get_proxy_url() {
    local varname
    varname="$(proxy_var_prefix "$1")_URL"
    eval "printf '%s' \"\${${varname}:-}\""
}

get_proxy_key() {
    local varname
    varname="$(proxy_var_prefix "$1")_KEY"
    eval "printf '%s' \"\${${varname}:-}\""
}

get_proxy_model() {
    local varname
    varname="$(proxy_var_prefix "$1")_MODEL"
    eval "printf '%s' \"\${${varname}:-}\""
}

proxy_exists() {
    local url
    url=$(get_proxy_url "$1")
    [[ -n "$url" ]]
}

list_proxy_names() {
    [[ -f "$CCGS_CONFIG_FILE" ]] || return 0
    grep -E '^CCGS_PROXY_[A-Z0-9_]+_URL=' "$CCGS_CONFIG_FILE" \
        | sed 's/^CCGS_PROXY_//' \
        | sed 's/_URL=.*//' \
        | tr '[:upper:]' '[:lower:]' || true
}

# ─── settings.json Management ─────────────────────────────────────────────────

backup_settings() {
    [[ -f "$CLAUDE_SETTINGS_FILE" ]] || return 0
    local backup_dir
    backup_dir="$(dirname "$CLAUDE_SETTINGS_FILE")/backups"
    mkdir -p "$backup_dir"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp "$CLAUDE_SETTINGS_FILE" "$backup_dir/settings_${ts}.json"
    # Keep newest 10 backups
    ls -t "$backup_dir"/settings_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

update_settings_json() {
    local mode="$1"
    local url="${2:-}"
    local key="${3:-}"
    local model="${4:-}"

    require_python3
    backup_settings
    mkdir -p "$(dirname "$CLAUDE_SETTINGS_FILE")"
    [[ -f "$CLAUDE_SETTINGS_FILE" ]] || printf '{}' > "$CLAUDE_SETTINGS_FILE"

    python3 - "$CLAUDE_SETTINGS_FILE" "$mode" "$url" "$key" "$model" << 'PYEOF'
import sys, json, os, tempfile

settings_file = sys.argv[1]
mode, url, key, model = sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
MANAGED = ("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_MODEL")

try:
    with open(settings_file) as f:
        data = json.load(f)
except (json.JSONDecodeError, ValueError):
    print("[ccgs] Warning: settings.json was malformed, starting fresh", file=sys.stderr)
    data = {}

env = data.get("env", {})

# Remove only ccgs-managed keys; preserve everything else
for k in MANAGED:
    env.pop(k, None)

# Add proxy keys when switching to proxy mode
if mode == "proxy":
    if url:
        env["ANTHROPIC_BASE_URL"] = url
    if key:
        env["ANTHROPIC_AUTH_TOKEN"] = key
    if model:
        env["ANTHROPIC_MODEL"] = model

data["env"] = env

dir_path = os.path.dirname(os.path.abspath(settings_file))
fd, tmp = tempfile.mkstemp(dir=dir_path, prefix='.ccgs_settings_tmp_')
with os.fdopen(fd, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp, settings_file)
PYEOF
}

# ─── Session Mode ─────────────────────────────────────────────────────────────

print_session_exports() {
    local mode="$1" url="${2:-}" key="${3:-}" model="${4:-}"

    # Always print eval-able lines to stdout
    if [[ "$mode" == "proxy" ]]; then
        [[ -n "$url" ]]   && printf 'export ANTHROPIC_BASE_URL="%s"\n'    "$url"
        [[ -n "$key" ]]   && printf 'export ANTHROPIC_AUTH_TOKEN="%s"\n'  "$key"
        [[ -n "$model" ]] && printf 'export ANTHROPIC_MODEL="%s"\n'       "$model"
    else
        printf 'unset ANTHROPIC_BASE_URL\n'
        printf 'unset ANTHROPIC_AUTH_TOKEN\n'
        printf 'unset ANTHROPIC_API_KEY\n'
        printf 'unset ANTHROPIC_MODEL\n'
    fi

    # Print hint to stderr only when running interactively (not captured by shell function)
    if [[ "${CCGS_SESSION_OUTPUT:-0}" != "1" ]]; then
        printf '\n' >&2
        printf "${YELLOW}[ccgs] To apply to current shell:${RESET}\n" >&2
        printf "${BLUE}  eval \"\$(ccgs %s --session)\"${RESET}\n" "$mode" >&2
    fi
}

# ─── Commands ─────────────────────────────────────────────────────────────────

cmd_native() {
    local session_mode="$1"

    if [[ "$session_mode" -eq 1 ]]; then
        print_session_exports "native"
    else
        require_python3
        update_settings_json "native"
        write_config_value "CCGS_ACTIVE" "native"
        success "Switched to native Anthropic mode."
        info "Proxy settings cleared from settings.json."
        info "Restart Claude Code to apply."
    fi
}

cmd_proxy() {
    local session_mode="$1"
    shift || true
    local proxy_name
    proxy_name=$(normalize_proxy_name "${1:-}")

    [[ -n "$proxy_name" ]] || die "Proxy name required. Usage: ccgs proxy <name>"

    proxy_exists "$proxy_name" || {
        err "Proxy '$proxy_name' is not configured."
        info "Add it:      ccgs add $proxy_name <url> [key]"
        info "List all:    ccgs list"
        exit 1
    }

    local url key model
    url=$(get_proxy_url "$proxy_name")
    key=$(get_proxy_key "$proxy_name")
    model=$(get_proxy_model "$proxy_name")

    if [[ "$session_mode" -eq 1 ]]; then
        print_session_exports "proxy" "$url" "$key" "$model"
    else
        require_python3
        update_settings_json "proxy" "$url" "$key" "$model"
        write_config_value "CCGS_ACTIVE" "$proxy_name"
        success "Switched to proxy '$proxy_name'."
        info "URL:   $url"
        [[ -n "$key" ]]   && info "Key:   ${key:0:8}..." || info "Key:   (none — open proxy)"
        [[ -n "$model" ]] && info "Model: $model"
        info "Restart Claude Code to apply."
    fi
}

cmd_models_list() {
    local proxy_name="${1:-}"

    if [[ -z "$proxy_name" ]]; then
        local active="${CCGS_ACTIVE:-native}"
        if [[ "$active" == "native" ]]; then
            die "No proxy active. Usage: ccgs models list <name>  |  or switch to a proxy first."
        fi
        proxy_name="$active"
    fi

    proxy_name=$(normalize_proxy_name "$proxy_name")
    proxy_exists "$proxy_name" || die "Proxy '$proxy_name' not found. See: ccgs list"

    require_curl
    require_python3

    local url key
    url=$(get_proxy_url "$proxy_name")
    key=$(get_proxy_key "$proxy_name")

    header "Models available on '$proxy_name' ($url):"
    printf '\n'

    local tmp_body http_code
    tmp_body=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$tmp_body'" EXIT

    local curl_args=(-s --connect-timeout 10 --max-time 30 -w "%{http_code}" -o "$tmp_body")
    [[ -n "$key" ]] && curl_args+=(-H "Authorization: Bearer $key")

    http_code=$(curl "${curl_args[@]}" "$url/v1/models" 2>/dev/null) || {
        rm -f "$tmp_body"
        trap - EXIT
        die "curl failed to reach '$url'. Is the proxy running? Check: curl $url/health"
    }

    if [[ "$http_code" -ge 400 ]]; then
        printf "${RED}[ccgs] HTTP %s from %s/v1/models${RESET}\n" "$http_code" "$url" >&2
        if [[ "$http_code" -eq 401 ]] || [[ "$http_code" -eq 403 ]]; then
            warn "Auth failed — check your API key with: ccgs config"
        elif [[ "$http_code" -eq 404 ]]; then
            warn "Endpoint not found — proxy may not support /v1/models"
        fi
        [[ -s "$tmp_body" ]] && { printf 'Response: '; cat "$tmp_body"; printf '\n'; } >&2
        rm -f "$tmp_body"
        trap - EXIT
        exit 1
    fi

    python3 - "$tmp_body" << 'PYEOF'
import sys, json

with open(sys.argv[1]) as f:
    raw = f.read().strip()

if not raw:
    print("  (empty response)")
    sys.exit(1)

try:
    d = json.loads(raw)
except json.JSONDecodeError as e:
    print("  Failed to parse JSON: {}".format(e))
    print("  Raw: {}".format(raw[:200]))
    sys.exit(1)

models = d.get("data", [])
if not models:
    print("  No models found in response.")
    print("  Response keys: {}".format(list(d.keys())))
    sys.exit(0)

if d.get("has_more"):
    print("  Note: results may be paginated (showing first page only)")
    print()

print("  {:<45} {:>12} {:>12}".format("MODEL ID", "CTX IN", "CTX OUT"))
print("  " + "-" * 71)

for m in sorted(models, key=lambda x: x.get("id", "")):
    mid = m.get("id", "?")
    ctx_in = m.get("max_input_tokens", "")
    ctx_out = m.get("max_output_tokens", "")
    if isinstance(ctx_in, int): ctx_in = "{:,}".format(ctx_in)
    if isinstance(ctx_out, int): ctx_out = "{:,}".format(ctx_out)
    print("  {:<45} {:>12} {:>12}".format(mid, str(ctx_in), str(ctx_out)))

print()
print("  Total: {} model(s)".format(len(models)))
PYEOF

    rm -f "$tmp_body"
    trap - EXIT
}

cmd_add() {
    local raw_name="${1:-}"; shift || true
    local url="" key=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-url) url="${2:-}"; shift 2 ;;
            --token)    key="${2:-}"; shift 2 ;;
            *)
                [[ -z "$url" ]] && url="$1" || key="$1"
                shift ;;
        esac
    done

    [[ -n "$raw_name" ]] || die "Usage: ccgs add <name> <url> [--token <key>]"
    [[ -n "$url" ]]      || die "Usage: ccgs add <name> --base-url <url> [--token <key>]"

    [[ "$url" =~ ^https?:// ]] || die "URL must start with http:// or https://"

    local name
    name=$(normalize_proxy_name "$raw_name")
    [[ -n "$name" ]] || die "Proxy name '$raw_name' is invalid (use letters, digits, hyphens, underscores)"

    local varprefix
    varprefix=$(proxy_var_prefix "$name")

    mkdir -p "$CCGS_CONFIG_DIR"
    [[ -f "$CCGS_CONFIG_FILE" ]] || init_config

    write_config_value "${varprefix}_URL" "$url"
    write_config_value "${varprefix}_KEY" "$key"
    write_config_value "${varprefix}_MODEL" ""

    success "Proxy '$name' configured."
    info "URL:  $url"
    [[ -n "$key" ]] && info "Key:  ${key:0:8}..." || info "Key:  (none — open proxy)"
    info ""
    info "Switch to it:          ccgs proxy $name"
    info "List models:           ccgs models list $name"
    info "Set a default model:   ccgs config"
}

cmd_remove() {
    local raw_name="${1:-}"
    [[ -n "$raw_name" ]] || die "Usage: ccgs remove <name>"

    local name
    name=$(normalize_proxy_name "$raw_name")

    proxy_exists "$name" || die "Proxy '$name' not found. See: ccgs list"

    local active="${CCGS_ACTIVE:-native}"
    if [[ "$active" == "$name" ]]; then
        warn "Proxy '$name' is currently active."
        printf '  Remove anyway? [y/N] '
        local confirm
        read -r confirm || confirm=""
        [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
    fi

    local varprefix
    varprefix=$(proxy_var_prefix "$name")
    remove_config_values_by_prefix "${varprefix}_"

    # If this proxy was active, also remove the stale CCGS_ACTIVE line and reset
    if [[ "$active" == "$name" ]]; then
        write_config_value "CCGS_ACTIVE" "native"
        success "Proxy '$name' removed. Active mode reset to native."
        warn "Run 'ccgs native' to also clear settings.json."
    else
        success "Proxy '$name' removed."
    fi
}

cmd_list() {
    local active="${CCGS_ACTIVE:-native}"

    header "Configured proxies:"
    printf '\n'

    local names
    names=$(list_proxy_names)

    if [[ -z "$names" ]]; then
        info "(no proxies configured)"
        info ""
        info "Add one:  ccgs add litellm https://litellm.my-company.com sk-..."
        return 0
    fi

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        local url key model marker
        url=$(get_proxy_url "$name")
        key=$(get_proxy_key "$name")
        model=$(get_proxy_model "$name")
        marker=""
        [[ "$active" == "$name" ]] && marker=" ${GREEN}[ACTIVE]${RESET}"

        printf "  ${BOLD}%-22s${RESET}  %s%b\n" "$name" "$url" "$marker"
        [[ -n "$key" ]]   && printf "    key:   %s...\n" "${key:0:8}"
        [[ -n "$model" ]] && printf "    model: %s\n" "$model"
    done <<< "$names"

    printf '\n'
    printf "  Active mode: ${BOLD}%s${RESET}\n" "$active"
    printf '\n'
    info "Switch:  ccgs native  |  ccgs proxy <name>"
}

cmd_status() {
    local active="${CCGS_ACTIVE:-native}"

    header "ccgs status"
    printf '\n'
    printf "  %-24s ${BOLD}%s${RESET}\n" "Active mode:" "$active"

    if [[ "$active" != "native" ]] && proxy_exists "$active"; then
        local url key model
        url=$(get_proxy_url "$active")
        key=$(get_proxy_key "$active")
        model=$(get_proxy_model "$active")
        printf "  %-24s %s\n" "Proxy URL:" "$url"
        [[ -n "$model" ]] && printf "  %-24s %s\n" "Default model:" "$model"
        [[ -n "$key" ]]   && printf "  %-24s %s...\n" "Auth key:" "${key:0:8}"
    fi

    printf '\n'
    printf "  %-24s %s\n" "Config file:" "$CCGS_CONFIG_FILE"
    printf "  %-24s %s\n" "settings.json:" "$CLAUDE_SETTINGS_FILE"
    printf '\n'

    if [[ -f "$CLAUDE_SETTINGS_FILE" ]]; then
        header "  Current settings.json env block:"
        python3 - "$CLAUDE_SETTINGS_FILE" << 'PYEOF'
import sys, json
MANAGED = {"ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_MODEL"}
try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
    env = data.get("env", {})
    active_keys = [k for k in MANAGED if k in env]
    if not active_keys:
        print("    (no ccgs-managed keys — native mode)")
    else:
        for k in ("ANTHROPIC_BASE_URL", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_API_KEY", "ANTHROPIC_MODEL"):
            if k in env:
                v = env[k]
                if "KEY" in k or "TOKEN" in k:
                    v = v[:8] + "..." if len(v) > 8 else v
                print("    {:<35} {}".format(k, v))
except Exception as e:
    print("    (could not read settings.json: {})".format(e))
PYEOF
    else
        info "  settings.json not found (will be created on first switch)"
    fi
}

cmd_config() {
    mkdir -p "$CCGS_CONFIG_DIR"
    [[ -f "$CCGS_CONFIG_FILE" ]] || init_config
    local editor="${VISUAL:-${EDITOR:-vi}}"
    info "Opening config in $editor..."
    info "File: $CCGS_CONFIG_FILE"
    "$editor" "$CCGS_CONFIG_FILE"
}

cmd_version() {
    printf 'ccgs %s\n' "$CCGS_VERSION"
}

cmd_help() {
    printf "${BOLD}${CYAN}ccgs${RESET} — Claude Code Gateway Switch v%s\n\n" "$CCGS_VERSION"
    printf "${BOLD}USAGE${RESET}\n"
    printf "  ccgs <command> [options]\n\n"
    printf "${BOLD}COMMANDS${RESET}\n"
    printf "  ${GREEN}native${RESET}                   Switch to native Anthropic API (Pro subscription)\n"
    printf "  ${GREEN}proxy${RESET} <name>             Switch to a named proxy (writes settings.json)\n"
    printf "  ${GREEN}models list${RESET} [name]       List models from current or named proxy\n"
    printf "  ${GREEN}add${RESET} <name> <url> [key]                    Add or update a proxy configuration\n"
    printf "  ${GREEN}add${RESET} <name> --base-url <url> [--token <key>]  (named-flag form)\n"
    printf "  ${GREEN}remove${RESET} <name>            Remove a proxy configuration\n"
    printf "  ${GREEN}list${RESET}                     List all configured proxies\n"
    printf "  ${GREEN}status${RESET}                   Show current mode and settings.json state\n"
    printf "  ${GREEN}config${RESET}                   Open config file in \$EDITOR\n"
    printf "  ${GREEN}help${RESET}                     Show this help\n"
    printf "  ${GREEN}version${RESET}                  Show version\n\n"
    printf "${BOLD}GLOBAL FLAGS${RESET}\n"
    printf "  --session    Export env vars into current shell (requires shell function or eval)\n\n"
    printf "${BOLD}EXAMPLES${RESET}\n"
    printf "  ccgs add litellm https://litellm.my-company.com sk-mykey\n"
    printf "  ccgs add litellm --base-url https://litellm.my-company.com --token sk-mykey\n"
    printf "  ccgs proxy litellm\n"
    printf "  ccgs native\n"
    printf "  ccgs models list litellm\n"
    printf "  ccgs status\n"
    printf "  ccgs proxy litellm --session   # session-only, no settings.json write\n\n"
    printf "${BOLD}CONFIG FILE${RESET}\n"
    printf "  %s\n\n" "$CCGS_CONFIG_FILE"
    printf "${BOLD}DOCS${RESET}\n"
    printf "  https://github.com/antoinefradin/claude-code-gateway-switch\n"
}

# ─── Shell Function Injection ─────────────────────────────────────────────────

inject_shell_function() {
    require_python3

    local shell_rc target_shell
    target_shell=$(basename "${SHELL:-bash}")

    case "$target_shell" in
        zsh)  shell_rc="$HOME/.zshrc" ;;
        bash) shell_rc="$HOME/.bashrc" ;;
        *)
            warn "Unsupported shell '$target_shell'. Shell function not injected."
            info "For --session mode, use:  eval \"\$(ccgs proxy <name> --session)\""
            return 0
            ;;
    esac

    touch "$shell_rc"

    # Remove existing injection (idempotent)
    if grep -q ">>> ccgs shell function >>>" "$shell_rc" 2>/dev/null; then
        info "Removing existing shell function from $shell_rc..."
        python3 - "$shell_rc" << 'PYEOF'
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
    fi

    # Append the shell function block
    cat >> "$shell_rc" << 'SHELL_FUNCTION'

# >>> ccgs shell function >>>
# Enables --session mode for ccgs (exports env vars into current shell).
# Added by ccgs installer. Remove with: ccgs uninstall
ccgs() {
    local _cmd="${1:-}"
    if { [[ "$_cmd" == "native" ]] || [[ "$_cmd" == "proxy" ]]; } && \
       { printf '%s\n' "$@" | grep -qx -- '--session'; }; then
        local _out _rc
        _out="$(CCGS_SESSION_OUTPUT=1 command ccgs "$@" 2>/dev/null)"
        _rc=$?
        if [[ -n "$_out" ]]; then
            eval "$_out"
            echo "[ccgs] Session vars applied to current shell."
        else
            echo "[ccgs] Warning: no session output received." >&2
        fi
        return $_rc
    else
        command ccgs "$@"
    fi
}
# <<< ccgs shell function <<<
SHELL_FUNCTION

    success "Shell function injected into $shell_rc"
    info "Run: source $shell_rc  (or open a new terminal)"
}

remove_shell_function() {
    require_python3

    local target_shell
    target_shell=$(basename "${SHELL:-bash}")

    local shell_rc
    case "$target_shell" in
        zsh)  shell_rc="$HOME/.zshrc" ;;
        bash) shell_rc="$HOME/.bashrc" ;;
        *)    warn "Unsupported shell; remove the ccgs block manually from your shell profile."; return 0 ;;
    esac

    if ! grep -q ">>> ccgs shell function >>>" "$shell_rc" 2>/dev/null; then
        info "No ccgs shell function found in $shell_rc"
        return 0
    fi

    python3 - "$shell_rc" << 'PYEOF'
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

    success "Shell function removed from $shell_rc"
}

# ─── Main Dispatcher ──────────────────────────────────────────────────────────

main() {
    local cmd="${1:-help}"
    shift || true

    # Parse global flags and filter positional args
    local session_mode=0
    local filtered_args=()
    for arg in "$@"; do
        case "$arg" in
            --session)     session_mode=1 ;;
            --version|-v)  cmd_version; return 0 ;;
            --help|-h)     cmd_help; return 0 ;;
            *)             filtered_args+=("$arg") ;;
        esac
    done
    # bash 3.2 + set -u: empty arrays trigger "unbound variable" with ${arr[@]}
    if [[ ${#filtered_args[@]} -gt 0 ]]; then
        set -- "${filtered_args[@]}"
    else
        set --
    fi

    case "$cmd" in
        native)
            load_config
            cmd_native "$session_mode"
            ;;
        proxy)
            load_config
            [[ $# -gt 0 ]] || die "Usage: ccgs proxy <name> [--session]"
            cmd_proxy "$session_mode" "$@"
            ;;
        models)
            local subcmd="${1:-list}"
            shift || true
            case "$subcmd" in
                list) load_config; cmd_models_list "$@" ;;
                *) die "Unknown models subcommand: '$subcmd'. Try: ccgs models list" ;;
            esac
            ;;
        add)
            [[ $# -ge 2 ]] || die "Usage: ccgs add <name> <url> [--token <key>]"
            load_config
            cmd_add "$@"
            ;;
        remove|rm)
            [[ $# -ge 1 ]] || die "Usage: ccgs remove <name>"
            load_config
            cmd_remove "$@"
            ;;
        list|ls)
            load_config
            cmd_list
            ;;
        status)
            load_config
            cmd_status
            ;;
        config)
            cmd_config
            ;;
        help|--help|-h)
            cmd_help
            ;;
        version|--version|-v)
            cmd_version
            ;;
        --inject-shell-function)
            inject_shell_function
            ;;
        --remove-shell-function)
            remove_shell_function
            ;;
        *)
            err "Unknown command: '$cmd'"
            printf '\n'
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
