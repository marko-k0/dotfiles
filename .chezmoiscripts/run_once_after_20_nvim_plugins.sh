#!/bin/bash
# Neovim plugin bootstrap (lazy.nvim sync, headless).
# Runs via chezmoi AFTER dotfiles are written, so init.lua and lua/plugins/*
# exist. Also clones lazy.nvim itself on a fresh machine.
set -euo pipefail
log() { echo "==> [nvim-plugins] $*"; }

# mise-managed nvim lives behind shims, which a non-interactive shell (this
# hook runs under) does not get from the fish config.
if [ -d "$HOME/.local/share/mise/shims" ]; then
    PATH="$HOME/.local/share/mise/shims:$PATH"
    export PATH
fi

if ! command -v nvim >/dev/null 2>&1; then
    log "nvim not installed, skipping"
    exit 0
fi
if [ ! -f "$HOME/.config/nvim/lua/config/lazy.lua" ]; then
    log "LazyVim config not present (Raspbian vim-only setup), skipping"
    exit 0
fi

log "Syncing Neovim plugins (headless)"
nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true
