#!/bin/bash
# Fisher + fish plugins (from ~/.config/fish/fish_plugins).
# Runs via chezmoi AFTER dotfiles are written.
set -euo pipefail
log() { echo "==> [fish] $*"; }

os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi
case "$os_id" in
    *raspbian*) log "Raspbian: Fisher skipped (fish too old for plugins)"; exit 0 ;;
esac

command -v fish >/dev/null 2>&1 || { log "fish not installed, skipping"; exit 0; }

# The plugin list is deployed by chezmoi; skip plugin install when it was
# deliberately removed (Raspbian compat).
if [ ! -f "$HOME/.config/fish/fish_plugins" ]; then
    log "no fish_plugins, skipping Fisher"
    exit 0
fi

fish -c '
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    else
        fisher update
    end
'
log "Fisher and plugins up to date"
