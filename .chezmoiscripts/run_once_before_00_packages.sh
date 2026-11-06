#!/bin/bash
# System packages via the distro package manager.
# Runs via chezmoi BEFORE dotfiles are written.
# - Ubuntu/Debian: apt
# - Arch: pacman (also provides neovim)
# - Raspbian: same apt path, lighter set (vim instead of nvim, no powerline)
set -euo pipefail
log() { echo "==> [packages] $*"; }

os_id=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/etc/os-release
    . /etc/os-release
    os_id="${ID:-}"
fi

if command -v apt-get >/dev/null 2>&1; then
    case "$os_id" in
        raspbian|raspios)
            log "Installing system packages (apt, Raspbian set)"
            sudo apt-get update -qq
            sudo apt-get install -y fish tmux vim git curl fzf
            ;;
        *)
            log "Installing system packages (apt)"
            sudo apt-get update -qq
            PKGS="fish tmux git curl fzf powerline"
            if apt-cache show kitty-terminfo >/dev/null 2>&1; then
                sudo apt-get install -y $PKGS kitty-terminfo
            else
                # kitty-terminfo may not be packaged (e.g. some Debian derivatives)
                sudo apt-get install -y $PKGS
            fi
            ;;
    esac
    # tmux-256color terminfo may be missing on older Debian/Ubuntu/Raspbian
    if ! infocmp tmux-256color >/dev/null 2>&1; then
        sudo apt-get install -y ncurses-term 2>/dev/null || true
    fi
elif command -v pacman >/dev/null 2>&1; then
    log "Installing system packages (pacman)"
    sudo pacman -Syu --noconfirm --needed \
        fish tmux git curl fzf powerline kitty-terminfo neovim
else
    echo "ERROR: [packages] unsupported package manager (need apt-get or pacman)" >&2
    exit 1
fi
