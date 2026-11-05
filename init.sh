#!/bin/bash
# Bootstrap: installs chezmoi, points it at this repo, applies everything.
# All real setup lives in run_once_before_* / run_once_after_* scripts that
# chezmoi executes (before/after writing dotfiles). Re-running this script is
# always safe.
#
# Usage: bash init.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Minimal prerequisites: curl (for the chezmoi installer) ---------------
if ! command -v curl >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y curl
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm --needed curl
    else
        echo "ERROR: curl is required to install chezmoi" >&2
        exit 1
    fi
fi

# --- chezmoi ----------------------------------------------------------------
if command -v chezmoi >/dev/null 2>&1; then
    echo "==> chezmoi already installed: $(chezmoi --version | head -1)"
else
    echo "==> Installing chezmoi..."
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
fi
export PATH="$HOME/.local/bin:$PATH"

# --- Point chezmoi at this checkout (supports worktrees) --------------------
echo "==> Configuring chezmoi source: ${REPO_DIR}"
mkdir -p "$HOME/.config/chezmoi"
printf 'sourceDir = "%s"\n' "$REPO_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"

# --- Apply: writes dotfiles, runs run_once_* setup scripts -----------------
echo "==> Applying dotfiles and running setup scripts..."
chezmoi apply

echo ""
echo "Done!"
echo "Post-install:"
echo "  - Log out and back in for fish to become your default shell"
echo "  - Run 'tide configure' to set up the fish prompt"
echo "  - Set OPENAI_API_KEY in your environment for codecompanion.nvim"
echo "  - Run 'happier auth login --no-open' to authenticate (use --no-open over SSH)"
