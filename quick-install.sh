#!/usr/bin/env bash
# ccgs quick installer — one-liner bootstrap
# curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/claude-code-gateway-switch/main/quick-install.sh | bash

set -euo pipefail

REPO="YOUR_USERNAME/claude-code-gateway-switch"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

TMP_DIR=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$TMP_DIR'" EXIT

printf '[ccgs] Downloading...\n'
curl -fsSL "${BASE_URL}/ccgs"        -o "$TMP_DIR/ccgs"
curl -fsSL "${BASE_URL}/install.sh"  -o "$TMP_DIR/install.sh"
chmod +x "$TMP_DIR/ccgs"

printf '[ccgs] Installing...\n'
CCGS_REPO_DIR="$TMP_DIR" bash "$TMP_DIR/install.sh" "$@"
