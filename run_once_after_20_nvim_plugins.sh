#!/bin/bash
# Neovim plugin bootstrap (Lazy.nvim sync, headless).
# Runs via chezmoi AFTER dotfiles are written and NvChad is present.
set -euo pipefail
log() { echo "==> [nvim-plugins] $*"; }

if ! command -v nvim >/dev/null 2>&1; then
    log "nvim not installed, skipping"
    exit 0
fi
if [ ! -d "$HOME/.config/nvim/lua/core" ]; then
    log "NvChad not present (Raspbian vim-only setup), skipping"
    exit 0
fi

log "Syncing Neovim plugins (headless)"
nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || true
