#!/bin/bash
# TPM (Tmux Plugin Manager) + tmux plugins.
# Runs via chezmoi AFTER dotfiles are written (~/.tmux.conf exists).
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
