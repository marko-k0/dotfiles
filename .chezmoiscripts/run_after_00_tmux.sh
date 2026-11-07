#!/bin/bash
# TPM (Tmux Plugin Manager) + tmux plugins.
# Runs via chezmoi AFTER dotfiles are written (~/.tmux.conf exists), on every
# apply: the plugin list lives in the managed ~/.tmux.conf, so adding a plugin
# there must install it without editing this script's content. Idempotent and
# cheap (~60ms when everything is installed; TPM only clones what is missing).
set -euo pipefail
log() { echo "==> [tmux] $*"; }

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    log "Cloning TPM"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
    log "TPM already present"
fi

if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    log "Installing tmux plugins"
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null
fi
