#!/usr/bin/env bash
# ccgs end-to-end test suite
# Uses isolated settings.json and config dir — never touches real files.
# Usage: bash tests/e2e.sh [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
chmod +x "$REPO_DIR/ccgs.sh"
ccgs() { "$REPO_DIR/ccgs.sh" "$@"; }
export -f ccgs

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

PASS=0
FAIL=0
ERRORS=()

# ─── Isolated environment ─────────────────────────────────────────────────────

export CLAUDE_SETTINGS
CLAUDE_SETTINGS=$(mktemp /tmp/ccgs_test_settings_XXXX.json)
# shellcheck disable=SC2064
trap "rm -f '$CLAUDE_SETTINGS'" EXIT

export XDG_CONFIG_HOME
XDG_CONFIG_HOME=$(mktemp -d /tmp/ccgs_test_config_XXXX)
# shellcheck disable=SC2064
trap "rm -rf '$XDG_CONFIG_HOME'; rm -f '$CLAUDE_SETTINGS'" EXIT

# Write initial settings.json with non-ccgs content to verify preservation
printf '{"theme":"dark","effortLevel":"medium","env":{"CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS":"1"}}' \
    > "$CLAUDE_SETTINGS"

# ─── Helpers ──────────────────────────────────────────────────────────────────

pass_test() {
    PASS=$((PASS+1))
    [[ "$VERBOSE" -eq 1 ]] && printf "  \033[0;32mPASS\033[0m  %s\n" "$*" || printf '.'
}

fail_test() {
    FAIL=$((FAIL+1))
    ERRORS+=("$*")
    printf "  \033[0;31mFAIL\033[0m  %s\n" "$*"
}

check() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass_test "$desc"
    else
        fail_test "$desc"
    fi
}

check_output() {
    local desc="$1" pattern="$2"
    shift 2
    local out
    out=$("$@" 2>&1) || true
    if echo "$out" | grep -q "$pattern"; then
        pass_test "$desc"
    else
        fail_test "$desc  (expected: '$pattern', got: '$out')"
    fi
}

py_assert() {
    local desc="$1" code="$2"
    if python3 -c "
import json
d = json.load(open('$CLAUDE_SETTINGS'))
$code
" 2>/dev/null; then
        pass_test "$desc"
    else
        fail_test "$desc"
    fi
}

# ─── Tests ────────────────────────────────────────────────────────────────────

printf '\n\033[1mccgs e2e tests\033[0m\n\n'

# T1: help shows USAGE
check_output "T01: help shows USAGE"   "USAGE"   ccgs help

# T2: version format
check_output "T02: version format"     "ccgs [0-9]"  ccgs version

# T3: status shows native by default
check_output "T03: status shows native" "native"  ccgs status

# T4: add proxy — writes URL to config
ccgs add testproxy http://localhost:9999 sk-testkey123 >/dev/null 2>&1
check "T04: add proxy — URL in config" \
    grep -q 'CCGS_PROXY_TESTPROXY_URL="http://localhost:9999"' "$XDG_CONFIG_HOME/ccgs/config"

# T5: add proxy — writes KEY to config
check "T05: add proxy — KEY in config" \
    grep -q 'CCGS_PROXY_TESTPROXY_KEY="sk-testkey123"' "$XDG_CONFIG_HOME/ccgs/config"

# T6: list shows added proxy
check_output "T06: list shows testproxy" "testproxy" ccgs list

# T7: switch to proxy — settings.json updated
ccgs proxy testproxy >/dev/null 2>&1
py_assert "T07: proxy sets ANTHROPIC_BASE_URL" \
    "assert d['env']['ANTHROPIC_BASE_URL'] == 'http://localhost:9999', repr(d)"

# T8: proxy sets AUTH_TOKEN
py_assert "T08: proxy sets ANTHROPIC_AUTH_TOKEN" \
    "assert d['env']['ANTHROPIC_AUTH_TOKEN'] == 'sk-testkey123', repr(d)"

# T9: proxy preserves theme
py_assert "T09: proxy preserves theme" \
    "assert d['theme'] == 'dark', repr(d)"

# T10: proxy preserves effortLevel
py_assert "T10: proxy preserves effortLevel" \
    "assert d['effortLevel'] == 'medium', repr(d)"

# T11: proxy preserves custom env keys
py_assert "T11: proxy preserves CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS" \
    "assert d['env']['CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS'] == '1', repr(d)"

# T12: no stale ANTHROPIC_API_KEY
py_assert "T12: no stale ANTHROPIC_API_KEY" \
    "assert 'ANTHROPIC_API_KEY' not in d.get('env', {}), repr(d)"

