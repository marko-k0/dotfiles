#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
NVCHAD_BRANCH="v2.0"
NVIM_VERSION="latest"

echo "==> Installing system packages..."
sudo apt-get update -qq
sudo apt-get install -y fish tmux git curl fzf powerline kitty-terminfo

echo "==> Installing latest Neovim from GitHub..."
if command -v nvim &>/dev/null && nvim --version | head -1 | grep -qE 'v0\.(1[0-9]|[2-9])'; then
    echo "    Neovim already installed: $(nvim --version | head -1)"
else
    curl -fsSL -o /tmp/nvim-linux-x86_64.tar.gz \
        "https://github.com/neovim/neovim/releases/${NVIM_VERSION}/download/nvim-linux-x86_64.tar.gz"
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar xzf /tmp/nvim-linux-x86_64.tar.gz -C /opt
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm -f /tmp/nvim-linux-x86_64.tar.gz
    echo "    Installed: $(nvim --version | head -1)"
fi

echo "==> Installing chezmoi..."
if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

echo "==> Setting up chezmoi..."
mkdir -p "$HOME/.config/chezmoi"
cat > "$HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "${REPO_DIR}"
EOF

echo "==> Installing NvChad..."
if [ ! -d "$HOME/.config/nvim/lua/core" ]; then
    rm -rf "$HOME/.config/nvim"
    git clone --branch "$NVCHAD_BRANCH" --depth 1 \
        https://github.com/NvChad/NvChad "$HOME/.config/nvim"
fi

echo "==> Applying dotfiles with chezmoi..."
chezmoi apply

echo "==> Installing TPM (Tmux Plugin Manager)..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "==> Installing tmux plugins..."
"$HOME/.tmux/plugins/tpm/bin/install_plugins"

echo "==> Installing Fisher and Fish plugins..."
fish -c '
    if not functions -q fisher
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher install jorgebucaran/fisher
    else
        fisher update
    end
'

echo "==> Bootstrapping Neovim plugins..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

export PATH="$HOME/.local/bin:$PATH"

echo "==> Installing Claude Code..."
if command -v claude &>/dev/null; then
    echo "    Claude Code already installed"
else
    curl -fsSL https://claude.ai/install.sh | bash
fi

echo "==> Installing latest Go..."
"$REPO_DIR/install-go.sh"

echo "==> Installing Happier..."
if command -v happier &>/dev/null; then
    echo "    happier already installed"
else
    HAPPIER_NONINTERACTIVE=1 curl -fsSL https://happier.dev/install | bash
fi

echo "==> Changing default shell to Fish..."
if [ "$SHELL" != "/usr/bin/fish" ]; then
    sudo chsh -s /usr/bin/fish "$USER"
fi

echo ""
echo "Done! Log out and back in for fish to become your default shell."
echo ""
echo "Post-install:"
echo "  - Set OPENAI_API_KEY in your environment for codecompanion.nvim"
echo "  - Run 'tmux' and press prefix+I to verify tmux plugins"
echo "  - Run 'happier auth login --no-open' to authenticate (use --no-open over SSH)"
