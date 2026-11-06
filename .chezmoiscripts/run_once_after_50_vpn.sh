#!/bin/bash
# Tailscale + NordVPN (Raspbian devices only; the Pi is the one machine that
# needs device-level VPN clients).
# Runs via chezmoi AFTER dotfiles are written.
set -euo pipefail
log() { echo "==> [vpn] $*"; }

os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi
case "$os_id" in
    raspbian|raspios) ;;
    *) log "not Raspbian, skipping"; exit 0 ;;
esac

if command -v tailscale >/dev/null 2>&1; then
    log "tailscale already installed"
else
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    log "After install: run 'sudo tailscale up' to join your tailnet"
fi

if command -v nordvpn >/dev/null 2>&1; then
    log "nordvpn already installed"
else
    log "Installing NordVPN..."
    sh -c "$(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)"
    log "After install: run 'nordvpn login' and 'nordvpn connect'"
fi
