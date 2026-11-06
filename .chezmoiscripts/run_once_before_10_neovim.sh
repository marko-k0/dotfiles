#!/bin/bash
# Latest Neovim + NvChad base.
# - Ubuntu/Debian: apt ships an old neovim, so install the official GitHub
#   build into /opt (kept out of apt's way).
# - Arch: pacman already installed the current neovim (see packages script).
# - NvChad: cloned on first run; chezmoi later overwrites the custom layer
#   in ~/.config/nvim/lua/custom.
# Skipped on Raspbian (vim-only setup: dot_vimrc is deployed instead).
set -euo pipefail
log() { echo "==> [neovim] $*"; }

os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi
case "$os_id" in
    *raspbian*) log "Raspbian: vim-only setup (dot_vimrc), skipping"; exit 0 ;;
esac

if command -v apt-get >/dev/null 2>&1; then
    # Map machine arch to the GitHub release asset.
    local_asset=""
    case "$(uname -m)" in
        x86_64)  local_asset="nvim-linux-x86_64" ;;
        aarch64) local_asset="nvim-linux-arm64" ;;
    esac

    if command -v nvim >/dev/null 2>&1 \
        && nvim --version | head -1 | grep -qE 'v0\.(1[0-9]|[2-9])'; then
        log "Neovim already installed: $(nvim --version | head -1)"
    elif [ -n "$local_asset" ]; then
        log "Installing latest Neovim from GitHub (${local_asset})"
        curl -fsSL -o "/tmp/${local_asset}.tar.gz" \
            "https://github.com/neovim/neovim/releases/latest/download/${local_asset}.tar.gz"
        sudo rm -rf "/opt/${local_asset}"
        sudo tar xzf "/tmp/${local_asset}.tar.gz" -C /opt
        sudo ln -sf "/opt/${local_asset}/bin/nvim" /usr/local/bin/nvim
        rm -f "/tmp/${local_asset}.tar.gz"
        log "Installed: $(nvim --version | head -1)"
    else
        log "No official Neovim build for $(uname -m); skipping (install via distro)"
    fi
fi

if [ -d "$HOME/.config/nvim/lua/core" ]; then
    log "NvChad already present"
else
    log "Cloning NvChad v2.0"
    rm -rf "$HOME/.config/nvim"
    git clone --branch v2.0 --depth 1 \
        https://github.com/NvChad/NvChad "$HOME/.config/nvim"
fi
