#!/bin/bash
# NvChad base config. Cloned once; chezmoi supplies the custom layer afterwards.
# Neovim itself is managed by mise (see run_after_05_mise.sh).
# Runs before dotfiles; skipped on Raspbian (vim-only setup).
set -euo pipefail
log() { echo "==> [nvchad] $*"; }

if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    case "${ID:-}" in
        *raspbian*) log "Raspbian: vim-only setup, skipping"; exit 0 ;;
    esac
fi

if [ -d "$HOME/.config/nvim/lua/core" ]; then
    log "NvChad already present"
    exit 0
fi

# Never silently destroy an existing (non-NvChad) config: move it aside.
if [ -d "$HOME/.config/nvim" ] && [ -n "$(ls -A "$HOME/.config/nvim" 2>/dev/null)" ]; then
    backup="$HOME/.config/nvim.bak-$(date +%Y%m%d-%H%M%S)"
    log "Existing nvim config is not NvChad; moving it to ${backup}"
    mv "$HOME/.config/nvim" "$backup"
fi

log "Cloning NvChad v2.0"
rm -rf "$HOME/.config/nvim"
git clone --branch v2.0 --depth 1 \
    https://github.com/NvChad/NvChad "$HOME/.config/nvim"
