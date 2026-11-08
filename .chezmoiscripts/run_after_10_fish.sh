#!/bin/bash
# Fisher + fish plugins (from ~/.config/fish/fish_plugins).
# Runs via chezmoi AFTER dotfiles are written, on EVERY apply: fish_plugins is a
# dotfile, so a pin change never alters this script's content hash and a
# run_once_ hook would never notice it. The no-op path is one `fisher list`
# call; `fisher update` (which re-downloads every plugin) only runs on drift.
#
# `fisher update` with no arguments reconciles to fish_plugins: it installs what
# is missing, updates what is listed, and removes what is no longer listed.
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
PLUGINS="$HOME/.config/fish/fish_plugins"
if [ ! -f "$PLUGINS" ]; then
    log "no fish_plugins, skipping Fisher"
    exit 0
fi

# Plugin specs are "owner/repo" or "owner/repo@ref" (fisher lowercases them).
# Normalize both sides before comparing so ordering/whitespace do not matter.
normalize() {
    sed -e 's/[[:space:]]//g' | grep -v '^$' | tr '[:upper:]' '[:lower:]' | sort -u
}

desired="$(normalize < "$PLUGINS")"
installed=""
if fish -c 'functions -q fisher' 2>/dev/null; then
    installed="$(fish -c 'fisher list' 2>/dev/null | normalize)"
fi

if [ -n "$installed" ] && [ "$installed" = "$desired" ]; then
    log "plugins match fish_plugins"
    exit 0
fi

log "Installing/updating plugins"
fish -c '
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    end
    fisher update
'
log "Fisher and plugins up to date"