# T13: CCGS_ACTIVE updated in config
check "T13: CCGS_ACTIVE set to testproxy" \
    grep -q 'CCGS_ACTIVE="testproxy"' "$XDG_CONFIG_HOME/ccgs/config"

# T14: status reflects proxy mode
check_output "T14: status shows testproxy" "testproxy" ccgs status
check_output "T15: status shows proxy URL" "localhost:9999" ccgs status

# T16: idempotency — switch twice
ccgs proxy testproxy >/dev/null 2>&1
py_assert "T16: idempotency (ANTHROPIC_BASE_URL unchanged)" \
    "assert d['env']['ANTHROPIC_BASE_URL'] == 'http://localhost:9999', repr(d)"

# T17: switch to native — removes proxy keys
ccgs native >/dev/null 2>&1
py_assert "T17: native removes ANTHROPIC_BASE_URL" \
    "assert 'ANTHROPIC_BASE_URL' not in d.get('env', {}), repr(d)"

# T18: native removes AUTH_TOKEN
py_assert "T18: native removes ANTHROPIC_AUTH_TOKEN" \
    "assert 'ANTHROPIC_AUTH_TOKEN' not in d.get('env', {}), repr(d)"

# T19: native removes ANTHROPIC_MODEL
py_assert "T19: native removes ANTHROPIC_MODEL" \
    "assert 'ANTHROPIC_MODEL' not in d.get('env', {}), repr(d)"

# T20: native preserves theme
py_assert "T20: native preserves theme" \
    "assert d['theme'] == 'dark', repr(d)"

# T21: native preserves existing env key
py_assert "T21: native preserves CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS" \
    "assert d['env']['CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS'] == '1', repr(d)"

# T22: CCGS_ACTIVE reset to native
check "T22: CCGS_ACTIVE reset to native" \
    grep -q 'CCGS_ACTIVE="native"' "$XDG_CONFIG_HOME/ccgs/config"

# T23: add second proxy
ccgs add proxy2 https://openrouter.ai/api sk-or-key >/dev/null 2>&1
check_output "T23: list shows both proxies" "proxy2" ccgs list

# T24: session mode prints export statement
SESSION_OUT=$(CCGS_SESSION_OUTPUT=1 ccgs proxy testproxy --session 2>/dev/null)
if echo "$SESSION_OUT" | grep -q 'export ANTHROPIC_BASE_URL='; then
    pass_test "T24: session mode prints export ANTHROPIC_BASE_URL"
else
    fail_test "T24: session mode prints export ANTHROPIC_BASE_URL  (got: $SESSION_OUT)"
fi

# T25: session mode prints AUTH_TOKEN export
if echo "$SESSION_OUT" | grep -q 'export ANTHROPIC_AUTH_TOKEN='; then
    pass_test "T25: session mode prints export ANTHROPIC_AUTH_TOKEN"
else
    fail_test "T25: session mode prints export ANTHROPIC_AUTH_TOKEN  (got: $SESSION_OUT)"
fi

# T26: session mode does NOT write settings.json
# At this point we just did ccgs native (T17-T22), so no BASE_URL in settings
BEFORE=$(python3 -c "import json; d=json.load(open('$CLAUDE_SETTINGS')); print(d.get('env',{}).get('ANTHROPIC_BASE_URL','none'))")
CCGS_SESSION_OUTPUT=1 ccgs proxy testproxy --session >/dev/null 2>&1 || true
AFTER=$(python3 -c "import json; d=json.load(open('$CLAUDE_SETTINGS')); print(d.get('env',{}).get('ANTHROPIC_BASE_URL','none'))")
if [[ "$BEFORE" == "$AFTER" ]]; then
    pass_test "T26: session mode does not write settings.json"
else
    fail_test "T26: session mode does not write settings.json  (before=$BEFORE after=$AFTER)"
fi

# T27: native session mode prints unset statements
SESSION_NATIVE=$(CCGS_SESSION_OUTPUT=1 ccgs native --session 2>/dev/null)
if echo "$SESSION_NATIVE" | grep -q 'unset ANTHROPIC_BASE_URL'; then
    pass_test "T27: native session mode prints unset ANTHROPIC_BASE_URL"
else
    fail_test "T27: native session mode prints unset ANTHROPIC_BASE_URL  (got: $SESSION_NATIVE)"
fi

# T28: remove proxy
ccgs remove testproxy <<< "y" >/dev/null 2>&1 || true
if ! grep -q 'CCGS_PROXY_TESTPROXY' "$XDG_CONFIG_HOME/ccgs/config"; then
    pass_test "T28: remove deletes proxy keys from config"
else
    fail_test "T28: remove deletes proxy keys from config"
