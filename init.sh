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
# Download the installer to a file first: `sh -c "$(curl ...)"` exits 0 on an
# empty download, so a failed fetch would look like success. get.chezmoi.io and
# the GitHub release it redirects to occasionally return 5xx, hence the retries.
install_chezmoi() {
    local tmp rc=0
    tmp="$(mktemp)"
    if curl -fsSL --max-time 60 -o "$tmp" https://get.chezmoi.io && [ -s "$tmp" ]; then
        sh "$tmp" -b "$HOME/.local/bin" || rc=$?
    else
        rc=1
    fi
    rm -f "$tmp"
    return "$rc"
}

if command -v chezmoi >/dev/null 2>&1; then
    echo "==> chezmoi already installed: $(chezmoi --version | head -1)"
else
    echo "==> Installing chezmoi..."
    for attempt in 1 2 3; do
        if install_chezmoi; then
            break
        fi
        if [ "$attempt" -eq 3 ]; then
            echo "ERROR: could not install chezmoi after 3 attempts" >&2
            exit 1
        fi
        echo "    download failed (attempt ${attempt}/3), retrying in 5s" >&2
        sleep 5
    done
fi
export PATH="$HOME/.local/bin:$PATH"
command -v chezmoi >/dev/null 2>&1 || {
    echo "ERROR: chezmoi is not on PATH after installation" >&2
    exit 1
}

# --- Point chezmoi at this checkout (supports worktrees) --------------------
# Only the sourceDir key is replaced: other settings in an existing
# chezmoi.toml ([data], [edit], [diff], ...) are preserved. The previous file
# is kept as a backup the first time this points somewhere else.
echo "==> Configuring chezmoi source: ${REPO_DIR}"
mkdir -p "$HOME/.config/chezmoi"
cfg="$HOME/.config/chezmoi/chezmoi.toml"
if [ -f "$cfg" ]; then
    if ! grep -qxF "sourceDir = \"${REPO_DIR}\"" "$cfg"; then
        backup="${cfg}.bak-$(date +%Y%m%d-%H%M%S)"
        cp "$cfg" "$backup"
        echo "    previous config backed up to ${backup}"
    fi
    grep -vE '^[[:space:]]*sourceDir[[:space:]]*=' "$cfg" > "${cfg}.tmp"
else
    : > "${cfg}.tmp"
fi
{
    printf 'sourceDir = "%s"\n' "$REPO_DIR"
    cat "${cfg}.tmp"
} > "$cfg"
rm -f "${cfg}.tmp"

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
echo "  - Dev tools (go, neovim, kubectl, ...) are managed by mise; pins live in"
echo "    .chezmoidata/software.yaml and './update.sh' refreshes the tooling"
