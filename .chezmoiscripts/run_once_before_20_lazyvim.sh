#!/bin/bash
# Neovim: migrate away from a previous NvChad setup.
#
# The Neovim config is now fully managed by chezmoi (init.lua, lua/config/,
# lua/plugins/): nothing is cloned, so there is no upstream tree to pull or keep
# in sync. This hook only runs once (per content hash) and only cleans up:
#
#   * a non-LazyVim ~/.config/nvim is moved aside, never deleted
#   * NvChad's plugin/cache dirs in ~/.local/share/nvim are moved aside too
#     (~/.local/share/nvim/nvchad holds base46's compiled highlights and breaks
#     LazyVim if left in place)
#
# Raspbian uses vim (dot_vimrc) and never has Neovim, so it is skipped.
set -euo pipefail
log() { echo "==> [nvim] $*"; }

if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    case "${ID:-}" in
        *raspbian*) log "Raspbian: vim-only setup, skipping"; exit 0 ;;
    esac
fi

NVIM_CFG="$HOME/.config/nvim"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
STAMP="$(date +%Y%m%d-%H%M%S)"

# Already on the managed LazyVim config: nothing to migrate.
if [ -f "$NVIM_CFG/lua/config/lazy.lua" ]; then
    log "LazyVim config already present"
    exit 0
fi

if [ -d "$NVIM_CFG" ] && [ -n "$(ls -A "$NVIM_CFG" 2>/dev/null)" ]; then
    backup="$NVIM_CFG.bak-$STAMP"
    log "Existing Neovim config is not LazyVim; moving it to ${backup}"
    mv "$NVIM_CFG" "$backup"
fi

# NvChad leftovers in the data dir. Moved, not deleted: they are regenerable,
# but keeping them makes the migration reversible.
legacy_backup="$DATA_DIR/pre-lazyvim-$STAMP"
moved=0
for rel in nvchad lazy/base46 lazy/ui lazy/nvterm lazy/nvim-colorizer.lua; do
    if [ -e "$DATA_DIR/$rel" ]; then
        mkdir -p "$legacy_backup"
        mv "$DATA_DIR/$rel" "$legacy_backup/$(basename "$rel")"
        log "Moved stale plugin data: ${rel}"
        moved=1
    fi
done
if [ "$moved" -eq 1 ]; then
    log "Old plugin data backed up in ${legacy_backup}"
else
    log "No previous Neovim config to migrate"
fi
