#!/bin/bash
# Happier installer (happier.dev).
# Runs via chezmoi AFTER dotfiles are written.
set -euo pipefail
log() { echo "==> [happier] $*"; }

os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi
case "$os_id" in
    *raspbian*) log "Raspbian: Happier not installed here"; exit 0 ;;
esac

if command -v happier >/dev/null 2>&1; then
    log "happier already installed"
else
    HAPPIER_NONINTERACTIVE=1 curl -fsSL https://happier.dev/install | bash
fi