fi

# T29: removed proxy no longer in list
LIST_OUT=$(ccgs list 2>&1 || true)
if ! echo "$LIST_OUT" | grep -q "testproxy"; then
    pass_test "T29: removed proxy not in list"
else
    fail_test "T29: removed proxy not in list"
fi

# T30: unknown command shows error
UNKNOWN_OUT=$(ccgs unknowncmd 2>&1 || true)
if echo "$UNKNOWN_OUT" | grep -q "Unknown command"; then
    pass_test "T30: unknown command shows error"
else
    fail_test "T30: unknown command shows error"
fi

# T31: keyless proxy — no AUTH_TOKEN written to settings.json
ccgs add noauth http://open-proxy:8080 >/dev/null 2>&1
ccgs proxy noauth >/dev/null 2>&1
py_assert "T31: keyless proxy sets ANTHROPIC_BASE_URL" \
    "assert d.get('env',{}).get('ANTHROPIC_BASE_URL') == 'http://open-proxy:8080', repr(d)"
py_assert "T32: keyless proxy has no ANTHROPIC_AUTH_TOKEN" \
    "assert 'ANTHROPIC_AUTH_TOKEN' not in d.get('env',{}), repr(d)"

# T33: proxy with model — sets ANTHROPIC_MODEL
ccgs add modelproxy http://localhost:5000 sk-key >/dev/null 2>&1
# Manually set model in config
echo 'CCGS_PROXY_MODELPROXY_MODEL="claude-opus-4-8"' >> "$XDG_CONFIG_HOME/ccgs/config"
ccgs proxy modelproxy >/dev/null 2>&1
py_assert "T33: proxy with model sets ANTHROPIC_MODEL" \
    "assert d.get('env',{}).get('ANTHROPIC_MODEL') == 'claude-opus-4-8', repr(d)"

# T34: missing proxy name errors gracefully
T34_OUT=$(ccgs proxy 2>&1 || true)
if echo "$T34_OUT" | grep -qi "proxy name required\|usage"; then
    pass_test "T34: missing proxy name errors gracefully"
else
    fail_test "T34: missing proxy name errors gracefully"
fi

# T35: add requires URL
T35_OUT=$(ccgs add myproxy 2>&1 || true)
if echo "$T35_OUT" | grep -qi "usage\|url"; then
    pass_test "T35: add without URL shows usage"
else
    fail_test "T35: add without URL shows usage"
fi

# ─── T36-T44: ccgs models set (interactive default-model picker) ─────────────
# Spins up a tiny local /v1/models fixture server so the picker's fetch/parse/
# write/apply pipeline is exercised end-to-end (arrow-key rendering itself is
# not testable headlessly — these drive the non-TTY numbered-prompt fallback,
# which shares all the same code except the raw-terminal input loop).

FIXTURE_PORT=18934

python3 - "$FIXTURE_PORT" > /dev/null 2>&1 <<'PY' &
import sys, http.server, json

port = int(sys.argv[1])

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        body = {"data": [{"id": "claude-opus-4-8"}, {"id": "claude-sonnet-5"}]}
        self.wfile.write(json.dumps(body).encode())
    def log_message(self, *args):
        pass

http.server.HTTPServer(('127.0.0.1', port), Handler).serve_forever()
PY
FIXTURE_PID=$!
# shellcheck disable=SC2064
trap "rm -rf '$XDG_CONFIG_HOME'; rm -f '$CLAUDE_SETTINGS'; kill $FIXTURE_PID 2>/dev/null || true" EXIT

# Wait for the fixture server to come up (bounded, no fixed sleep guesswork)
for _ in 1 2 3 4 5 6 7 8 9 10; do
    curl -s -o /dev/null "http://127.0.0.1:$FIXTURE_PORT/v1/models" && break
    sleep 0.2
done

ccgs native >/dev/null 2>&1

# T36: models set with no proxy active (but proxies configured) points at
# `ccgs proxy <name>` / `ccgs list` instead of just saying "no proxy active"
T36_OUT=$(ccgs models set 2>&1 || true)
if echo "$T36_OUT" | grep -qi "no proxy active" && echo "$T36_OUT" | grep -q "ccgs proxy <name>"; then
    pass_test "T36: models set with no active proxy points at 'ccgs proxy <name>'"
else
    fail_test "T36: models set with no active proxy points at 'ccgs proxy <name>'  (got: $T36_OUT)"
fi

# T37: models set on an unknown proxy errors gracefully
T37_OUT=$(ccgs models set doesnotexist 2>&1 || true)
if echo "$T37_OUT" | grep -qi "not found"; then
    pass_test "T37: models set on unknown proxy errors gracefully"
