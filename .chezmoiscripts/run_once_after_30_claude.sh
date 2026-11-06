#!/bin/bash
# Claude Code installer (claude.ai/install.sh).
# Runs via chezmoi AFTER dotfiles are written.
set -euo pipefail
log() { echo "==> [claude] $*"; }

# downloads.claude.ai 403s datacenter IPs (CI runners), so skip there.
# The installer also wants an interactive terminal on some setups.
if [ -n "${DOTFILES_CI:-}" ]; then
    log "CI environment detected, skipping"
    exit 0
fi

os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi
case "$os_id" in
    *raspbian*) log "Raspbian: Claude Code not installed here"; exit 0 ;;
esac

if command -v claude >/dev/null 2>&1; then
    log "Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi
