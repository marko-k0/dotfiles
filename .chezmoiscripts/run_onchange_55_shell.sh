#!/bin/bash
# Sets fish as the login shell if it is not already.
# Runs via chezmoi whenever this script's contents change (run_onchange);
# exits fast when the login shell is already fish.
set -euo pipefail
log() { echo "==> [shell] $*"; }

FISH_PATH="/usr/bin/fish"
[ -x "$FISH_PATH" ] || { log "fish not installed at $FISH_PATH, skipping"; exit 0; }

current_shell="$(getent passwd "${USER:-$(id -un)}" | cut -d: -f7)"
if [ "$current_shell" = "$FISH_PATH" ]; then
    log "login shell already fish"
    exit 0
fi

log "Changing login shell: ${current_shell} -> ${FISH_PATH} (takes effect on next login)"
if [ "$(id -u)" -eq 0 ]; then
    chsh -s "$FISH_PATH" "${USER:-$(id -un)}"
elif command -v sudo >/dev/null 2>&1; then
    sudo chsh -s "$FISH_PATH" "${USER:-$(id -un)}"
else
    log "WARNING: no sudo available; run manually: chsh -s ${FISH_PATH}"
fi