else
    fail_test "T37: models set on unknown proxy errors gracefully  (got: $T37_OUT)"
fi

# T38: add a proxy backed by the fixture server
ccgs add pickerproxy "http://127.0.0.1:$FIXTURE_PORT" >/dev/null 2>&1
check_output "T38: list shows pickerproxy" "pickerproxy" ccgs list

# T39: models set (inactive proxy, non-TTY numbered fallback) writes config
# Options are: 1) clear default, 2) claude-opus-4-8, 3) claude-sonnet-5
echo "2" | ccgs models set pickerproxy >/dev/null 2>&1
check "T39: models set writes CCGS_PROXY_PICKERPROXY_MODEL to config" \
    grep -q 'CCGS_PROXY_PICKERPROXY_MODEL="claude-opus-4-8"' "$XDG_CONFIG_HOME/ccgs/config"

# T40: switching to pickerproxy carries the picked model into settings.json
ccgs proxy pickerproxy >/dev/null 2>&1
py_assert "T40: proxy pickerproxy carries picked model into ANTHROPIC_MODEL" \
    "assert d.get('env',{}).get('ANTHROPIC_MODEL') == 'claude-opus-4-8', repr(d)"

# T41: models set on the *active* proxy applies to settings.json immediately
echo "3" | ccgs models set pickerproxy >/dev/null 2>&1
py_assert "T41: models set applies immediately when proxy is active" \
    "assert d.get('env',{}).get('ANTHROPIC_MODEL') == 'claude-sonnet-5', repr(d)"

# T42: the "clear default" option removes ANTHROPIC_MODEL immediately (active proxy)
echo "1" | ccgs models set pickerproxy >/dev/null 2>&1
py_assert "T42: clear-default option removes ANTHROPIC_MODEL immediately" \
    "assert 'ANTHROPIC_MODEL' not in d.get('env', {}), repr(d)"

# T43: re-picking a model, then switching to native, fully resets it
echo "2" | ccgs models set pickerproxy >/dev/null 2>&1
py_assert "T43a: model re-applied before native reset" \
    "assert d.get('env',{}).get('ANTHROPIC_MODEL') == 'claude-opus-4-8', repr(d)"
ccgs native >/dev/null 2>&1
py_assert "T43b: native clears ANTHROPIC_MODEL set via models set" \
    "assert 'ANTHROPIC_MODEL' not in d.get('env', {}), repr(d)"

# T44: models set on a now-inactive proxy does not touch settings.json
BEFORE44=$(python3 -c "import json; d=json.load(open('$CLAUDE_SETTINGS')); print(d.get('env',{}).get('ANTHROPIC_MODEL','none'))")
echo "3" | ccgs models set pickerproxy >/dev/null 2>&1
AFTER44=$(python3 -c "import json; d=json.load(open('$CLAUDE_SETTINGS')); print(d.get('env',{}).get('ANTHROPIC_MODEL','none'))")
if [[ "$BEFORE44" == "$AFTER44" ]]; then
    pass_test "T44: models set on inactive proxy does not touch settings.json"
else
    fail_test "T44: models set on inactive proxy does not touch settings.json  (before=$BEFORE44 after=$AFTER44)"
fi

# T45: with zero proxies configured anywhere, the hint says "add one" instead
# of "select one" — isolated XDG_CONFIG_HOME so it doesn't see the proxies
# added earlier in this suite.
EMPTY_CONFIG_HOME=$(mktemp -d /tmp/ccgs_test_empty_config_XXXX)
T45_OUT=$(XDG_CONFIG_HOME="$EMPTY_CONFIG_HOME" ccgs models set 2>&1 || true)
rm -rf "$EMPTY_CONFIG_HOME"
if echo "$T45_OUT" | grep -qi "no proxies configured" && echo "$T45_OUT" | grep -q "ccgs add"; then
    pass_test "T45: models set with zero proxies configured suggests 'ccgs add'"
else
    fail_test "T45: models set with zero proxies configured suggests 'ccgs add'  (got: $T45_OUT)"
fi

# ─── Results ──────────────────────────────────────────────────────────────────

printf '\n\n'
printf '\033[1mResults:\033[0m  '
printf "\033[0;32m%d passed\033[0m  " "$PASS"
printf "\033[0;31m%d failed\033[0m\n" "$FAIL"

if [[ "${#ERRORS[@]}" -gt 0 ]]; then
    printf '\nFailed tests:\n'
    for err in "${ERRORS[@]}"; do
        printf "  - %s\n" "$err"
    done
    printf '\n'
fi

printf '\n'
[[ "$FAIL" -eq 0 ]]
